#!/bin/bash
# ==========================================================
# KAOKAB5GC – System Sanity Check (111.sh)
# Author: Forat Selman
# Purpose: Pre-flight validation before Private 5G install
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

# -----------------------------
# Helpers
# -----------------------------
pause() { sleep 2; }
section() {
  echo
  echo -e "${BOLD}${ORANGE}==============================================${RESET}"
  echo -e "${BOLD}${ORANGE} $1 ${RESET}"
  echo -e "${BOLD}${ORANGE}==============================================${RESET}"
  pause
}

abort() {
  echo
  echo -e "${BOLD}${RED}❌ INSTALLATION ABORTED${RESET}"
  echo -e "${RED}$1${RESET}"
  echo
  exit 1
}

# -----------------------------
# Install dependencies
# -----------------------------
if ! command -v figlet &>/dev/null || ! command -v toilet &>/dev/null; then
  echo -e "${BOLD}${BLUE}Installing required packages (figlet, toilet)...${RESET}"
  apt-get update -qq
  apt-get install -y figlet toilet
fi

# -----------------------------
# Welcome Screen
# -----------------------------
clear
echo -e "${BOLD}${ORANGE}"
figlet -w 120 "KAOKAB5GC"
echo -e "${RESET}"
echo -e "${BOLD}${BLUE}Shaping the Future of Private 5G Networks${RESET}"
pause

# ==========================================================
# SYSTEM INFORMATION
# ==========================================================

section "SYSTEM INFORMATION CHECK"

# OS Check (Ubuntu ANY)
echo -e "${BLUE}[+] Operating System:${RESET}"
if grep -qi ubuntu /etc/os-release; then
  . /etc/os-release
  echo -e "${GREEN}✔ Ubuntu detected: ${PRETTY_NAME}${RESET}"
else
  abort "This installer supports Ubuntu only."
fi
pause

# Kernel
echo -e "${BLUE}[+] Kernel Version:${RESET}"
echo -e "${GREEN}$(uname -r)${RESET}"
pause

# RAM
echo -e "${BLUE}[+] Total RAM:${RESET}"
RAM_MB=$(awk '/MemTotal/ {printf "%.0f MB", $2/1024}' /proc/meminfo)
echo -e "${GREEN}${RAM_MB}${RESET}"
pause

# CPU Cores
echo -e "${BLUE}[+] CPU Cores:${RESET}"
echo -e "${GREEN}$(nproc)${RESET}"
pause

# Disk Space
echo -e "${BLUE}[+] Disk Space Available (/):${RESET}"
echo -e "${GREEN}$(df -h / | awk 'NR==2 {print $4}')${RESET}"
pause

# ==========================================================
# NETWORK CHECKS
# ==========================================================

section "NETWORK CONNECTIVITY CHECK"

echo -e "${BLUE}[+] Internet Connectivity:${RESET}"
if ping -c 2 -W 2 8.8.8.8 &>/dev/null || ping -c 2 -W 2 google.com &>/dev/null; then
  echo -e "${GREEN}✔ Internet reachable${RESET}"
else
  abort "No internet connectivity detected."
fi
pause

echo -e "${BLUE}[+] Network Interfaces:${RESET}"
ip -br addr show | awk '{print "  - " $1 ": " $3}'
pause

echo -e "${BLUE}[+] Default Gateway:${RESET}"
GW=$(ip route show default | awk '{print $3}')
if [[ -z "$GW" ]]; then
  abort "No default gateway found."
else
  echo -e "${GREEN}${GW}${RESET}"
fi
pause

# ==========================================================
# FINAL CONFIRMATION
# ==========================================================

section "FINAL CONFIRMATION"

echo -e "${BOLD}${GREEN}"
echo "✔ All system checks passed successfully."
echo -e "${RESET}"
pause

echo -e "${BOLD}${BLINK}${GREEN}"
echo "Press ENTER to continue with KAOKAB5GC installation"
echo -e "${RESET}"
read -r

clear
echo -e "${GREEN}➡ Proceeding to next installation step (222.sh)...${RESET}"
pause

exit 0
