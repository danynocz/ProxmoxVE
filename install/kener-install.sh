#!/usr/bin/env bash
# Kener install script for ProxmoxVE container
# Author: danynocz
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://kener.ing

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

APP="Kener"
header_info "$APP"
variables
color
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing dependencies"
$STD apt update
$STD apt install -y git apt-transport-https openssl lsb-release gnupg
msg_ok "Dependencies installed"

msg_info "Installing Docker"
$STD install -m 0755 -d /etc/apt/keyrings
$STD curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
$STD chmod a+r /etc/apt/keyrings/docker.asc

$STD tee > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable
EOF

$STD apt update
$STD apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
msg_ok "Docker installed"

msg_info "Creating Kener folder structure"
mkdir -p /opt/kener/uploads
chown -R root:root /opt/kener
msg_ok "Folder structure ready"

msg_info "Creating .env file"
cat > /opt/kener/.env <<EOF
KENER_SECRET_KEY=$(openssl rand -hex 32)
POSTGRES_USER=kener
POSTGRES_PASSWORD=$(openssl rand -hex 16)
POSTGRES_DB=kener
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASS=yourpassword
SMTP_SECURE=true
SMTP_FROM_EMAIL="Kener <noreply@example.com>"
EOF
msg_ok ".env file created at /opt/kener/.env"

HOST_IP=$(hostname -I | awk '{print $1}')

msg_info "Creating Docker Compose file for Kener"
cat > /opt/kener/docker-compose.yaml <<EOF
version: "3.8"

services:
  kener:
    image: rajnandan1/kener:latest
    container_name: kener
    environment:
      ORIGIN: http://${HOST_IP}:3000
      TZ: Europe/Prague
      KENER_SECRET_KEY: \${KENER_SECRET_KEY}
      DATABASE_URL: postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@postgres:5432/\${POSTGRES_DB}
#      SMTP_HOST: \${SMTP_HOST}
#      SMTP_PORT: \${SMTP_PORT}
#      SMTP_USER: \${SMTP_USER}
#      SMTP_PASS: \${SMTP_PASS}
#      SMTP_SECURE: \${SMTP_SECURE}
#      SMTP_FROM_EMAIL: \${SMTP_FROM_EMAIL}
    ports:
      - "3000:3000"
    volumes:
      - ./uploads:/app/uploads
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

  postgres:
    image: postgres:alpine
    container_name: postgres
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  pgdata:
    name: kener_postgres
EOF
msg_ok "Docker Compose file created at /opt/kener/docker-compose.yaml"

msg_info "Starting Kener Docker containers"
cd /opt/kener
$STD docker compose up -d
msg_ok "Kener containers are running"

motd_ssh
customize
cleanup_lxc
