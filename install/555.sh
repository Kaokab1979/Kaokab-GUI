#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# KAOKAB5GC GUI INSTALLER
# Step 555.sh
# ============================================================

APP_DIR="/opt/kaokab"
BACKEND_DIR="${APP_DIR}/backend"
FRONTEND_DIR="${APP_DIR}/frontend"
SERVICE_NAME="kaokab-web"

# Resolve repo root (…/Kaokab-GUI)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info(){ echo -e "[INFO] $*"; }
ok(){ echo -e "[OK]   $*"; }
fail(){ echo -e "[FAIL] $*" >&2; exit 1; }

sleep_step(){ sleep 2; }

# ------------------------------------------------------------
# Safety checks
# ------------------------------------------------------------
[[ $EUID -eq 0 ]] || fail "Run as root"

command -v systemctl >/dev/null || fail "systemctl not found"
command -v node >/dev/null || fail "nodejs not installed"
command -v npm >/dev/null || fail "npm not installed"

info "Installing KAOKAB5GC GUI stack"
sleep_step

# ------------------------------------------------------------
# Verify kaokabctl (installed by 333.sh)
# ------------------------------------------------------------
if ! command -v kaokabctl >/dev/null 2>&1; then
  fail "kaokabctl not found in PATH (expected /usr/local/sbin/kaokabctl)"
fi

ok "kaokabctl detected at $(command -v kaokabctl)"
sleep_step

# ------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------
info "Preparing application directories"
install -d "${APP_DIR}" "${BACKEND_DIR}" "${FRONTEND_DIR}"
ok "Directories ready"
sleep_step

# ------------------------------------------------------------
# Deploy backend
# ------------------------------------------------------------
info "Deploying backend"
[[ -f "${REPO_ROOT}/backend/server.js" ]] || fail "backend/server.js missing in repo"
rsync -a --delete "${REPO_ROOT}/backend/" "${BACKEND_DIR}/"

cd "${BACKEND_DIR}"
if [[ -f package.json ]]; then
  npm install --omit=dev
else
  fail "backend/package.json missing"
fi

ok "Backend deployed"
sleep_step

# ------------------------------------------------------------
# Deploy frontend
# ------------------------------------------------------------
info "Deploying frontend"
[[ -f "${REPO_ROOT}/frontend/index.html" ]] || fail "frontend/index.html missing in repo"
rsync -a --delete "${REPO_ROOT}/frontend/" "${FRONTEND_DIR}/"
ok "Frontend deployed"
sleep_step

# ------------------------------------------------------------
# Install systemd service
# ------------------------------------------------------------
info "Installing systemd service"

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
sleep_step

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------
cat <<EOF

==============================================================
 ✅ KAOKAB5GC OPS CONSOLE INSTALLED
==============================================================

 Web UI:   http://<server-ip>:3000
 Service:  systemctl status ${SERVICE_NAME}
 Logs:     journalctl -u ${SERVICE_NAME} -f

==============================================================

EOF
