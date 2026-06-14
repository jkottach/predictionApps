#!/usr/bin/env bash
# Build and deploy FCC + Mandrake on EC2. Run from repo root after git pull.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$APP_ROOT"

echo "==> Building API..."
cd api
npm ci
npm run build
cd "$APP_ROOT"

echo "==> Reloading PM2 API processes..."
if pm2 describe fifa-api-fcc &>/dev/null; then
  pm2 reload deploy/ecosystem.config.js --update-env
else
  pm2 start deploy/ecosystem.config.js
fi

echo "==> Building FCC frontend..."
cd frontend
npm ci
npm run build:fcc
mkdir -p "$APP_ROOT/fcc/dist"
rm -rf "$APP_ROOT/fcc/dist"/*
cp -r dist/* "$APP_ROOT/fcc/dist/"

echo "==> Building Mandrake frontend..."
npm run build:mandrake
mkdir -p "$APP_ROOT/mandrake/dist"
rm -rf "$APP_ROOT/mandrake/dist"/*
cp -r dist/* "$APP_ROOT/mandrake/dist/"

cd "$APP_ROOT"

if command -v nginx &>/dev/null; then
  echo "==> Reloading nginx..."
  sudo nginx -t
  sudo systemctl reload nginx
fi

pm2 save 2>/dev/null || true

echo "==> Deploy complete."
