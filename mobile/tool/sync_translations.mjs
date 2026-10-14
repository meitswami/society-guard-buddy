// Copies the web app's UI strings (src/i18n/translations.ts) into the Flutter app
// so both clients show identical Hindi / English copy.
// Usage (repo root): node mobile/tool/sync_translations.mjs
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..');
const mod = await import(path.join(repoRoot, 'src/i18n/translations.ts'));
const translations = mod.default;
const out = {};
for (const key of Object.keys(translations).sort()) {
  const row = translations[key];
  out[key] = { en: row.en ?? '', hi: row.hi ?? '' };
}
const target = path.join(repoRoot, 'mobile/assets/i18n/translations.json');
writeFileSync(target, JSON.stringify(out, null, 0) + '\n');
console.log(`Wrote ${Object.keys(out).length} keys → ${path.relative(repoRoot, target)}`);
