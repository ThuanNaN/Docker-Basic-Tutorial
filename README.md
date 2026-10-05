# Docker Basic Tutorial - VLAI

Dự án thực hành cuối khóa **Docker Basic** của VLAI: một ứng dụng quản lý sách (Bookstore) gồm 3 tầng,
chạy hoàn toàn bằng Docker Compose.

```
Trình duyệt ──▶ frontend (Gradio :7860) ──▶ backend (FastAPI :8000) ──▶ db (PostgreSQL 17)
                  duy nhất cổng được publish     chỉ trong mạng appnet        volume pgdata
```

Khóa học: https://vlai.aivietnam.edu.vn/tutorials/docker-basic-tutorial

## Yêu cầu

- Docker Engine 29.x và Docker Compose v5.x (đã kiểm chứng: Engine 29.8.1, Compose v5.5.1, Ubuntu 24.04)
- Không cần cài Python hay PostgreSQL trên máy: mọi thứ chạy trong container.
- Dự án **độc lập**: chỉ cần clone repo này.

## Chạy bài lab

```bash
git clone https://github.com/ThuanNaN/Docker-Basic-Tutorial.git
cd Docker-Basic-Tutorial

cp .env.example .env          # đổi POSTGRES_PASSWORD nếu muốn, TRƯỚC lần chạy đầu tiên
docker compose up -d --build --wait   # build + chạy cả 3 dịch vụ, chờ tới khi healthy

docker compose ps             # db, backend, frontend đều (healthy)
```

Mở http://localhost:7860 để thêm, sửa, xóa sách.
Backend và database **không** được publish ra máy host; gọi API từ trong mạng Docker:

```bash
docker compose exec backend python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/books').read().decode())"
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
# trong psql gõ:  \dt   rồi   select * from books;   rồi   \q
```

(Lệnh `psql` lấy user và database từ biến môi trường của container nên luôn khớp với `.env`.)

Cổng 7860 bị chiếm? Đổi `FRONTEND_PORT` trong `.env`.

Giao diện chỉ mở trên **máy đang chạy lab** (`127.0.0.1`) vì nó không có đăng nhập. Chạy lab trên server từ xa?
Dùng SSH tunnel: `ssh -L 7860:localhost:7860 <user>@<server>` rồi mở http://localhost:7860 trên máy bạn.
(Muốn mở cho cả mạng: bỏ `127.0.0.1:` trong `compose.yaml`, và hãy thêm xác thực trước.)

> **Lưu ý về `.env`**
> - PostgreSQL chỉ đọc `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` **một lần**, khi volume `pgdata` được tạo.
>   Đổi chúng sau lần chạy đầu thì backend báo `password authentication failed` và không khởi động được.
>   Cách xử lý: `docker compose down -v` (xóa dữ liệu) rồi `docker compose up -d --build`.
> - `POSTGRES_PASSWORD` phải an toàn trong URL (chữ, số, `- _ . ~`): giá trị này nằm trong `DATABASE_URL` của backend.
>   Ký tự như `@`, `%`, `/`, `:` làm URL sai.

## Dừng và dọn dẹp

```bash
docker compose down       # dừng, xóa container + network, GIỮ dữ liệu (volume pgdata)
docker compose down -v    # xóa luôn volume: mất toàn bộ dữ liệu
```

> **Lưu ý:** cả 3 service dùng `restart: unless-stopped`, nên lab **tự chạy lại** mỗi khi Docker (hoặc máy)
> khởi động lại, cho tới khi bạn chạy `docker compose down` (hoặc `stop`). Học xong nhớ `down` để nó không chiếm
> tài nguyên và cổng 7860 ở nền.

## Kiểm tra tự động

```bash
bash tests/smoke.sh       # build stack, kiểm tra API, healthcheck, lưu trữ dữ liệu, rồi dọn sạch
```

Bài kiểm tra chạy trong project Compose riêng (`bookstore-smoke`, cổng 17860, đổi bằng `SMOKE_FRONTEND_PORT`),
nên **không** đụng tới stack và dữ liệu bạn đang chạy ở project `bookstore`.

## Cấu trúc

| Đường dẫn | Vai trò |
|---|---|
| `compose.yaml` | 3 service, mạng `appnet`, volume `pgdata`, healthcheck, thứ tự khởi động |
| `backend/` | FastAPI + SQLAlchemy, Dockerfile multi-stage chạy bằng user thường |
| `frontend/` | Giao diện Gradio gọi backend qua `http://backend:8000` |
| `*/constraints.txt` | Khóa phiên bản mọi gói phụ thuộc (kết quả `pip freeze`) để build lại luôn ra cùng kết quả |
| `.env.example` | Mẫu cấu hình (`.env` không được commit) |
| `tests/smoke.sh` | Kiểm tra end-to-end |

## Cấu trúc khóa học

| Phần | Nội dung |
|---|---|
| 1 | Giới thiệu Docker và các khái niệm cốt lõi |
| 2 | Cài đặt và bước khởi đầu |
| 3 | CLI cơ bản: vòng đời container |
| 4 | Docker image và Dockerfile |
| 5 | Registry và chia sẻ image |
| 6 | Dữ liệu: volume, bind mount, tmpfs |
| 7 | Networking: container nói chuyện với nhau |
| 8 | Docker Compose |
| 9 | Best practices, tối ưu và bảo mật |
| Lab | Bài lab tổng hợp: Gradio + FastAPI + PostgreSQL (repo này) |

Học tiếp: khóa **Docker Advanced** (tối ưu image, bảo mật, observability, CI/CD, AI) dùng lại chính dự án này.
