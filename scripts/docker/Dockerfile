# Daemon devtools chạy trong Docker trên server Ubuntu.
# Binary tĩnh (CGO_ENABLED=0, sqlite pure-Go) nên chỉ cần alpine + ca-certificates
# (cho TLS outbound tới relay UltraViewer / RDP).
# Build binary bằng scripts/build-devtools-server.ps1 trên Windows rồi copy
# file dev-tool-daemon-server vào cùng thư mục với Dockerfile này.
FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app
COPY dev-tool-daemon-server /app/dev-tool-daemon-server
RUN chmod +x /app/dev-tool-daemon-server

# Web UI (1403) + API/WebSocket (7777)
EXPOSE 1403 7777

# config.json + database nằm trong /app/config (mount volume từ compose)
# để persist qua các lần upgrade container.
ENTRYPOINT ["/app/dev-tool-daemon-server"]
