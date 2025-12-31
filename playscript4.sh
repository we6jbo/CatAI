#!/bin/bash
set -euo pipefail
mv /opt/cataised/playscript2.sh /opt/cataised/playscript2_OLD.sh
chmod +x /opt/cataised/install_startup.sh

BASE_DIR="/opt/cataised"
MARKER="$BASE_DIR/didit.txt"

INIT="$BASE_DIR/init.sh"
MON="$BASE_DIR/monitor.sh"
CHAT="$BASE_DIR/chatter.sh"

# Always append a line to didit.txt
mkdir -p "$BASE_DIR"
NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

if [ ! -f "$MARKER" ]; then
  # First run (marker did not exist)
  echo "$NOW FIRST_RUN playscript4.sh" >> "$MARKER"

  # Ensure scripts exist (or at least warn)
  for f in "$INIT" "$MON" "$CHAT"; do
    if [ ! -f "$f" ]; then
      echo "$NOW WARNING missing: $f" >> "$MARKER"
    else
      chmod +x "$f"
    fi
  done

  # Install/enable systemd services to run on boot
  "$BASE_DIR/install_startup.sh" >> "$MARKER" 2>&1

else
  # Not first run
  echo "$NOW RUN playscript4.sh" >> "$MARKER"
fi
