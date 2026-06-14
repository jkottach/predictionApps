#!/usr/bin/env bash
# Build and deploy FCC + Mandrake on EC2. Run from repo root after git pull.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$APP_ROOT"

verify_google_client_in_dist() {
  local dist_dir="$1"
  if ! grep -rqE '[0-9]+-[^"[:space:]]+\.apps\.googleusercontent\.com' "$dist_dir/assets" 2>/dev/null; then
    echo "ERROR: No valid VITE_GOOGLE_CLIENT_ID in $dist_dir — check frontend/.env.*.production"
    exit 1
  fi
}

build_frontend_tenant() {
  local tenant="$1"
  local env_file="$APP_ROOT/frontend/.env.${tenant}.production"
  if [[ ! -f "$env_file" ]]; then
    echo "ERROR: Missing $env_file"
    exit 1
  fi
  echo "==> Building ${tenant} frontend (loading $env_file)..."
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
  npm run "build:${tenant}"
  verify_google_client_in_dist "$APP_ROOT/frontend/dist"
}

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
build_frontend_tenant fcc
mkdir -p "$APP_ROOT/fcc/dist"
rm -rf "$APP_ROOT/fcc/dist"/*
cp -r dist/* "$APP_ROOT/fcc/dist/"

build_frontend_tenant mandrake
mkdir -p "$APP_ROOT/mandrake/dist"
rm -rf "$APP_ROOT/mandrake/dist"/*
cp -r dist/* "$APP_ROOT/mandrake/dist/"

# Verify deployed bundles include 24-match dashboard limit
if ! grep -rq 'slice(0,24)' "$APP_ROOT/fcc/dist/assets" 2>/dev/null; then
  echo "ERROR: FCC dist missing slice(0,24) — frontend deploy may be stale"
  exit 1
fi

cd "$APP_ROOT"

if command -v nginx &>/dev/null; then
  echo "==> Reloading nginx..."
  sudo nginx -t
  sudo systemctl reload nginx
fi

pm2 save 2>/dev/null || true

echo "==> Deploy complete."
