/**
 * PM2 ecosystem — two API processes (FCC + Mandrake) on one EC2 instance.
 *
 * Prerequisites on server:
 *   api/.env.fcc and api/.env.mandrake (copy from .env.*.example)
 *
 * Usage (from repo root):
 *   pm2 start deploy/ecosystem.config.js
 *   pm2 reload deploy/ecosystem.config.js --update-env
 *   pm2 save
 */
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const apiDir = path.join(repoRoot, 'api');

module.exports = {
  apps: [
    {
      name: 'fifa-api-fcc',
      cwd: apiDir,
      script: 'dist/server.js',
      instances: 1,
      autorestart: true,
      env: {
        NODE_ENV: 'production',
        API_ENV_FILE: '.env.fcc',
      },
    },
    {
      name: 'fifa-api-mandrake',
      cwd: apiDir,
      script: 'dist/server.js',
      instances: 1,
      autorestart: true,
      env: {
        NODE_ENV: 'production',
        API_ENV_FILE: '.env.mandrake',
      },
    },
  ],
};
