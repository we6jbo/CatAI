#!/usr/bin/env bash
# fixes.sh — CatAI self-heal: unblock git pull conflicts + status prerequisites
# Tracking: R8A59706F-T2Phal-002-60 | R807DA635-T2Phal-002-63

set -u

REPO_DIR="/opt/cataised"
LOG_DIR="/opt/cataised"
LOG_FILE="${LOG_DIR}/fixes.log"
LAST="/tmp/cataised-fixes-last.txt"

# Problem files from your log (examples; script now stashes *everything*)
FILE_A="10min.sh"
FILE_B="playscript4.sh"
FILE_C="keys/fixes_public_key.pem"

# Where to move untracked conflicts (keeps them safe)
QUAR_DIR="/opt/cataised-local-keys"

LOCK="/tmp/cataised-fixes.lock"

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

die() {
  log "ERROR: $*"
  exit 1
}

with_lock_or_exit() {
  # simple lock: prevents overlapping cron/manual runs
  if [ -e "$LOCK" ]; then
    log "Lock exists ($LOCK). Another run may be in progress; exiting."
    exit 0
  fi
  echo "$$" >"$LOCK"
  trap 'rm -f "$LOCK"' EXIT
}

is_tracked() {
  # returns 0 if file is tracked by git, else 1
  git -C "$REPO_DIR" ls-files --error-unmatch "$1" >/dev/null 2>&1
}

is_modified_tracked() {
  # returns 0 if tracked file has local modifications, else 1
  git -C "$REPO_DIR" diff --name-only -- "$1" | grep -q .
}

is_untracked_exists() {
  # returns 0 if file exists and is untracked, else 1
  local f="$1"
  [ -e "$REPO_DIR/$f" ] || return 1
  is_tracked "$f" && return 1
  return 0
}


stash_all_if_needed() {
  # Stash *all* local changes (including untracked files) so git pull can run cleanly.
  # This prevents errors like:
  #   "Your local changes to the following files would be overwritten by merge"
  # and ensures new files can be pulled from GitHub.
  local porcelain
  porcelain="$(git -C "$REPO_DIR" status --porcelain 2>/dev/null || true)"
  if [ -n "$porcelain" ]; then
    log "Local changes detected; stashing ALL changes (including untracked)"
    git -C "$REPO_DIR" stash push -u -m "auto-stash before pull $(date +%F_%H%M%S)" \
      >>"$LOG_FILE" 2>&1 || log "WARN: stash-all failed (non-fatal)"
  else
    log "Working tree clean; no stash needed"
  fi
}

stash_one_if_needed() {
  local f="$1"
  if is_tracked "$f" && is_modified_tracked "$f"; then
    log "Tracked file modified locally; stashing: $f"
    git -C "$REPO_DIR" stash push -m "auto-stash before pull $(date +%F_%H%M) -- $f" -- "$f" \
      >>"$LOG_FILE" 2>&1 || log "WARN: stash failed for $f"
  else
    log "No tracked modifications to stash for: $f"
  fi
}

quarantine_untracked_if_needed() {
  local f="$1"
  if is_untracked_exists "$f"; then
    log "Untracked file conflicts with pull; quarantining: $f"
    mkdir -p "$QUAR_DIR" 2>/dev/null || true
    local src="$REPO_DIR/$f"
    local dst="$QUAR_DIR/$(basename "$f").$(date +%F_%H%M%S)"
    mv -v "$src" "$dst" >>"$LOG_FILE" 2>&1 || log "WARN: move failed for $src"
  else
    log "No untracked conflict to quarantine for: $f"
  fi
}

git_pull_safe() {
  have git || die "git not found"

  [ -d "$REPO_DIR/.git" ] || die "Not a git repo: $REPO_DIR"

  log "Git status (porcelain) before:"
  git -C "$REPO_DIR" status --porcelain >>"$LOG_FILE" 2>&1 || true

# Stash everything so pulls never fail due to local edits or untracked files
stash_all_if_needed

  log "Fetching remote"
  git -C "$REPO_DIR" fetch --all --prune >>"$LOG_FILE" 2>&1 || log "WARN: git fetch failed"

  # Use ff-only so we never create a merge commit automatically
  log "Pulling updates from remote (fast-forward only)"
  if git -C "$REPO_DIR" pull --ff-only >>"$LOG_FILE" 2>&1; then
    log "git pull --ff-only succeeded"

log "NOTE: Any stashed local changes remain saved. To restore later:"
log "  cd $REPO_DIR && git stash list"
log "  cd $REPO_DIR && git stash pop"
  else
    log "WARN: git pull --ff-only failed (repo may require manual intervention)"
    return 1
  fi

  log "Git status (porcelain) after:"
  git -C "$REPO_DIR" status --porcelain >>"$LOG_FILE" 2>&1 || true

  return 0
}

ensure_status_prereqs() {
  # These mirror your status checks:
  # flag(/usr/local/bin/cataidse): missing
  # tmp(/tmp/cataised.tmp): present
  # git_dir(/opt/cataised): present

  local flag="/usr/local/bin/cataidse"
  local tmp="/tmp/cataised.tmp"

  if [ -d "$REPO_DIR" ]; then
    log "OK: git_dir($REPO_DIR): present"
  else
    log "ERROR: git_dir($REPO_DIR): missing"
  fi

  if [ -f "$tmp" ]; then
    log "OK: tmp($tmp): present"
  else
    log "Creating tmp marker: $tmp"
    run "printf 'created %s\n' \"$(ts)\" > \"$tmp\""
  fi

  if [ -x "$flag" ]; then
    log "OK: flag($flag): present+executable"
  else
    log "Flag missing or not executable: $flag (not fixing here unless you want it added)"
  fi
}

main() {
  with_lock_or_exit

  log "=== START fixes.sh ==="
  log "Running as: $(id)"
  log "Repo: $REPO_DIR"

  git_pull_safe || true
  ensure_status_prereqs

  log "=== END fixes.sh ==="
  log "Last-run quick log: $LAST"
}
touch /tmp/jonealworking.txt
main "$@"
