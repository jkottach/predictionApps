# EC2 Deployment: Amazon Linux + Nginx + PM2 + sslip.io

Single EC2 instance hosts **FCC** and **Mandrake** as separate tenants:

| Layer | Tech |
|--------|------|
| OS | **Amazon Linux 2023** (or Amazon Linux 2) |
| Frontend | React build → Nginx static files |
| API | Express → PM2 (two processes, ports 5001 / 5002) |
| DNS | [sslip.io](https://sslip.io/) — no custom domain required |
| Database | MongoDB Atlas — same cluster, different `MONGODB_DB` per tenant |

Example URLs (replace `203-0-113-10` with your dashed Elastic IP):

- FCC: `https://fcc.203-0-113-10.sslip.io`
- Mandrake: `https://mandrake.203-0-113-10.sslip.io`

---

## 1. Launch EC2 (Amazon Linux)

| Setting | Value |
|---------|--------|
| AMI | **Amazon Linux 2023** |
| Instance type | t3.small or larger |
| Key pair | Create/download `.pem` for SSH |
| Security group | Inbound **22** (SSH), **80** (HTTP), **443** (HTTPS) |
| Storage | 20 GB+ |
| Elastic IP | **Allocate and associate** — required for stable sslip.io URLs |

SSH in (default user is `ec2-user`):

```bash
chmod 400 your-key.pem
ssh -i your-key.pem ec2-user@YOUR_ELASTIC_IP
```

Convert Elastic IP to dashed form for sslip.io: `203.0.113.10` → `203-0-113-10`

---

## 2. One-time server setup

### Option A — automated script

```bash
git clone https://github.com/YOUR_ORG/fifaPrediction.git /var/www/fifa
cd /var/www/fifa
chmod +x scripts/*.sh
./scripts/setup-amazon-linux.sh
```

### Option B — manual install

```bash
sudo dnf update -y
sudo dnf install -y git nginx certbot python3-certbot-nginx

curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

sudo npm install -g pm2
sudo systemctl enable nginx
sudo systemctl start nginx

sudo mkdir -p /var/www
sudo chown ec2-user:ec2-user /var/www
git clone https://github.com/YOUR_ORG/fifaPrediction.git /var/www/fifa
```

---

## 3. API environment (secrets — never commit)

```bash
cd /var/www/fifa/api
cp .env.fcc.example .env.fcc
cp .env.mandrake.example .env.mandrake
nano .env.fcc
nano .env.mandrake
```

| Variable | FCC | Mandrake |
|----------|-----|----------|
| `PORT` | `5001` | `5002` |
| `MONGODB_URI` | same Atlas cluster | same Atlas cluster |
| `MONGODB_DB` | `fifaPredictionFcc` | `fifaPredictionMandrake` |
| `JWT_SECRET` | unique secret | unique secret |
| `GOOGLE_CLIENT_ID` | FCC OAuth client | Mandrake OAuth client |
| `GOOGLE_CLIENT_SECRET` | matching secret | matching secret |
| `FRONTEND_URL` | `https://fcc.203-0-113-10.sslip.io` | `https://mandrake.203-0-113-10.sslip.io` |
| `NODE_ENV` | `production` | `production` |

**MongoDB Atlas:** add the EC2 **Elastic IP** to Network Access (allowlist).

**Seed data (optional):**

```bash
cd /var/www/fifa/api
API_ENV_FILE=.env.fcc npm run seed:mongo
API_ENV_FILE=.env.mandrake npm run seed:mongo
```

---

## 4. Frontend production env

Ensure Google client IDs are set before deploy:

```bash
nano /var/www/fifa/frontend/.env.fcc.production
nano /var/www/fifa/frontend/.env.mandrake.production
```

`VITE_GOOGLE_CLIENT_ID` must match `GOOGLE_CLIENT_ID` in the matching API env file.

---

## 5. Nginx

```bash
cd /var/www/fifa
./scripts/configure-nginx.sh 203-0-113-10
```

This installs `/etc/nginx/conf.d/fifa.conf` on Amazon Linux.

---

## 6. SSL (Let's Encrypt)

Port **80** must be open in the security group:

```bash
sudo certbot --nginx \
  -d fcc.203-0-113-10.sslip.io \
  -d mandrake.203-0-113-10.sslip.io
```

Follow prompts (email, agree to terms). Certbot configures HTTPS and auto-renewal.

Test renewal:

```bash
sudo certbot renew --dry-run
```

---

## 7. Deploy app

```bash
cd /var/www/fifa
./scripts/deploy.sh
```

This builds API + both frontends, starts PM2, reloads nginx.

**PM2 on boot:**

```bash
pm2 startup
# Run the sudo command PM2 prints, then:
pm2 save
```

---

## 8. Verify

```bash
# DNS
dig +short fcc.203-0-113-10.sslip.io

# Health
curl -s https://fcc.203-0-113-10.sslip.io/api/health
curl -s https://mandrake.203-0-113-10.sslip.io/api/health

# Processes
pm2 status
pm2 logs fifa-api-fcc --lines 20
```

Expected: `"status": "ok"`, `"mongo": { "ok": true }`.

Open in browser:
- https://fcc.203-0-113-10.sslip.io
- https://mandrake.203-0-113-10.sslip.io

---

## 9. Google OAuth

For **each** tenant OAuth client, add **Authorized JavaScript origins**:

```
https://fcc.203-0-113-10.sslip.io
https://mandrake.203-0-113-10.sslip.io
http://localhost:3000
```

---

## 10. CI/CD (optional)

Push to `main` triggers [`.github/workflows/deploy-ec2.yml`](.github/workflows/deploy-ec2.yml).

**GitHub repository secrets:**

| Secret | Value |
|--------|-------|
| `EC2_HOST` | Elastic IP |
| `EC2_USER` | `ec2-user` |
| `EC2_SSH_KEY` | Contents of your `.pem` private key |

---

## 11. Redeploy after code changes

```bash
cd /var/www/fifa
git pull
./scripts/deploy.sh
```

---

## Troubleshooting (Amazon Linux)

| Issue | Fix |
|-------|-----|
| `nginx: command not found` | `sudo dnf install -y nginx && sudo systemctl start nginx` |
| Permission denied on `/var/www` | `sudo chown ec2-user:ec2-user /var/www` |
| `/api/health` → 502 | `pm2 logs fifa-api-fcc` — check `.env.fcc`, MongoDB IP allowlist |
| SELinux blocking nginx | `sudo setsebool -P httpd_can_network_connect 1` |
| Google sign-in fails | Match OAuth client IDs; check sslip.io origins in Google Console |
| certbot fails | Security group must allow port 80 from `0.0.0.0/0` |
| Wrong tenant branding | `./scripts/deploy.sh` rebuilds both frontends |

---

## Quick reference (copy-paste checklist)

```bash
# On EC2 as ec2-user — replace YOUR-IP-DASHED and repo URL

git clone <repo-url> /var/www/fifa && cd /var/www/fifa
chmod +x scripts/*.sh
./scripts/setup-amazon-linux.sh

cd api && cp .env.fcc.example .env.fcc && cp .env.mandrake.example .env.mandrake
nano .env.fcc    # fill secrets + sslip.io FRONTEND_URL
nano .env.mandrake

cd /var/www/fifa
./scripts/configure-nginx.sh YOUR-IP-DASHED
./scripts/deploy.sh
sudo certbot --nginx -d fcc.YOUR-IP-DASHED.sslip.io -d mandrake.YOUR-IP-DASHED.sslip.io
pm2 startup && pm2 save
```
