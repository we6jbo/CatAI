#!/usr/bin/env bash
# fixes.sh — weekly CatAI self-heal (flag + tmp + repo presence)
# Tracking: R8A59706F-T2Phal-002-60 | R807DA635-T2Phal-002-63

set -u

BASE="/opt/cataised"
LOG_DIR="$BASE"
LOG_FILE="$LOG_DIR/fixes.log"
LAST="/tmp/cataised-fixes-last.txt"

FLAG_TARGET="/usr/local/bin/cataidse"
TMP_MARKER="/tmp/cataised.tmp"

ts() { date "+%Y-%m-%d %H:%M:%S %z"; }

mkdir -p "$LOG_DIR" 2>/dev/null || true

log() {
  local msg="$*"
  printf "[%s] %s\n" "$(ts)" "$msg" | tee -a "$LOG_FILE" >"$LAST" 2>/dev/null || true
}

have() { command -v "$1" >/dev/null 2>&1; }

run() {
  local cmd="$*"
  log "RUN: $cmd"
  bash -lc "$cmd" >>"$LOG_FILE" 2>&1 || log "WARN: command failed (non-fatal): $cmd"
}

maybe_sudo() {
  local cmd="$*"
  if [ "$(id -u)" -eq 0 ]; then
    run "$cmd"
    return
  fi
  if have sudo; then
    log "Attempting with sudo: $cmd"
    sudo -n bash -lc "$cmd" >>"$LOG_FILE" 2>&1 || log "WARN: sudo failed (non-fatal): $cmd"
  else
    log "WARN: sudo not available; skipping privileged command: $cmd"
  fi
}

ensure_tmp_marker() {
  if [ -f "$TMP_MARKER" ]; then
    log "OK: tmp marker present: $TMP_MARKER"
    return 0
  fi
  log "Creating tmp marker: $TMP_MARKER"
  run "printf 'created %s\n' \"$(ts)\" > \"$TMP_MARKER\""
}

ensure_repo_dir() {
  if [ -d "$BASE" ]; then
    log "OK: git_dir present: $BASE"
  else
    log "ERROR: git_dir missing: $BASE (expected repo directory)"
  fi
}

pick_flag_source() {
  # Choose the best candidate in /opt/cataised to link/copy to /usr/local/bin/cataidse
  # Priority order is conservative. Add more names if you have them.
  local candidates=(
    "$BASE/cataidse"
    "$BASE/cataised"
    "$BASE/agent.sh"
    "$BASE/client.sh"
    "$BASE/server.sh"
    "$BASE/run.sh"
  )

  local f
  for f in "${candidates[@]}"; do
    if [ -e "$f" ]; then
      echo "$f"
      return 0
    fi
  done

  echo ""
  return 0
}

ensure_flag_target() {
  # Main fix for: flag(/usr/local/bin/cataidse): missing
  if [ -e "$FLAG_TARGET" ]; then
    if [ -x "$FLAG_TARGET" ]; then
      log "OK: flag present and executable: $FLAG_TARGET"
      return 0
    fi

    log "Flag exists but not executable: $FLAG_TARGET"
    maybe_sudo "chmod +x \"$FLAG_TARGET\""
    if [ -x "$FLAG_TARGET" ]; then
      log "FIXED: made executable: $FLAG_TARGET"
    else
      log "WARN: could not chmod +x (needs sudo): $FLAG_TARGET"
    fi
    return 0
  fi

  log "Flag missing: $FLAG_TARGET"
  local src
  src="$(pick_flag_source)"

  if [ -z "$src" ]; then
    log "ERROR: No source candidate found in $BASE to link/copy into $FLAG_TARGET"
    log "       Add a file like $BASE/cataidse (or update candidates list in fixes.sh)."
    return 1
  fi

  log "Using source candidate: $src"

  # Make sure source is executable (does not require sudo)
  if [ -f "$src" ] && [ ! -x "$src" ]; then
    run "chmod +x \"$src\""
  fi

  # Prefer symlink; fall back to copy if symlink fails
  maybe_sudo "ln -sf \"$src\" \"$FLAG_TARGET\""
  if [ ! -e "$FLAG_TARGET" ]; then
    log "Symlink failed or not permitted; trying copy instead."
    maybe_sudo "cp -f \"$src\" \"$FLAG_TARGET\""
  fi

  maybe_sudo "chmod +x \"$FLAG_TARGET\""

  if [ -x "$FLAG_TARGET" ]; then
    log "FIXED: flag installed and executable: $FLAG_TARGET"
    return 0
  fi

  log "WARN: flag still missing/not executable (likely sudo issue): $FLAG_TARGET"
  return 1
}

report_status_like_remote() {
  # This mimics the remote status lines so you can quickly compare
  log "STATUS: time: $(ts)"
  if [ -x "$FLAG_TARGET" ]; then
    log "STATUS: flag($FLAG_TARGET): present+executable"
  elif [ -e "$FLAG_TARGET" ]; then
    log "STATUS: flag($FLAG_TARGET): present-not-executable"
  else
    log "STATUS: flag($FLAG_TARGET): missing"
  fi

  if [ -f "$TMP_MARKER" ]; then
    log "STATUS: tmp($TMP_MARKER): present"
  else
    log "STATUS: tmp($TMP_MARKER): missing"
  fi

  if [ -d "$BASE" ]; then
    log "STATUS: git_dir($BASE): present"
  else
    log "STATUS: git_dir($BASE): missing"
  fi
}

main() {
  log "=== START fixes.sh ==="
  log "Running as: $(id)"

  ensure_repo_dir
  ensure_tmp_marker
  ensure_flag_target || true

  report_status_like_remote

  log "=== END fixes.sh ==="
  log "Last-run quick log: $LAST"
}

main "$@"

