#!/usr/bin/env bash
# End-to-end smoke test for the Bookstore lab.
# Run from anywhere: bash tests/smoke.sh   (needs Docker + Compose, builds the stack, removes it at the end)
set -euo pipefail
cd "$(dirname "$0")/.."

# Isolation: run in a separate Compose project so the learner's own 'bookstore' stack,
# volume and port are never touched. Must be set BEFORE the cleanup trap can fire.
export COMPOSE_PROJECT_NAME=bookstore-smoke
created_env=0

cleanup() {
  docker compose down -v >/dev/null 2>&1 || true
  if [ "$created_env" = 1 ]; then rm -f .env; fi
}
trap cleanup EXIT

pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; exit 1; }
contains() { # description, expected substring, actual
  case "$3" in *"$2"*) pass "$1" ;; *) fail "$1 (expected '$2' in: $3)" ;; esac
}
status_is() { # description, expected HTTP status, "<status> <body>"
  [ "${3%% *}" = "$2" ] && pass "$1" || fail "$1 (expected $2, got: $3)"
}
wait_healthy() { # service, timeout in seconds
  for _ in $(seq 1 "$2"); do
    [ "$(docker compose ps --format '{{.Service}}={{.Health}}' | grep "^$1=")" = "$1=healthy" ] && return 0
    sleep 1
  done
  return 1
}

# Call the backend from inside its own container (it is not published to the host).
# Prints "<status> <body>"; any transport failure prints "000 <reason>" instead of aborting the script.
api() { # method path [json]
  docker compose exec -T backend python - "$@" <<'PY' || echo "000 exec failed"
import sys, urllib.error, urllib.request
method, path = sys.argv[1], sys.argv[2]
data = sys.argv[3].encode() if len(sys.argv) > 3 else None
req = urllib.request.Request("http://localhost:8000" + path, data=data, method=method,
                             headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        print(r.status, r.read().decode())
except urllib.error.HTTPError as e:
    print(e.code, e.read().decode())
except Exception as e:
    print("000", repr(e))
PY
}

# Exercise the frontend's row-selection handler with the shapes of data Gradio really sends.
frontend_check() {
  docker compose exec -T frontend python - <<'PY'
import types

import pandas as pd

import app

cols = ["id", "title", "author", "price", "year"]


def pick(df, row):
    return app.pick_row(df, types.SimpleNamespace(index=[row, 0]))


# a book without a year (all years missing -> object column of None)
df = pd.DataFrame([[1, "A", "B", 9.5, None]], columns=cols)
assert pick(df, 0) == (1, "A", "B", 9.5, None), pick(df, 0)
# a normal book
df = pd.DataFrame([[2, "C", "D", 3.0, 2008]], columns=cols)
assert pick(df, 0) == (2, "C", "D", 3.0, 2008), pick(df, 0)
# the blank placeholder row Gradio shows for an empty table
df = pd.DataFrame([["", "", "", "", ""]], columns=cols)
assert pick(df, 0) == app.clear_form(), pick(df, 0)
# a click beyond the table
assert pick(df, 5) == app.clear_form()
print("ROW-SELECT-OK")
PY
}

# Drive the real Gradio event handlers (Save / Delete) through Gradio's own API layer:
# browser -> frontend -> backend -> db. Guards against breakage when Gradio is upgraded.
frontend_api_check() {
  docker compose exec -T frontend python - <<'PY'
from gradio_client import Client

client = Client("http://localhost:7860", verbose=False)
_, message = client.predict(None, "Smoke Book", "Gradio Client", 5.0, 2020, api_name="/save_book")
assert "Đã thêm sách" in message, message
book_id = int(message.split("#")[1])
_, message = client.predict(book_id, api_name="/delete_book")
assert "Đã xóa sách" in message, message
print("UI-API-OK")
PY
}

# Deterministic pool_pre_ping check: kill the server-side process behind a pooled connection of the
# app's own engine, then use the engine again. Without pool_pre_ping that query raises OperationalError.
backend_pool_check() {
  docker compose exec -T backend python - <<'PY'
import time

from sqlalchemy import create_engine, text

from app.db import DATABASE_URL, engine

with engine.connect() as c:  # one connection goes back into the pool
    pid = c.execute(text("select pg_backend_pid()")).scalar()
killer = create_engine(DATABASE_URL)
with killer.connect() as k:  # kill its server process: the pooled connection is now stale
    k.execute(text("select pg_terminate_backend(:pid)"), {"pid": pid})
time.sleep(0.5)
with engine.connect() as c:  # the engine must notice and reconnect transparently
    assert c.execute(text("select 1")).scalar() == 1
print("PREPING-OK")
PY
}

if [ ! -f .env ]; then cp .env.example .env; created_env=1; fi
# Compose reads .env itself; only the published port is overridden so the lab's 7860 stays free.
export FRONTEND_PORT="${SMOKE_FRONTEND_PORT:-17860}"
FRONT="http://localhost:${FRONTEND_PORT}/"

# 0. Independence and configuration errors
# Decide on grep's output, not its exit code: grep exits 2 when a path is missing even if it matched.
hits=$(grep -rnE 'FastAPI-Tutorial|\.\./' compose.yaml backend frontend 2>/dev/null || true)
[ -z "$hits" ] && pass "no reference to sibling repos or ../ paths" || fail "sibling reference found: $hits"
for var in POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB; do # Compose stops at the first missing variable: test each alone
  tmp=$(mktemp)
  grep -v "^$var=" .env.example > "$tmp"
  out=$(env -u POSTGRES_USER -u POSTGRES_PASSWORD -u POSTGRES_DB docker compose --env-file "$tmp" config 2>&1 || true)
  rm -f "$tmp"
  contains "missing $var is reported" "required variable $var is missing a value" "$out"
done
# pg_isready without -h talks to the unix socket and succeeds while the image's temporary
# init server (socket only) is up; probing TCP means "ready" is what the backend will use.
contains "db healthcheck probes TCP, not the init-time socket" "pg_isready -h 127.0.0.1" "$(docker compose config)"

# The UI has no login: it must listen on this machine only, not on the whole network.
contains "frontend is published on 127.0.0.1 only (config)" "host_ip: 127.0.0.1" "$(docker compose config)"

# 1. Build and start; all services healthy
docker compose up -d --build --wait --wait-timeout 300
health=$(docker compose ps --format '{{.Service}}={{.Health}}' | sort | tr '\n' ' ')
for s in backend db frontend; do contains "$s is healthy" "$s=healthy" "$health"; done

# Reproducible builds: every package installed in an image must be pinned in <service>/constraints.txt.
for s in backend frontend; do
  extra=$(docker compose exec -T "$s" pip freeze 2>/dev/null | sort | comm -23 - <(sort "$s/constraints.txt" 2>/dev/null))
  [ -z "$extra" ] && pass "$s: all installed packages are pinned in constraints.txt" \
                  || fail "$s: packages not pinned in constraints.txt: $(echo $extra)"
done

# 2. Only the frontend is published
# A published port shows as "host:port->container/tcp" in the Ports column; an internal one has no "->".
ports=$(docker compose ps --format '{{.Service}}|{{.Ports}}')
publishes() { echo "$ports" | grep "^$1|" | grep -q -- '->'; }
publishes backend && fail "backend port is published" || pass "backend port not published"
publishes db && fail "db port is published" || pass "db port not published"
publishes frontend && pass "frontend port published" || fail "frontend port not published"
echo "$ports" | grep '^frontend|' | grep -q '127\.0\.0\.1:' && ! echo "$ports" | grep '^frontend|' | grep -qE '0\.0\.0\.0|\[::\]' \
  && pass "frontend is bound to 127.0.0.1 only (running)" || fail "frontend is reachable beyond localhost: $(echo "$ports" | grep '^frontend|')"
curl -fsS -o /dev/null --max-time 10 "$FRONT" && pass "frontend answers on host" || fail "frontend does not answer"
contains "row selection handles missing year, empty table and out-of-range clicks" "ROW-SELECT-OK" "$(frontend_check 2>&1)"
contains "UI Save and Delete work end to end through Gradio" "UI-API-OK" "$(frontend_api_check 2>&1 | tail -5)"

# 3. CRUD through the API
out=$(api POST /books '{"title":"Clean Code","author":"Robert C. Martin","price":29.5,"year":2008}')
status_is "create book" 201 "$out"
id=$(echo "$out" | sed -E 's/.*"id":([0-9]+).*/\1/')
contains "list contains the book" "Clean Code" "$(api GET /books)"
status_is "get book by id" 200 "$(api GET "/books/$id")"
out=$(api PUT "/books/$id" '{"title":"Clean Code 2e","author":"Robert C. Martin","price":31,"year":2024}')
status_is "update book" 200 "$out"
contains "update is visible" "Clean Code 2e" "$out"

# A row that breaks the API's input rules (inserted behind its back, e.g. via psql) must not break the list.
badid=$(docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAq' <<'SQL' | sed -n 1p
insert into books(title, author, price, year) values ('', 'x', -1, 2200) returning id;
SQL
)
case "$badid" in ''|*[!0-9]*) fail "could not insert the out-of-range row (got: '$badid')" ;; esac
status_is "list survives a stored row that breaks the input rules" 200 "$(api GET /books)"
status_is "delete book" 204 "$(api DELETE "/books/$badid")"
status_is "deleted book is gone" 404 "$(api GET "/books/$badid")"

# 4. Validation and not-found (one violation per request)
status_is "empty title rejected" 422 "$(api POST /books '{"title":"","author":"x","price":1}')"
status_is "negative price rejected" 422 "$(api POST /books '{"title":"t","author":"x","price":-1}')"
status_is "year out of range rejected" 422 "$(api POST /books '{"title":"t","author":"x","price":1,"year":2200}')"
status_is "NUL character in title rejected" 422 "$(api POST /books '{"title":"a\u0000b","author":"x","price":1}')"
# Python's JSON parser accepts Infinity/1e400; stored as inf they cannot be rendered as JSON and would break every list.
status_is "price Infinity rejected" 422 "$(api POST /books '{"title":"t","author":"x","price":Infinity}')"
status_is "price 1e400 (overflows to infinity) rejected" 422 "$(api POST /books '{"title":"t","author":"x","price":1e400}')"
status_is "list still works after the rejected requests" 200 "$(api GET /books)"
status_is "unknown id returns 404" 404 "$(api GET /books/999999)"

# 5. Persistence across down and restart (volume kept)
docker compose down
docker compose up -d --wait --wait-timeout 120
contains "data survives 'down'" "Clean Code 2e" "$(api GET /books)"
docker compose restart >/dev/null
for s in db backend frontend; do wait_healthy "$s" 90 || fail "$s is not healthy after 'restart'"; done
contains "data survives 'restart'" "Clean Code 2e" "$(api GET /books)"

# 6. Database outage: 503 while down (never a bare 500), automatic recovery afterwards
docker compose stop db >/dev/null
status_is "health is 503 while db is down" 503 "$(api GET /health)"
status_is "CRUD routes return 503 while db is down" 503 "$(api GET /books)"
docker compose up -d --wait --wait-timeout 120
status_is "health recovers after db returns" 200 "$(api GET /health)"
contains "stale pooled connection is replaced (pool_pre_ping)" "PREPING-OK" "$(backend_pool_check 2>&1 | tail -3)"
contains "data still there after db restart" "Clean Code 2e" "$(api GET /books)"

# 7. Backend outage: the frontend must (re)start and serve even though the backend is down
#    (this is what happens after a host reboot, when all containers start at once).
docker compose stop backend >/dev/null
docker compose restart frontend >/dev/null
wait_healthy frontend 60 && pass "frontend restarts and turns healthy with backend down" \
  || fail "frontend cannot start while backend is down (state: $(docker compose ps --format '{{.Service}}={{.Status}}' | grep '^frontend='))"
curl -fsS -o /dev/null --max-time 10 "$FRONT" && pass "frontend serves with backend down" || fail "frontend does not serve with backend down"
docker compose up -d --wait --wait-timeout 120

# 8. down -v wipes the data
docker compose down -v
docker compose up -d --wait --wait-timeout 120
contains "data is gone after 'down -v'" "[]" "$(api GET /books)"

echo "ALL CHECKS PASSED"
