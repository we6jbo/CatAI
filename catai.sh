#!/bin/bash
#Runs at catai user every 10min
set -euo pipefail

BASE_DIR="/opt/cataised"
FALLBACK_DIR="/tmp/cataised"
HBWCHAT="$BASE_DIR/hbwchat"

WAV_THERE_URL="https://github.com/we6jbo/CatAI/raw/refs/heads/main/filesarethere.wav"
WAV_NOTTHERE_URL="https://github.com/we6jbo/CatAI/raw/refs/heads/main/filesnotthere.wav"

WAV_THERE_NAME="filesarethere.wav"
WAV_NOTTHERE_NAME="filesnotthere.wav"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

try_run() {
  # Try command normally; if it fails and sudo exists, try with sudo.
  # If both fail, return non-zero.
  if "$@"; then
    return 0
  fi
  if have_cmd sudo; then
    sudo "$@" && return 0
  fi
  return 1
}

download() {
  local url="$1"
  local dest="$2"

  if [ -f "$dest" ]; then
    return 0
  fi

  if have_cmd curl; then
    curl -fsSL "$url" -o "$dest"
  elif have_cmd wget; then
    wget -qO "$dest" "$url"
  else
    echo "ERROR: Need curl or wget to download WAV files." >&2
    return 1
  fi
}

play_wav() {
  local path="$1"
  if ! have_cmd aplay; then
    echo "ERROR: 'aplay' not found (install alsa-utils)." >&2
    exit 1
  fi
  /usr/bin/aplay "$path"
}

# Decide which WAV we should play (based on whether hbwchat exists)
WANT_THERE=false
if [ -e "$HBWCHAT" ]; then
  WANT_THERE=true
fi

# If hbwchat exists, try to make it executable (best effort; skip on failure)
if $WANT_THERE; then
  if [ ! -x "$HBWCHAT" ]; then
    try_run chmod +x "$HBWCHAT" >/dev/null 2>&1 || true
  fi
fi

# Try to use /opt/cataised; otherwise fall back to /tmp/cataised for WAV storage
STORE_DIR="$BASE_DIR"
if ! try_run mkdir -p "$STORE_DIR" >/dev/null 2>&1; then
  STORE_DIR="$FALLBACK_DIR"
  mkdir -p "$STORE_DIR"
fi

# Pick correct wav + url
if $WANT_THERE; then
  WAV_URL="$WAV_THERE_URL"
  WAV_FILE="$STORE_DIR/$WAV_THERE_NAME"
else
  WAV_URL="$WAV_NOTTHERE_URL"
  WAV_FILE="$STORE_DIR/$WAV_NOTTHERE_NAME"
fi

# Download (best effort into chosen dir; if it fails in /opt, fall back to /tmp)
if ! download "$WAV_URL" "$WAV_FILE" >/dev/null 2>&1; then
  # If we were trying /opt and it failed, fall back to /tmp and try again.
  if [ "$STORE_DIR" = "$BASE_DIR" ]; then
    STORE_DIR="$FALLBACK_DIR"
    mkdir -p "$STORE_DIR"
    if $WANT_THERE; then
      WAV_FILE="$STORE_DIR/$WAV_THERE_NAME"
    else
      WAV_FILE="$STORE_DIR/$WAV_NOTTHERE_NAME"
    fi
    download "$WAV_URL" "$WAV_FILE"
  else
    # Already on fallback; surface error
    download "$WAV_URL" "$WAV_FILE"
  fi
fi

# Play the correct wav (always)
play_wav "$WAV_FILE"
