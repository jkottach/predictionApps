import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

/** `api/` package root (works when running from `src/` or compiled `dist/`). */
export function getApiPackageRoot(): string {
  return path.resolve(__dirname, '../..');
}

/** Load env file(s). Set API_ENV_FILE=.env.fcc (or .env.mandrake) for multi-tenant PM2. */
export function loadApiEnv(): void {
  const root = getApiPackageRoot();

  const files = process.env.API_ENV_FILE
    ? [process.env.API_ENV_FILE]
    : ['.env', '.env.local'];

  for (let i = 0; i < files.length; i++) {
    const file = files[i]!;
    const envPath = path.join(root, file);
    if (fs.existsSync(envPath)) {
      dotenv.config({
        path: envPath,
        override: i > 0,
      });
    }
  }
}

loadApiEnv();
