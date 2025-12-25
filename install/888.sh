#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# KAOKAB5GC GUI INSTALLER
# 888.sh
# ============================================================

APP_DIR="/opt/kaokab"
BACKEND_DIR="${APP_DIR}/backend"
FRONTEND_DIR="${APP_DIR}/frontend"
CTL_BIN="/usr/local/sbin/kaokabctl"
SERVICE_NAME="kaokab-web"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
info(){ echo -e "[INFO] $*"; }
ok(){ echo -e "[OK]   $*"; }
fail(){ echo -e "[FAIL] $*" >&2; exit 1; }

# ------------------------------------------------------------
# Safety checks
# ------------------------------------------------------------
[[ $EUID -eq 0 ]] || fail "Run as root"

command -v systemctl >/dev/null || fail "systemctl not found"
command -v node >/dev/null || fail "nodejs not installed"
command -v npm >/dev/null || fail "npm not installed"

info "Installing KAOKAB GUI stack"

# ------------------------------------------------------------
# Create directories
# ------------------------------------------------------------
install -d "${APP_DIR}"
install -d "${BACKEND_DIR}"
install -d "${FRONTEND_DIR}"

# ------------------------------------------------------------
# Install controller
# ------------------------------------------------------------
if [[ ! -f "./kaokabctl/kaokabctl" ]]; then
  fail "kaokabctl not found in repo"
fi

install -m 0755 ./kaokabctl/kaokabctl "${CTL_BIN}"
ok "kaokabctl installed to ${CTL_BIN}"

# ------------------------------------------------------------
# Deploy backend
# ------------------------------------------------------------
rsync -a --delete ./backend/ "${BACKEND_DIR}/"
cd "${BACKEND_DIR}"

if [[ -f package.json ]]; then
  npm install --omit=dev
else
  fail "backend/package.json missing"
fi

ok "Backend deployed"

# ------------------------------------------------------------
# Deploy frontend
# ------------------------------------------------------------
rsync -a --delete ./frontend/ "${FRONTEND_DIR}/"
ok "Frontend deployed"

# ------------------------------------------------------------
# Install systemd service
# ------------------------------------------------------------
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

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

ok "Systemd service ${SERVICE_NAME} enabled and started"

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------
cat <<EOF

==============================================================
 KAOKAB5GC OPS CONSOLE INSTALLED
==============================================================

 Web UI:   http://<server-ip>:3000
 Service: systemctl status ${SERVICE_NAME}

==============================================================

EOF
