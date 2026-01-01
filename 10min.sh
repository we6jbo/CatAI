#!/usr/bin/env bash
set -euo pipefail

SRC_URL="https://raw.githubusercontent.com/we6jbo/CatAI/refs/heads/main/hwbchat.c"

TMP_DIR="/tmp/a"
SRC_PATH="${TMP_DIR}/hwbchat.c"
BIN_PATH="${TMP_DIR}/hwbchat"

INSTALL_DIR="/opt/cataised/hbwchat"
INSTALL_BIN="${INSTALL_DIR}/hwbchat"

echo "[*] Checking for existing install..."

if [[ -x "${INSTALL_BIN}" ]]; then
  echo "[*] Existing hwbchat found:"
  echo "    ${INSTALL_BIN}"
  echo "[*] Running existing program..."
  cd "${INSTALL_DIR}"
  exec "${INSTALL_BIN}"
fi

echo "[*] No existing binary found. Proceeding with install."

echo "[*] Creating temp dir: ${TMP_DIR}"
mkdir -p "${TMP_DIR}"

echo "[*] Downloading source:"
echo "    ${SRC_URL}"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${SRC_URL}" -o "${SRC_PATH}"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "${SRC_PATH}" "${SRC_URL}"
else
  echo "[!] ERROR: Neither curl nor wget found."
  exit 1
fi

echo "[*] Verifying download..."
if [[ ! -s "${SRC_PATH}" ]]; then
  echo "[!] ERROR: Download failed or file is empty."
  exit 1
fi

echo "[*] Checking for gcc..."
if ! command -v gcc >/dev/null 2>&1; then
  echo "[!] ERROR: gcc not found."
  echo "    Install with: sudo apt-get install -y gcc"
  exit 1
fi

echo "[*] Compiling hwbchat..."
gcc -O2 -Wall -Wextra -o "${BIN_PATH}" "${SRC_PATH}"

echo "[*] Creating install directory: ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

echo "[*] Installing binary to ${INSTALL_BIN}"
install -m 0755 "${BIN_PATH}" "${INSTALL_BIN}"

echo "[*] Installation complete."
echo "[*] Running newly installed program..."

cd "${INSTALL_DIR}"
exec "${INSTALL_BIN}"
