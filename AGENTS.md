# AGENTS.md

Bookstore 3 tầng (Gradio → FastAPI → PostgreSQL 17) chạy bằng Docker Compose — project đi kèm khóa Docker của VLAI
(https://vlai.aivietnam.edu.vn/tutorials/docker-tutorial). Đây là **phiên bản chạy được hoàn chỉnh**, dùng làm nguồn đối chiếu cho nội dung bài học.

## Chạy

```bash
cp .env.example .env                    # đổi POSTGRES_PASSWORD trước lần chạy đầu
docker compose up -d --build --wait     # build + chạy, chờ healthy
bash tests/smoke.sh                     # kiểm tra end-to-end, project Compose riêng (bookstore-smoke)
docker compose down                     # dừng, giữ volume pgdata (down -v xóa dữ liệu)
```

## Quy ước

- Chỉ `frontend` publish cổng, và chỉ trên `127.0.0.1`; `backend` và `db` nằm trong mạng `appnet`.
- Biến `POSTGRES_*` chỉ được PostgreSQL đọc khi volume `pgdata` được tạo; đổi sau đó cần `down -v`.
- Phiên bản gói khóa trong `*/constraints.txt`; không bỏ.
- Bài học dùng lệnh, đầu ra và cấu hình từ repo này (`compose.yaml`, `tests/smoke.sh`): đổi chúng thì bài học cần được sửa theo.
