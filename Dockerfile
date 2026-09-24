FROM python:3.12-slim AS builder
WORKDIR /build
COPY app/requirements.txt .
RUN pip install --no-cache-dir --target=/build/vendor -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /build/vendor /usr/local/lib/python3.12/site-packages
COPY app/app.py .
COPY app/ .
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
