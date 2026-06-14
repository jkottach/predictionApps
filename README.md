# World Cup 26 Predictor (FCC + Mandrake)

Match prediction app: submit scores, earn points, view leaderboards. One codebase, two white-label tenants (**FCC** and **Mandrake**).

## Stack

| Layer | Tech |
|-------|------|
| Frontend | React, TypeScript, Vite, Tailwind |
| API | Express, MongoDB |
| Production | EC2 — Nginx + PM2 — see **[EC2_DEPLOYMENT.md](./EC2_DEPLOYMENT.md)** |

## Project layout

```
frontend/     React app (tenant branding via VITE_TENANT)
api/          Express API
deploy/       Nginx + PM2 configs
scripts/      deploy.sh
```

## Local development

```bash
# API
cd api
cp .env.example .env   # set MONGODB_URI, JWT_SECRET, GOOGLE_CLIENT_ID
npm install
npm run dev            # http://localhost:5001

# Frontend — pick a tenant
cd frontend
npm install
npm run dev:fcc        # FCC branding → http://localhost:3000
npm run dev:mandrake   # Mandrake branding
```

### Seed data

```bash
cd api
npm run seed:mongo
```

MongoDB collections: `users`, `teams`, `matches`.

## Tenants

Branding is configured in `frontend/src/config/tenant.ts`. Build per tenant:

```bash
cd frontend
npm run build:fcc
npm run build:mandrake
```

On EC2, `scripts/deploy.sh` builds both and deploys to separate Nginx roots.

## Production

See **[EC2_DEPLOYMENT.md](./EC2_DEPLOYMENT.md)** for EC2 setup, sslip.io hostnames, SSL, MongoDB Atlas, and Google OAuth.

Push to `main` deploys via `.github/workflows/deploy-ec2.yml` (secrets: `EC2_HOST`, `EC2_USER`=`ec2-user`, `EC2_SSH_KEY`).

**Amazon Linux setup scripts:** `scripts/setup-amazon-linux.sh`, `scripts/configure-nginx.sh`, `scripts/deploy.sh`

## Environment

| Where | What |
|-------|------|
| Local API | `api/.env` |
| Local frontend | `frontend/.env` or `npm run dev:fcc` / `dev:mandrake` |
| EC2 API (FCC) | `api/.env.fcc` — templates: `api/.env.fcc.example` |
| EC2 API (Mandrake) | `api/.env.mandrake` — templates: `api/.env.mandrake.example` |
| Production frontend build | `frontend/.env.fcc.production`, `frontend/.env.mandrake.production` |

Missing API env vars cause `/api/leaderboard/top` → **500**.
