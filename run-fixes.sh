#!/usr/bin/env bash
# run-fixes.sh — secure updater + verifier + runner

set -u

BASE="/opt/cataised-fixes"
SCRIPT="$BASE/fixes.sh"
SIG="$BASE/fixes.sh.sig"
PUBKEY="/opt/cataised/keys/fixes_public_key.pem"
LOG="/opt/cataised/fixes.log"

FIXES_URL="https://raw.githubusercontent.com/we6jbo/CatAI/refs/heads/main/fixes.sh"
SIG_URL="https://raw.githubusercontent.com/we6jbo/CatAI/refs/heads/main/fixes.sh.sig"

mkdir -p "$BASE" 2>/dev/null || true

ts() { date "+%Y-%m-%d %H:%M:%S %z"; }
log() { printf "[%s] %s\n" "$(ts)" "$*" >>"$LOG"; }

fetch() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    log "ERROR: curl or wget required"
    exit 1
  fi
}

# --- HARD SAFETY CHECKS ---
[ -s "$PUBKEY" ] || { log "ERROR: Public key missing: $PUBKEY"; exit 1; }
command -v openssl >/dev/null 2>&1 || { log "ERROR: openssl missing"; exit 1; }

log "Fetching fixes.sh"
fetch "$FIXES_URL" "$SCRIPT" || exit 1

log "Fetching fixes.sh.sig"
fetch "$SIG_URL" "$SIG" || exit 1

log "Verifying signature"
if ! openssl dgst -sha256 -verify "$PUBKEY" -signature "$SIG" "$SCRIPT" >/dev/null 2>&1; then
  log "ERROR: Signature verification FAILED — refusing to run"
  exit 1
fi

log "Signature verified OK"
chmod +x "$SCRIPT" 2>/dev/null || true

log "Executing fixes.sh"
exec /bin/bash "$SCRIPT"
