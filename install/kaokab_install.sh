#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# KAOKAB5GC – MASTER INSTALLER
# Clones Kaokab-GUI repo then runs install steps in order
# ============================================================

GREEN="\e[32m"; RED="\e[31m"; YEL="\e[33m"; BLU="\e[34m"; BOLD="\e[1m"; RESET="\e[0m"

REPO_URL="${REPO_URL:-https://github.com/Kaokab1979/Kaokab-GUI.git}"
WORKDIR="${WORKDIR:-/opt}"
REPO_DIR="${REPO_DIR:-${WORKDIR}/Kaokab-GUI}"

step() {
  echo
  echo -e "${BOLD}${BLU}▶ ${*}${RESET}"
  sleep 2
}

need_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo -e "${RED}[FAIL]${RESET} Missing command: ${c}"
    exit 1
  fi
}

pause_enter() {
  echo -e "${BOLD}${GREEN}Press ENTER to continue...${RESET}"
  read -r
  sleep 1
}

# ------------------ banner ------------------
sleep 1
clear
echo -e "${BOLD}${BLU}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                       KAOKAB5GC                              ║"
echo "║            Private 5G Core – Master Installer                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
sleep 2

# Root required
if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}[FAIL]${RESET} Run as root: sudo $0"
  exit 1
fi

# Requirements
step "Checking required tools"
need_cmd git
need_cmd chmod
need_cmd bash
ok_msg() { echo -e "${GREEN}[OK]${RESET} $*"; }
ok_msg "Base tools OK"
sleep 2

# Clone or update repo
step "Cloning repository: ${REPO_URL}"
mkdir -p "${WORKDIR}"
sleep 2

if [[ -d "${REPO_DIR}/.git" ]]; then
  step "Repo already exists → pulling latest"
  (cd "${REPO_DIR}" && git pull --rebase)
else
  git clone "${REPO_URL}" "${REPO_DIR}"
fi
ok_msg "Repository ready at: ${REPO_DIR}"
sleep 2

# Ensure install scripts executable
step "Preparing install scripts"
cd "${REPO_DIR}/install"
chmod +x ./*.sh || true
ok_msg "chmod +x install/*.sh done"
sleep 2

# NOTE: we expect renamed scripts to exist in install/
# 111.sh 222.sh 333.sh 444.sh 555.sh
for f in 111.sh 222.sh 333.sh 444.sh 555.sh; do
  if [[ ! -f "${REPO_DIR}/install/${f}" ]]; then
    echo -e "${RED}[FAIL]${RESET} Missing ${REPO_DIR}/install/${f}"
    echo -e "${YEL}[INFO]${RESET} Fix: ensure the script exists and is committed (or copied) into install/."
    exit 1
  fi
done
ok_msg "All expected install steps found"
sleep 2

# Run steps
step "Step 111: OS/Host preflight"
bash "${REPO_DIR}/install/111.sh"
pause_enter

step "Step 222: AVX hard-gate"
bash "${REPO_DIR}/install/222.sh"
pause_enter

step "Step 333: Base install (was 666.sh)"
bash "${REPO_DIR}/install/333.sh"
pause_enter

step "Step 444: Core configuration (was 777.sh)"
bash "${REPO_DIR}/install/444.sh"
pause_enter

step "Step 555: GUI install (was 888.sh)"
bash "${REPO_DIR}/install/555.sh"

echo
echo -e "${BOLD}${GREEN}✅ KAOKAB5GC installation completed.${RESET}"
echo -e "${YEL}Open GUI: http://<server-ip>:3000${RESET}"
sleep 2
