# Kutumbika — Society Management System

*Parivaar Jaisi Society*

Mobile-first multi-society app for **guards**, **residents**, **admins**, and **super admins**: visitors, vehicles, finance, meetings, polls & elections, notifications, and reporting. Society is chosen before login so data stays scoped.

**Version 2 details:** expanded release notes and migration table → **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)**.

---

## Version 2 (shipped — at a glance)

| Area | Highlights |
|------|------------|
| **Meetings** | `meeting_kind` (GBM / AGM / EC / other), filters & print, table picker for attendees, bulk attendance, multi-file docs + reorder, auto-save, publish + notify. |
| **Finance** | Period report, PDF, send to members + read receipts; **Transactions** tab (payment/ledger list). |
| **Polls** | Standard polls + **MC elections** (ranked ballots, 2 ballots/fl max, `election_results`, home banners). |
| **Donations** | Preset campaign titles + custom. |
| **Admin Home** | Extra KPIs, usage-sorted quick access, A–Z bottom nav. |
| **Store** | `setSocietyId` skips wiping data when society id unchanged. |

Apply SQL in `supabase/migrations/` (full table: **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)** — includes `20260515120000`, `20260515140000`).

---

## Features (overview)

- **Auth:** Society-first flow; guard / resident / admin / super admin; WebAuthn biometrics; password reset; admin RBAC via `society_roles.permissions`.
- **Gate:** Visitors, approvals, OTP passes, delivery & service, vehicles, blacklist, quick entry, directory.
- **Finance:** Maintenance, ledger, reminders, period report + PDF + targeted notifications, Transactions list.
- **Meetings:** Full module (see readme.md).
- **Community:** Donations (presets), Splitwise, events, polls & elections, parking.
- **Ops:** Notifications (FCM / OneSignal), REPORTS, audit, geofence, settings; **Capacitor** for native builds.

---

## Tech stack

React 18 · TypeScript · Vite · Tailwind · shadcn/ui · Zustand · Supabase (Postgres, RLS, Storage, Edge Functions) · jsPDF · Sonner / SweetAlert2 · Capacitor.

---

## Capacitor (native)

```bash
npm install && npm run build && npx cap sync && npx cap run android
```

Use `npx cap add ios` on macOS. For production builds, remove dev `server.url` from `capacitor.config.ts` before `npm run build && npx cap sync`.

---

## Database (core tables)

`societies`, `super_admins`, `admins`, `society_roles`, `guards`, `guard_shifts`, `visitors`, `resident_vehicles`, `approval_requests`, `visitor_passes`, `flats`, `members`, `resident_users`, `blacklist`, `maintenance_charges`, `maintenance_payments`, `finance_entries` (+ allocations, counterparties), `finance_reminder_settings`, donations & expense split tables, `events` (+ RSVPs, contributions), `polls` / `poll_options` / `poll_votes` / **`poll_election_ballots`**, **`meetings`** (+ attendees, decisions, documents), `notifications` (**`delivery_batch_id`**, **`read_at`**), `fcm_web_tokens`, `parking_spaces`, `geofence_settings`, `biometric_credentials`, `audit_logs`, `password_reset_tokens`.

Bucket **`notification-media`** for uploads (alerts, finance PDFs, meetings, etc.).

---

## Getting started

```bash
npm install
cp .env.example .env
npm run dev
```

Set **`VITE_SUPABASE_URL`** and **`VITE_SUPABASE_PUBLISHABLE_KEY`**. Optional: Firebase / FCM / reCAPTCHA per `.env.example`. Run all Supabase migrations.

**Code map:** `FinanceManager.tsx`, `MeetingManager.tsx`, `PollManager.tsx`, `electionTally.ts`, `ElectionResultsBanner.tsx`, `DonationManager.tsx`, `AdminDashboard.tsx`, `ResidentDashboard.tsx`, `ReportPage.tsx`, `NotificationCenter.tsx`, `useStore.ts`, `supabase/functions/*`.

---

## Demo logins (when seed data exists)

| Role | Example |
|------|---------|
| Super admin | `SUPERADMIN` / `Hello#123` |
| Admin | `ADMIN` / `admin123` |
| Guard | `G001` / `guard123` |
| Resident | `9876543210` / `resident123` |

---

## Docs

- **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)** — **Version 2** shipped features & migration index  
- **[CHANGELOG.md](./CHANGELOG.md)** — Keep a Changelog entries  
- **[docs/PRODUCT-V2.md](./docs/PRODUCT-V2.md)** — Future roadmap (not all shipped)

---

## License

Copyright © 2026. **MCSPL**.
