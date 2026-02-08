#!/usr/bin/env bash
# Kener install script for ProxmoxVE container (Bare Metal, No Docker)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: danynocz
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://kener.ing

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing base dependencies"
$STD apt update
$STD apt install -y \
  git \
  curl \
  ca-certificates \
  openssl \
  sqlite3 \
  build-essential
msg_ok "Base dependencies installed"

msg_info "Installing Node.js 20 (NodeSource)"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
$STD apt install -y nodejs
msg_ok "Node.js installed"

msg_info "Verifying Node.js & npm"
node -v
npm -v
msg_ok "Node.js & npm verified"

msg_info "Cloning Kener repository"
git clone https://github.com/rajnandan1/kener.git /opt/kener
cd /opt/kener
msg_ok "Repository cloned"

msg_info "Installing Node dependencies"
$STD npm install
msg_ok "Dependencies installed"

msg_info "Creating .env file"
cat <<EOF >/opt/kener/.env
HOST=0.0.0.0
PORT=3000
ORIGIN=http://localhost:3000
KENER_SECRET_KEY=$(openssl rand -hex 32)
EOF
msg_ok ".env file created"

msg_info "Preparing SQLite database"
$STD npm exec knex migrate:latest
$STD npm exec knex seed:run
msg_ok "Database initialized"

msg_info "Creating systemd service"
cat <<EOF >/etc/systemd/system/kener.service
[Unit]
Description=Kener Status Page
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/kener
ExecStart=/usr/bin/npm exec vite dev -- --host 0.0.0.0 --port 3000
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

$STD systemctl daemon-reexec
$STD systemctl daemon-reload
$STD systemctl enable kener
$STD systemctl start kener
msg_ok "Kener service started"

msg_ok "Kener is running on port 3000"

motd_ssh
customize
cleanup_lxc
