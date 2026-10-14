#!/usr/bin/env node
// Step 3 — copy every Storage bucket and file from Supabase cloud to the self-hosted stack.
// Run from the repo root on the VPS (uses the web app's @supabase/supabase-js):
//
//   OLD_URL=https://cyydprpucjeiscetrdfa.supabase.co OLD_SERVICE_KEY=<cloud service_role key> \
//   NEW_URL=https://api.kutumbika.meitcybersolutions.com NEW_SERVICE_KEY=<new SERVICE_ROLE_KEY> \
//   node deploy/supabase/migrate-storage.mjs
//
// Safe to re-run: buckets are created if missing and files are uploaded with upsert.
import { createClient } from '@supabase/supabase-js';

const need = (k) => process.env[k] || (console.error(`Missing ${k}`), process.exit(1));
const oldDb = createClient(need('OLD_URL'), need('OLD_SERVICE_KEY'), { auth: { persistSession: false } });
const newDb = createClient(need('NEW_URL'), need('NEW_SERVICE_KEY'), { auth: { persistSession: false } });

async function listAll(bucket, prefix = '') {
  const files = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await oldDb.storage.from(bucket).list(prefix, { limit: 1000, offset });
    if (error) throw new Error(`${bucket}/${prefix}: ${error.message}`);
    for (const item of data) {
      const path = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.id === null) files.push(...(await listAll(bucket, path))); // folder
      else files.push({ path, type: item.metadata?.mimetype });
    }
    if (data.length < 1000) break;
  }
  return files;
}

const { data: buckets, error } = await oldDb.storage.listBuckets();
if (error) throw error;
let copied = 0;
let failed = 0;
for (const b of buckets) {
  const { error: cErr } = await newDb.storage.createBucket(b.id, {
    public: b.public,
    fileSizeLimit: b.file_size_limit ?? undefined,
    allowedMimeTypes: b.allowed_mime_types ?? undefined,
  });
  if (cErr && !/already exists/i.test(cErr.message)) console.warn(`bucket ${b.id}: ${cErr.message}`);
  const files = await listAll(b.id);
  console.log(`${b.id}: ${files.length} files (${b.public ? 'public' : 'private'})`);
  for (const f of files) {
    const { data: blob, error: dErr } = await oldDb.storage.from(b.id).download(f.path);
    if (dErr) { failed++; console.warn(`  download ${f.path}: ${dErr.message}`); continue; }
    const { error: uErr } = await newDb.storage.from(b.id).upload(f.path, blob, { upsert: true, contentType: f.type });
    if (uErr) { failed++; console.warn(`  upload ${f.path}: ${uErr.message}`); continue; }
    copied++;
    if (copied % 50 === 0) console.log(`  … ${copied} copied`);
  }
}
console.log(`Done: ${copied} files copied, ${failed} failed.`);
if (failed) process.exitCode = 1;
