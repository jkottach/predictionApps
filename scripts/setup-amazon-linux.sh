#!/usr/bin/env bash
# One-time EC2 bootstrap for Amazon Linux 2023 (or Amazon Linux 2 with dnf).
# Run as ec2-user after SSH: chmod +x scripts/setup-amazon-linux.sh && ./scripts/setup-amazon-linux.sh
set -euo pipefail

echo "==> Installing system packages..."
if command -v dnf &>/dev/null; then
  sudo dnf update -y
  sudo dnf install -y git nginx
  # certbot — available on AL2023 via dnf
  sudo dnf install -y certbot python3-certbot-nginx 2>/dev/null || {
    echo "certbot not in dnf repos; install manually if needed"
  }
elif command -v yum &>/dev/null; then
  sudo yum update -y
  sudo yum install -y git nginx
  sudo amazon-linux-extras install -y nginx1 2>/dev/null || true
else
  echo "Unsupported OS — need dnf or yum (Amazon Linux)."
  exit 1
fi

echo "==> Installing Node.js 20..."
if ! command -v node &>/dev/null || [[ "$(node -v | cut -d. -f1 | tr -d v)" -lt 18 ]]; then
  curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
  if command -v dnf &>/dev/null; then
    sudo dnf install -y nodejs
  else
    sudo yum install -y nodejs
  fi
fi
node -v
npm -v

echo "==> Installing PM2..."
sudo npm install -g pm2

echo "==> Enabling nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "==> Creating app directory..."
sudo mkdir -p /var/www
sudo chown "$USER:$USER" /var/www

echo ""
echo "Setup complete. Next steps:"
echo "  1. Clone repo:  git clone <your-repo-url> /var/www/fifa"
echo "  2. Set Elastic IP on this instance (EC2 console)"
echo "  3. Configure API env:  cp api/.env.fcc.example api/.env.fcc  (edit secrets)"
echo "  4. Configure nginx:    ./scripts/configure-nginx.sh YOUR-IP-DASHED"
echo "  5. Deploy:             ./scripts/deploy.sh"
echo "  6. SSL:                sudo certbot --nginx -d fcc.YOUR-IP-DASHED.sslip.io -d mandrake.YOUR-IP-DASHED.sslip.io"
echo "  7. PM2 on boot:        pm2 startup  (run the command it prints), then pm2 save"
