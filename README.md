# Docker Basic Tutorial - VLAI
# Hướng dẫn xây dựng, đóng gói và triển khai ứng dụng bằng Docker
# từ Container, Image, Volume, Network đến Docker Compose và các workflow thực tế.
#
# Website: https://vlai.aivietnam.edu.vn/tutorials/docker-basic-tutorial

# --- Nền tảng ---

## Yêu cầu
- Docker Engine 29.7.2+
- Docker Compose v5.4.0+
- Python 3.12+
- Ubuntu 24.04 (x86_64) hoặc tương đương

## Cài đặt
Xem [Phần 2 - Cài đặt và bước đầu](part-02-installation.md)

# --- Cấu trúc khóa học ---

| Chương | Nội dung |
|--------|----------|
| Phần 1 | Giới thiệu Docker & các khái niệm cốt lõi |
| Phần 2 | Cài đặt và bước đầu |
| Phần 3 | CLI cơ bản: vòng đời container |
| Phần 4 | Docker image & Dockerfile |
| Phần 5 | Registry & chia sẻ image |
| Phần 6 | Dữ liệu: volume, bind mount, tmpfs |
| Phần 7 | Networking: container nói chuyện với nhau |
| Phần 8 | Docker Compose |
| Phần 9 | Best practices & bảo mật |
| Phần 10 | Production: Swarm, Kubernetes, CI/CD |
| Lab | Bài lab tổng hợp: web-app 3 tầng |

# --- Chạy bài lab ---

```bash
# Build và chạy toàn bộ ứng dụng 3 tầng
docker compose up -d --build

# Kiểm tra
docker compose ps
curl http://localhost:8090

# Dừng (giữ volume)
docker compose down

# Dừng và xóa toàn bộ dữ liệu
docker compose down -v
```
