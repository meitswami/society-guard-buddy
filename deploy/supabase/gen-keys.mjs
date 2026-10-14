#!/usr/bin/env node
// Generates the secrets a self-hosted Supabase needs (docker/.env).
// Usage: node gen-keys.mjs   → prints lines to paste into /opt/kutumbika-supabase/.env
// No dependencies (Node 18+).
import { createHmac, randomBytes } from 'node:crypto';

const b64url = (buf) => Buffer.from(buf).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
const rand = (n) => randomBytes(n).toString('base64').replace(/[^A-Za-z0-9]/g, '').slice(0, n);

function jwt(secret, role) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({ role, iss: 'supabase', iat: now, exp: now + 10 * 365 * 24 * 3600 }));
  const sig = b64url(createHmac('sha256', secret).update(`${header}.${payload}`).digest());
  return `${header}.${payload}.${sig}`;
}

const JWT_SECRET = rand(48);
const out = {
  POSTGRES_PASSWORD: rand(32),
  JWT_SECRET,
  ANON_KEY: jwt(JWT_SECRET, 'anon'),
  SERVICE_ROLE_KEY: jwt(JWT_SECRET, 'service_role'),
  DASHBOARD_USERNAME: 'kutumbika',
  DASHBOARD_PASSWORD: rand(24),
  SECRET_KEY_BASE: rand(64),
  VAULT_ENC_KEY: rand(32),
  PG_META_CRYPTO_KEY: rand(32),
  LOGFLARE_PUBLIC_ACCESS_TOKEN: rand(32),
  LOGFLARE_PRIVATE_ACCESS_TOKEN: rand(32),
};
for (const [k, v] of Object.entries(out)) console.log(`${k}=${v}`);
console.error('\nKeep these safe. ANON_KEY goes into the web app (VITE_SUPABASE_PUBLISHABLE_KEY) and the mobile app (SUPABASE_ANON_KEY).');
