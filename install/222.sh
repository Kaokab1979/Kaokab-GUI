#!/bin/bash
# ==========================================================
# KAOKAB5GC – CPU AVX Hard Gate (222.sh)
# Author: Forat Selman
# Purpose: Enforce AVX requirement before 5G Core install
# ==========================================================

set -e

# -----------------------------
# Colors & Styles
# -----------------------------
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
ORANGE="\e[38;5;208m"
BOLD="\e[1m"
BLINK="\e[5m"
RESET="\e[0m"

pause() { sleep 2; }

abort() {
  echo
  echo -e "${BOLD}${RED}❌ INSTALLATION ABORTED${RESET}"
  echo -e "${RED}$1${RESET}"
  echo
  exit 1
}

section() {
  echo
  echo -e "${BOLD}${ORANGE}==============================================${RESET}"
  echo -e "${BOLD}${ORANGE} $1 ${RESET}"
  echo -e "${BOLD}${ORANGE}==============================================${RESET}"
  pause
}

# -----------------------------
# Welcome Screen
# -----------------------------
clear
echo -e "${BOLD}${ORANGE}"
figlet -w 120 "KAOKAB5GC"
echo -e "${RESET}"
echo -e "${BOLD}${BLUE}CPU Capability Validation – AVX Requirement${RESET}"
pause

# ==========================================================
# CPU INFORMATION
# ==========================================================

section "CPU INFORMATION"

if command -v lscpu &>/dev/null; then
  lscpu | grep -E "Model name|Architecture|CPU\(s\)|Thread|Core|Socket"
else
  awk -F: '/model name/ {print "Model name:" $2; exit}' /proc/cpuinfo
fi
pause

# ==========================================================
# AVX CHECK
# ==========================================================

section "AVX FEATURE CHECK (MANDATORY)"

has_avx() {
  if command -v lscpu &>/dev/null; then
    if lscpu | awk -F: '/Flags/ {print $2}' | grep -qw avx; then
      return 0
    fi
  fi

  if grep -Eiq 'flags.*\bavx\b' /proc/cpuinfo; then
    return 0
  fi

  return 1
}

echo -e "${BLUE}[+] Checking for AVX support...${RESET}"
pause

if has_avx; then
  echo -e "${GREEN}✔ AVX support detected${RESET}"
else
  echo
  echo -e "${BOLD}${RED}🚫 AVX NOT SUPPORTED 🚫${RESET}"
  echo -e "${RED}"
  echo "KAOKAB5GC requires AVX for:"
  echo "  - Open5GS user plane performance"
  echo "  - Packet processing efficiency"
  echo "  - Production-grade stability"
  echo -e "${RESET}"
  abort "Please deploy KAOKAB5GC on AVX-capable hardware."
fi
pause

# ==========================================================
# FINAL CONFIRMATION
# ==========================================================

section "AVX VALIDATION PASSED"

echo -e "${BOLD}${GREEN}"
echo "✔ CPU meets KAOKAB5GC AVX requirements"
echo -e "${RESET}"
pause

echo -e "${BOLD}${BLINK}${GREEN}"
echo "Press ENTER to continue with KAOKAB5GC installation"
echo -e "${RESET}"
read -r

clear
echo -e "${GREEN}➡ Proceeding to next installation step (666.sh)...${RESET}"
pause

exit 0
