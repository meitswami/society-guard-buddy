# Kutumbika — Society Management System

*Parivaar Jaisi Society* · repo: **society-guard-buddy**

Mobile-first multi-society app for **guards**, **residents**, **admins**, and **super admins**: visitors, vehicles, finance, meetings, polls & elections, notifications, and reporting. Society is chosen before login so data stays scoped.

**Clients:** React web app (repo root) + **Flutter** native Android/iOS (`mobile/`). Both share the same Supabase backend. Legacy Capacitor WebView builds are still supported from the web tree.

**Version 2:** shipped features, migration index → **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)**

---

## What it does

| Goal | Modules |
|------|---------|
| Security & gate ops | Visitors, vehicles, blacklist, geofence, guard KYC, emergency alerts |
| Finance & audit | Ledger, period & flat reports, opening balances, head/reserve funds, self-audit, manual tracer |
| Community | Meetings, polls/elections, events & food, donations, parking, committee |
| Ops | Notifications (FCM + OneSignal), REPORTS, society documents, platform branding |

Architecture, data flows, and role matrix → **[docs/architecture/](./docs/architecture/)**

---

## Tech stack

**Web:** React 18 · TypeScript · Vite · Tailwind · shadcn/ui · React Router · TanStack Query · Zustand · Capacitor (optional WebView)

**Mobile:** Flutter 3.5+ (`mobile/`) · Riverpod · go_router · `supabase_flutter` · Firebase Auth/FCM · `local_auth`

**Backend:** **Supabase** (Postgres, Storage, Realtime, Edge Functions) · FCM / OneSignal · WebAuthn

---

## Repo layout

| Path | Purpose |
|------|---------|
| `src/` | React web app (pages, components, hooks, lib) |
| `mobile/` | Flutter Android & iOS app |
| `supabase/migrations/` | Postgres schema (apply in timestamp order) |
| `supabase/functions/` | Edge Functions (OTP, push, PhonePe, emergency, backup) |
| `docs/` | Release notes, architecture, mobile guides |
| `android/`, `ios/` | Capacitor native shells (web-in-WebView) |

---

## Prerequisites

- **Node.js** 18+ and npm (web)
- **Flutter** 3.5+ (native mobile; optional)
- A **Supabase** project (remote) or local stack via [Supabase CLI](https://supabase.com/docs/guides/cli)
- **Firebase** project for phone OTP and push (optional but recommended)

---

## Getting started

```bash
npm install
cp .env.example .env   # Windows: copy .env.example .env
npm run dev
npm run test           # vitest (npm run test:watch for watch mode)
npm run lint
npm run build
```

Copy [`.env.example`](.env.example) to `.env`. Key areas: `VITE_SUPABASE_*`, optional `VITE_FIREBASE_*` (OTP + FCM), reCAPTCHA, and Edge Function secrets (FCM, OneSignal, PhonePe, WhatsApp, Resend). Details in `.env.example`.

**Database:** apply all SQL under `supabase/migrations/` through **`20260707150000`** (full index in **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)**). With Supabase CLI linked to your project: `supabase db push`. Ensure Storage buckets **`notification-media`**, **`guard-documents`**, and **`society-documents`** exist.

**Deploy:** Vite build → static host; push migrations + Edge secrets to Supabase.

**Flutter (recommended for stores):**

```bash
cd mobile
cp .env.example .env   # SUPABASE_URL, SUPABASE_ANON_KEY, FIREBASE_*
flutter pub get
flutter run
```

Release: `flutter build appbundle` / `flutter build ios`. Push setup → **[docs/mobile/FIREBASE-NATIVE-SETUP.md](./docs/mobile/FIREBASE-NATIVE-SETUP.md)**. Parity → **[docs/mobile/PARITY-ROADMAP.md](./docs/mobile/PARITY-ROADMAP.md)**.

**Capacitor (web in WebView):**

```bash
npm install && npm run build && npx cap sync && npx cap run android
```

Remove dev `server.url` from `capacitor.config.ts` before production builds.

---

## Demo logins (when seed data exists)

| Role | Example |
|------|---------|
| Super admin | `SUPERADMIN` / `Hello#123` |
| Admin | `ADMIN` / `admin123` |
| Guard | `G001` / `guard123` |
| Resident | `9876543210` / `resident123` |

---

## Public routes

| Route | Page |
|-------|------|
| `/about` | Vision, modules, principles |
| `/privacy` | Privacy policy |
| `/terms` | Terms of service |
| `/contact` | Support |
| `/delete-account` | Account deletion |
| `/society-signup` | New society registration (PhonePe) |
| `/society-signup/status` | Signup payment status |

---

## Docs

| Document | Purpose |
|----------|---------|
| **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)** | V2 features & migration index |
| **[CHANGELOG.md](./CHANGELOG.md)** | Release history |
| **[docs/PRODUCT-V2.md](./docs/PRODUCT-V2.md)** | Future roadmap (V2.1–V3) |
| **[docs/architecture/OVERVIEW.md](./docs/architecture/OVERVIEW.md)** | Architecture & diagrams |
| **[docs/architecture/FINANCIAL-DATA-FLOW.md](./docs/architecture/FINANCIAL-DATA-FLOW.md)** | Finance traceability |
| **[docs/architecture/USER-ROLE-MATRIX.md](./docs/architecture/USER-ROLE-MATRIX.md)** | Role × module access |
| **[mobile/README.md](./mobile/README.md)** | Flutter app setup & build |
| **[docs/mobile/PARITY-ROADMAP.md](./docs/mobile/PARITY-ROADMAP.md)** | Web ↔ mobile feature parity |
| **[docs/mobile/FIREBASE-NATIVE-SETUP.md](./docs/mobile/FIREBASE-NATIVE-SETUP.md)** | FCM / Firebase for Flutter |
| **[docs/mobile/API-STRATEGY.md](./docs/mobile/API-STRATEGY.md)** | Shared Supabase API conventions |

---

## License

Copyright © 2026. **MCSPL**.
