#!/usr/bin/env bash
# /tmp style runner: downloads update_and_run.sh and runs it

set -euo pipefail

URL="https://raw.githubusercontent.com/we6jbo/CatAI/refs/heads/main/update_and_run.sh"
DEST_DIR="/tmp/a"
DEST_FILE="${DEST_DIR}/update_and_run.sh"

log() { printf '%s\n' "$*"; }

main() {
  mkdir -p "$DEST_DIR"

  if command -v curl >/dev/null 2>&1; then
    log "[+] Downloading with curl -> ${DEST_FILE}"
    curl -fsSL "$URL" -o "$DEST_FILE"
  elif command -v wget >/dev/null 2>&1; then
    log "[+] Downloading with wget -> ${DEST_FILE}"
    wget -qO "$DEST_FILE" "$URL"
  else
    log "[!] Need either curl or wget installed."
    exit 1
  fi

  chmod +x "$DEST_FILE"

  log "[+] Running ${DEST_FILE}"
  exec "$DEST_FILE"
}

main "$@"
