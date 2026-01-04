#!/usr/bin/env bash
# /opt/catai2/update_and_run.sh
#
# Purpose:
# - Ensure /opt/catai2 exists
# - Clone https://github.com/we6jbo/catai2 into /opt/catai2/catai2 if missing
# - If already present, update it (fetch + fast-forward pull)
# - Run 10min.sh from that repo
#
# Notes:
# - This script does NOT require root, but /opt/catai2 typically does.
#   If you can't write to /opt, run it once with sudo to create/chown the folder,
#   or adjust DEST_BASE to somewhere you own (like ~/catai2).

set -euo pipefail

REPO_URL="https://github.com/we6jbo/catai2"
DEST_BASE="/opt/catai2"
DEST_REPO="${DEST_BASE}/catai2"
RUN_SCRIPT="10min.sh"

log() { printf '%s\n' "$*"; }

ensure_dir() {
  if [[ -d "$DEST_BASE" ]]; then
    return 0
  fi

  log "[+] Creating ${DEST_BASE}"
  if mkdir -p "$DEST_BASE" 2>/dev/null; then
    return 0
  fi

  log "[!] Could not create ${DEST_BASE} without elevated permissions."
  log "    Try: sudo mkdir -p ${DEST_BASE} && sudo chown -R \"$(id -un)\":\"$(id -gn)\" ${DEST_BASE}"
  exit 1
}

clone_or_update() {
  if [[ ! -d "$DEST_REPO/.git" ]]; then
    # If the directory exists but isn't a git repo, we don't want to blow it away silently.
    if [[ -e "$DEST_REPO" && ! -d "$DEST_REPO/.git" ]]; then
      log "[!] ${DEST_REPO} exists but is not a git repository. Refusing to overwrite."
      log "    Move it aside or delete it, then rerun."
      exit 1
    fi

    log "[+] Cloning ${REPO_URL} -> ${DEST_REPO}"
    git clone "$REPO_URL" "$DEST_REPO"
    return 0
  fi

  log "[+] Updating existing repo in ${DEST_REPO}"
  (
    cd "$DEST_REPO"
    # Clean, safe update: fetch then fast-forward only
    git fetch --prune origin
    # Identify current branch (handles main/master/etc.)
    current_branch="$(git rev-parse --abbrev-ref HEAD)"
    # Fast-forward pull only (won't create merges)
    git pull --ff-only origin "$current_branch"
  )
}

run_10min() {
  local script_path="${DEST_REPO}/${RUN_SCRIPT}"

  if [[ ! -f "$script_path" ]]; then
    log "[!] ${RUN_SCRIPT} not found at: ${script_path}"
    exit 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log "[+] Making ${RUN_SCRIPT} executable"
    chmod +x "$script_path" || {
      log "[!] Could not chmod +x ${script_path}"
      exit 1
    }
  fi

  log "[+] Running ${RUN_SCRIPT} from ${DEST_REPO}"
  (
    cd "$DEST_REPO"
    exec "./${RUN_SCRIPT}"
  )
}

main() {
  command -v git >/dev/null 2>&1 || { log "[!] git not found in PATH"; exit 1; }

  ensure_dir
  clone_or_update
  run_10min
}

main "$@"
