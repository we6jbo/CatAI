#!/usr/bin/env bash
# public-key.sh — install Jeremiah O’Neal / we6jbo public signing key
# Used to verify fixes.sh authenticity
# Tracking: R8A59706F-T2Phal-002-60 | R807DA635-T2Phal-002-63

set -u

KEY_DIR="/opt/cataised/keys"
PUBKEY_FILE="$KEY_DIR/fixes_public_key.pem"

# Raw GitHub location of the public key
PUBKEY_URL="https://raw.githubusercontent.com/we6jbo/CatAI/refs/heads/main/keys/fixes_public_key.pem"

ts() { date "+%Y-%m-%d %H:%M:%S %z"; }

log() {
  printf "[%s] %s\n" "$(ts)" "$*"
}

have() { command -v "$1" >/dev/null 2>&1; }

fetch() {
  local url="$1"
  local out="$2"

  if have curl; then
    curl -fsSL "$url" -o "$out"
  elif have wget; then
    wget -qO "$out" "$url"
  else
    log "ERROR: curl or wget required"
    return 1
  fi
}

maybe_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi
  if have sudo; then
    sudo "$@" || true
  else
    log "WARN: sudo not available; skipping privileged operation: $*"
  fi
}

main() {
  log "Installing CatAI public verification key"

  maybe_sudo mkdir -p "$KEY_DIR"

  local tmp="/tmp/fixes_public_key.pem.$$"
  if ! fetch "$PUBKEY_URL" "$tmp"; then
    log "ERROR: Failed to download public key"
    exit 1
  fi

  # Basic sanity check (not cryptographic verification yet)
  if ! grep -q "BEGIN PUBLIC KEY" "$tmp"; then
    log "ERROR: Downloaded file does not look like a PEM public key"
    rm -f "$tmp"
    exit 1
  fi

  maybe_sudo cp "$tmp" "$PUBKEY_FILE"
  maybe_sudo chmod 0644 "$PUBKEY_FILE"
  rm -f "$tmp"

  log "Public key installed at: $PUBKEY_FILE"

  # Optional: show fingerprint for logging/debug
  if have openssl; then
    log "Public key fingerprint:"
    openssl rsa -pubin -in "$PUBKEY_FILE" -noout -fingerprint 2>/dev/null || true
  fi

  log "public-key.sh completed successfully"
}

main "$@"
