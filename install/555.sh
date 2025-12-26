#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# KAOKAB5GC GUI INSTALLER (Step 555)
# - Deploys backend + frontend into /opt/kaokab
# - Installs kaokabctl to /usr/local/sbin
# - Installs/updates systemd service kaokab-web
# - Verifies API comes up on 0.0.0.0:3000
# ============================================================

GREEN="\e[32m"; RED="\e[31m"; YEL="\e[33m"; BLU="\e[34m"; BOLD="\e[1m"; RESET="\e[0m"

APP_DIR="/opt/kaokab"
BACKEND_DIR="${APP_DIR}/backend"
FRONTEND_DIR="${APP_DIR}/frontend"
ASSETS_DIR="${FRONTEND_DIR}/assets"
CTL_BIN="/usr/local/sbin/kaokabctl"
SERVICE_NAME="kaokab-web"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Resolve repo root no matter where script is called from
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info(){ echo -e "${BLU}[INFO]${RESET} $*"; }
ok(){ echo -e "${GREEN}[OK]${RESET}   $*"; }
warn(){ echo -e "${YEL}[WARN]${RESET} $*"; }
fail(){ echo -e "${RED}[FAIL]${RESET} $*" >&2; exit 1; }

step(){
  echo
  echo -e "${BOLD}${BLU}▶ $*${RESET}"
  sleep 2
}

need_cmd(){
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

# ------------------------------------------------------------
# Safety
# ------------------------------------------------------------
[[ $EUID -eq 0 ]] || fail "Run as root (sudo -i or sudo ./555.sh)"
need_cmd systemctl
need_cmd node
need_cmd npm

# rsync is optional but recommended
if ! command -v rsync >/dev/null 2>&1; then
  step "Installing rsync (recommended)"
  apt-get update -y
  apt-get install -y rsync
fi

# ------------------------------------------------------------
# Validate repo structure
# ------------------------------------------------------------
step "Validating repository structure"

[[ -d "${REPO_ROOT}/backend"  ]] || fail "Missing: ${REPO_ROOT}/backend"
[[ -d "${REPO_ROOT}/frontend" ]] || fail "Missing: ${REPO_ROOT}/frontend"
[[ -f "${REPO_ROOT}/backend/server.js" ]] || fail "Missing: backend/server.js"
[[ -f "${REPO_ROOT}/backend/package.json" ]] || fail "Missing: backend/package.json"

# kaokabctl may be either in repo or already installed
if [[ -f "${REPO_ROOT}/kaokabctl/kaokabctl" ]]; then
  ok "kaokabctl found in repo"
else
  warn "kaokabctl not found in repo at ${REPO_ROOT}/kaokabctl/kaokabctl"
fi

# ------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------
step "Preparing application directories"
install -d "${APP_DIR}" "${BACKEND_DIR}" "${FRONTEND_DIR}" "${ASSETS_DIR}"
ok "Directories ready: ${APP_DIR}"

# ------------------------------------------------------------
# Install/Update kaokabctl
# ------------------------------------------------------------
step "Installing kaokabctl"

if [[ -f "${REPO_ROOT}/kaokabctl/kaokabctl" ]]; then
  install -m 0755 "${REPO_ROOT}/kaokabctl/kaokabctl" "${CTL_BIN}"
  ok "kaokabctl installed to ${CTL_BIN}"
else
  if [[ -x "${CTL_BIN}" ]]; then
    ok "kaokabctl already present at ${CTL_BIN}"
  else
    warn "kaokabctl missing (GUI may work, but status will fail)."
  fi
fi

# ------------------------------------------------------------
# Deploy backend
# ------------------------------------------------------------
step "Deploying backend to ${BACKEND_DIR}"
rsync -a --delete "${REPO_ROOT}/backend/" "${BACKEND_DIR}/"
ok "Backend files deployed"

step "Installing backend dependencies (npm install --omit=dev)"
cd "${BACKEND_DIR}"
npm install --omit=dev
ok "Backend dependencies installed"

# Quick syntax check before systemd restart
step "Validating backend entrypoint (node -c equivalent)"
node -e "require('./server.js'); console.log('server.js loads OK');" >/dev/null 2>&1 || {
  echo
  warn "server.js failed to load. Showing error:"
  node -e "require('./server.js')" || true
  fail "Backend validation failed. Fix server.js or dependencies first."
}
ok "Backend loads successfully"

# ------------------------------------------------------------
# Deploy frontend
# ------------------------------------------------------------
step "Deploying frontend to ${FRONTEND_DIR}"
rsync -a --delete "${REPO_ROOT}/frontend/" "${FRONTEND_DIR}/"
ok "Frontend deployed"

# ------------------------------------------------------------
# Install systemd service
# ------------------------------------------------------------
step "Installing systemd unit: ${SERVICE_NAME}"

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=KAOKAB5GC Ops Console (API + Web)
After=network.target

[Service]
Type=simple
WorkingDirectory=${BACKEND_DIR}
Environment=PORT=3000
ExecStart=/usr/bin/node ${BACKEND_DIR}/server.js
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.service"
sleep 2

# ------------------------------------------------------------
# Verify it is actually listening
# ------------------------------------------------------------
step "Verifying service is running and port 3000 is listening"

systemctl is-active --quiet "${SERVICE_NAME}" || {
  warn "Service not active. Recent logs:"
  journalctl -u "${SERVICE_NAME}" -n 80 --no-pager || true
  fail "Service failed to start."
}

# Try loopback health check
if curl -fsS "http://127.0.0.1:3000/api/health" >/dev/null 2>&1; then
  ok "Health OK on 127.0.0.1:3000"
else
  warn "Health check failed on 127.0.0.1. Showing listeners + logs:"
  ss -ltnp | grep -E ':3000' || true
  journalctl -u "${SERVICE_NAME}" -n 80 --no-pager || true
  fail "API not reachable locally. Fix before continuing."
fi

# Confirm bind (ideally 0.0.0.0:3000)
if ss -ltnp | grep -qE 'LISTEN.*:3000'; then
  ok "Port 3000 is listening:"
  ss -ltnp | grep -E ':3000' || true
else
  warn "No listener on :3000 detected"
fi

# ------------------------------------------------------------
# Final message
# ------------------------------------------------------------
cat <<EOF

==============================================================
 ✅ KAOKAB5GC OPS CONSOLE INSTALLED
==============================================================

 Web UI:   http://<server-ip>:3000
 Service:  systemctl status ${SERVICE_NAME}
 Logs:     journalctl -u ${SERVICE_NAME} -f

 Quick checks:
   curl -s http://127.0.0.1:3000/api/health

==============================================================

EOF
