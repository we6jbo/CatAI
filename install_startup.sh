#!/bin/bash
set -euo pipefail

BASE_DIR="/opt/cataised"

# NOTE: These services run as root. If you want them to run as "pi", change User=pi.
make_service() {
  local name="$1"
  local exec_path="$2"
  local svc_path="/etc/systemd/system/${name}.service"

  cat > "$svc_path" <<EOF
[Unit]
Description=CatAI ${name}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${exec_path}
WorkingDirectory=${BASE_DIR}
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
}

# Create services for each script
make_service "cataised-init"    "${BASE_DIR}/init.sh"
make_service "cataised-monitor" "${BASE_DIR}/monitor.sh"
make_service "cataised-chatter" "${BASE_DIR}/chatter.sh"

systemctl daemon-reload
systemctl enable cataised-init.service
systemctl enable cataised-monitor.service
systemctl enable cataised-chatter.service

# Start immediately too (optional; remove if you only want next boot)
systemctl start cataised-init.service || true
systemctl start cataised-monitor.service || true
systemctl start cataised-chatter.service || true

echo "Installed and enabled systemd boot services for init.sh, monitor.sh, chatter.sh"
