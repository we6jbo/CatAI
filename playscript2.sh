#!/usr/bin/env bash
# R8A59706F-T2Phal-002-60
set -euo pipefail

SERVICE_NAME="rpichat-client.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

HOST="192.168.5.146"
PORT="4495"
RECONNECT_SECONDS="900"  # 15 minutes

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rpichat-client"
MARKER_FILE="/var/lib/rpichat-client/.installed_configured"

OUTBOX="/var/lib/rpichat-client/outbox.txt"
INBOX="/var/log/rpichat-client/inbox.log"

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Please run as root (use sudo)." >&2
    exit 1
  fi
}

already_configured() {
  # If marker exists AND service file exists AND service is enabled, treat as configured.
  if [[ -f "${MARKER_FILE}" && -f "${SERVICE_PATH}" ]]; then
    if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

python_pkg_installed() {
  # Check if the module can be imported
  python3 -c "import rpichat_client" >/dev/null 2>&1
}

install_python_pkg_if_needed() {
  if python_pkg_installed; then
    echo "[OK] Python package rpichat-client already installed."
    return 0
  fi

  if [[ ! -d "${PKG_DIR}" ]]; then
    echo "ERROR: Package directory not found: ${PKG_DIR}" >&2
    echo "Expected: ${PKG_DIR}/pyproject.toml" >&2
    exit 1
  fi

  echo "[..] Installing rpichat-client from ${PKG_DIR}"
  python3 -m pip install --upgrade pip >/dev/null
  python3 -m pip install "${PKG_DIR}"
  echo "[OK] Installed rpichat-client."
}

setup_dirs_if_needed() {
  mkdir -p /var/lib/rpichat-client
  mkdir -p /var/log/rpichat-client

  # Create files if missing (don’t overwrite)
  [[ -f "${OUTBOX}" ]] || touch "${OUTBOX}"
  [[ -f "${INBOX}" ]]  || touch "${INBOX}"

  chown -R root:root /var/lib/rpichat-client /var/log/rpichat-client
  chmod 755 /var/lib/rpichat-client /var/log/rpichat-client
  chmod 644 "${OUTBOX}" "${INBOX}"

  echo "[OK] Directories/log files present."
}

install_service_if_needed() {
  if [[ -f "${SERVICE_PATH}" ]]; then
    echo "[OK] Systemd service file already exists: ${SERVICE_PATH}"
    return 0
  fi

  echo "[..] Writing systemd unit: ${SERVICE_PATH}"
  cat > "${SERVICE_PATH}" <<EOF
# R8A59706F-T2Phal-002-60
[Unit]
Description=Raspberry Pi TCP chat client with stats responder
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/rpichat-client --daemon --host ${HOST} --port ${PORT} --reconnect-seconds ${RECONNECT_SECONDS}
Restart=always
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/var/lib/rpichat-client /var/log/rpichat-client

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  echo "[OK] Installed systemd unit."
}

enable_start_service() {
  echo "[..] Enabling + starting ${SERVICE_NAME}"
  systemctl enable --now "${SERVICE_NAME}"
  echo "[OK] Service enabled and started."
}

write_marker() {
  # Record config so we can cleanly short-circuit next time
  cat > "${MARKER_FILE}" <<EOF
# R8A59706F-T2Phal-002-60
installed_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
host=${HOST}
port=${PORT}
reconnect_seconds=${RECONNECT_SECONDS}
outbox=${OUTBOX}
inbox=${INBOX}
EOF
  chmod 644 "${MARKER_FILE}"
  echo "[OK] Wrote marker: ${MARKER_FILE}"
}

main() {
  need_root

  if already_configured; then
    echo "[OK] Already installed/configured. Doing nothing."
    echo "Marker: ${MARKER_FILE}"
    exit 0
  fi

  install_python_pkg_if_needed
  setup_dirs_if_needed
  install_service_if_needed
  enable_start_service
  write_marker

  echo
  echo "[DONE]"
  echo "Send a message (headless mode):"
  echo "  echo \"hello\" | sudo tee -a ${OUTBOX}"
  echo
  echo "View log:"
  echo "  sudo tail -f ${INBOX}"
  echo
  echo "Service status:"
  echo "  sudo systemctl status ${SERVICE_NAME} --no-pager"
}

main "$@"
