#!/bin/bash
# ============================================================
# GPS51 Fleet Tracker — Full Server Deployment Script
# Run as root or sudo on Ubuntu 20.04 / 22.04
# Usage: bash deploy.sh
# ============================================================

set -e

PROJECT_DIR="/var/www/gps51-fleet"
echo "==> Deploying GPS51 Fleet Tracker to $PROJECT_DIR"

# ── 1. System packages ─────────────────────────────────────
echo "==> Installing system packages..."
apt update -y
apt install -y python3 python3-pip python3-venv nodejs npm nginx git

# ── 2. Copy project files ──────────────────────────────────
echo "==> Copying project files..."
mkdir -p $PROJECT_DIR
cp -r ./backend  $PROJECT_DIR/
cp -r ./frontend $PROJECT_DIR/

# ── 3. Backend setup ───────────────────────────────────────
echo "==> Setting up Python virtualenv..."
cd $PROJECT_DIR/backend
python3 -m venv ../venv
../venv/bin/pip install --upgrade pip
../venv/bin/pip install -r requirements.txt

# ── 4. Configure .env ──────────────────────────────────────
if [ ! -f "$PROJECT_DIR/backend/.env" ]; then
  echo "==> Creating .env from template..."
  cp $PROJECT_DIR/backend/.env.example $PROJECT_DIR/backend/.env
  echo ""
  echo "!! IMPORTANT: Edit $PROJECT_DIR/backend/.env and fill in:"
  echo "   GPS51_USERNAME, GPS51_PASSWORD, SECRET_KEY, GOOGLE_MAPS_API_KEY, ALLOWED_ORIGINS"
  echo ""
fi

# ── 5. Frontend build ──────────────────────────────────────
echo "==> Building React frontend..."
cd $PROJECT_DIR/frontend
npm install
npm run build

# ── 6. Nginx config ────────────────────────────────────────
echo "==> Configuring Nginx..."
cp /var/www/gps51-fleet/../$(dirname "$0")/nginx.conf /etc/nginx/sites-available/gps51-fleet
ln -sf /etc/nginx/sites-available/gps51-fleet /etc/nginx/sites-enabled/gps51-fleet
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# ── 7. Systemd service ─────────────────────────────────────
echo "==> Installing systemd service..."
cp $(dirname "$0")/gps51-fleet.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable gps51-fleet
systemctl restart gps51-fleet

echo ""
echo "============================================"
echo " Deployment complete!"
echo " Backend:  http://127.0.0.1:8000"
echo " Frontend: served via Nginx on port 80"
echo " Status:   systemctl status gps51-fleet"
echo " Logs:     journalctl -u gps51-fleet -f"
echo "============================================"
