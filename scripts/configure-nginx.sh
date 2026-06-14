#!/usr/bin/env bash
# Install nginx site config for FCC + Mandrake (Amazon Linux conf.d layout).
# Usage: ./scripts/configure-nginx.sh 203-0-113-10
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <EC2_IP_DASHED>"
  echo "Example: $0 203-0-113-10   (Elastic IP 203.0.113.10)"
  exit 1
fi

IP_DASHED="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONF_SRC="$APP_ROOT/deploy/nginx/fifa-tenant.conf"
CONF_OUT="/tmp/fifa-nginx.conf"

sed "s/EC2_IP_DASHED/${IP_DASHED}/g" "$CONF_SRC" > "$CONF_OUT"

# Amazon Linux: /etc/nginx/conf.d/
# Ubuntu: /etc/nginx/sites-available + sites-enabled
if [[ -d /etc/nginx/conf.d ]]; then
  sudo cp "$CONF_OUT" /etc/nginx/conf.d/fifa.conf
  echo "Installed /etc/nginx/conf.d/fifa.conf"
elif [[ -d /etc/nginx/sites-available ]]; then
  sudo cp "$CONF_OUT" /etc/nginx/sites-available/fifa
  sudo ln -sf /etc/nginx/sites-available/fifa /etc/nginx/sites-enabled/fifa
  sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
  echo "Installed /etc/nginx/sites-available/fifa"
else
  echo "Could not find nginx config directory."
  exit 1
fi

sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "Nginx configured for:"
echo "  http://fcc.${IP_DASHED}.sslip.io"
echo "  http://mandrake.${IP_DASHED}.sslip.io"
echo ""
echo "Next: sudo certbot --nginx -d fcc.${IP_DASHED}.sslip.io -d mandrake.${IP_DASHED}.sslip.io"
