# --- Stage 1: install dependencies into an isolated prefix ---
FROM python:3.12-slim AS builder
WORKDIR /build
# constraints.txt pins every transitive package (pip freeze of a known-good build) so rebuilds are reproducible.
COPY requirements.txt constraints.txt ./
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt -c constraints.txt

# --- Stage 2: runtime image, no build tools, non-root ---
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app ./app
USER appuser
EXPOSE 8000
# slim has no curl: use the Python stdlib. A non-200 (e.g. 503) makes urlopen raise -> exit 1.
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
