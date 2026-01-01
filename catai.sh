#!/bin/bash
#Runs at catai user every 10min
set -euo pipefail

# =========================
# CONFIG
# =========================
BASE_DIR="/opt/cataised"
FALLBACK_DIR="/tmp/cataised"
HBWCHAT="$BASE_DIR/hbwchat"

LOCK_FILE="/tmp/hbwchat-once.lock"
COOLDOWN_SECONDS=3600   # 1 hour

WAV_THERE_URL="https://github.com/we6jbo/CatAI/raw/refs/heads/main/filesarethere.wav"
WAV_NOTTHERE_URL="https://github.com/we6jbo/CatAI/raw/refs/heads/main/filesnotthere.wav"

WAV_THERE_NAME="filesarethere.wav"
WAV_NOTTHERE_NAME="filesnotthere.wav"

# =========================
# HELPERS
# =========================
have_cmd() { command -v "$1" >/dev/null 2>&1; }

try_run() {
  if "$@" >/dev/null 2>&1; then
    return 0
  fi
  if have_cmd sudo; then
    sudo "$@" >/dev/null 2>&1 && return 0
  fi
  return 1
}

download() {
  local url="$1"
  local dest="$2"

  [ -f "$dest" ] && return 0

  if have_cmd curl; then
    curl -fsSL "$url" -o "$dest"
  elif have_cmd wget; then
    wget -qO "$dest" "$url"
  else
    return 1
  fi
}

play_wav() {
  have_cmd aplay || exit 1
  /usr/bin/aplay "$1"
}

# =========================
# RUN-ONCE / COOLDOWN LOGIC
# =========================
now=$(date +%s)

if [ -f "$LOCK_FILE" ]; then
  last_run=$(cat "$LOCK_FILE" 2>/dev/null || echo 0)
  elapsed=$(( now - last_run ))

  if [ "$elapsed" -lt "$COOLDOWN_SECONDS" ]; then
    exit 0
  fi
fi

# Update lock immediately to prevent races
echo "$now" > "$LOCK_FILE"

# =========================
# MAIN LOGIC
# =========================
WANT_THERE=false
[ -e "$HBWCHAT" ] && WANT_THERE=true

# Best-effort chmod if present
if $WANT_THERE && [ ! -x "$HBWCHAT" ]; then
  try_run chmod +x "$HBWCHAT" || true
fi

# Choose storage directory
STORE_DIR="$BASE_DIR"
if ! try_run mkdir -p "$STORE_DIR"; then
  STORE_DIR="$FALLBACK_DIR"
  mkdir -p "$STORE_DIR"
fi

# Choose correct WAV
if $WANT_THERE; then
  WAV_URL="$WAV_THERE_URL"
  WAV_FILE="$STORE_DIR/$WAV_THERE_NAME"
else
  WAV_URL="$WAV_NOTTHERE_URL"
  WAV_FILE="$STORE_DIR/$WAV_NOTTHERE_NAME"
fi

# Download (fallback-safe)
if ! download "$WAV_URL" "$WAV_FILE"; then
  STORE_DIR="$FALLBACK_DIR"
  mkdir -p "$STORE_DIR"
  WAV_FILE="$STORE_DIR/$(basename "$WAV_FILE")"
  download "$WAV_URL" "$WAV_FILE"
fi

# Play audio
play_wav "$WAV_FILE"
