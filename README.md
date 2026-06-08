# Kutumbika — Society Management System

*Parivaar Jaisi Society*

Mobile-first multi-society app for **guards**, **residents**, **admins**, and **super admins**: visitors, vehicles, finance, meetings, polls & elections, notifications, and reporting. Society is chosen before login so data stays scoped.

**Version 2 details:** expanded release notes and migration table → **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)**.

---

## System objectives

Kutumbika is built to deliver:

1. **Security surveillance** — gate operations, visitor tracking, guard accountability, geofence
2. **Monitoring & alerts** — notifications, emergency broadcast, KPI dashboards, KYC alerts
3. **Fair & transparent accounting** — verified ledger, reconciliation, self-audit, head & reserve funds
4. **Understandable reporting** — period reports, monthly REPORTS tab, flat statements
5. **Operational flexibility** — multi-society, RBAC, events & food vs society payments, society pool
6. **Auditability & compliance** — audit logs, governance framework, meeting & election records
7. **Future scalability** — Supabase backend, Capacitor native, extensible edge functions

---

## Version 2 (shipped — at a glance)

| Area | Highlights |
|------|------------|
| **Meetings** | `meeting_kind` (GBM / AGM / EC / other), filters & print, table picker for attendees, bulk attendance, multi-file docs + reorder, auto-save, publish + notify. |
| **Finance** | Period report, PDF, send to members + read receipts; **Transactions** tab; society pool; head fund reconciliation; reserve/operating fund; flat report. |
| **Audit & Governance** | Duplicate maintenance alarms; **Self-Audit** engine (10 checks); **Manual Audit Tracer**; **Society Governance Framework**; public **About** page. |
| **Events & food** | Event-linked expense groups; food vs payment split; flat/outsider contribution receipts (flat-wise or without flat); edit/delete; cash/bank breakdown; shortfall/surplus pool adjustments; **EventFoodReconciliation**. |
| **Committee** | MC roster with flat, tenure, elected/nominated; election results apply to committee. |
| **Emergency alerts** | Guard/resident broadcast with photos; FCM push + WhatsApp (`emergency_alerts`). |
| **Polls** | Standard polls + **MC elections** (ranked ballots, phases, 2 ballots/fl max, `election_results`, home banners). |
| **Donations** | Preset campaign titles + custom. |
| **Admin Home** | Extra KPIs (incl. event food total), usage-sorted quick access, A–Z bottom nav, KYC guard alerts. |
| **Guards (admin)** | Worker **profile photo** (camera + gallery); double-tap enlarge; **multiple documents** per guard (images + PDF). |
| **Store** | `setSocietyId` skips wiping data when society id unchanged. |

Apply SQL in `supabase/migrations/` (full table through **`20260608140000`**: **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)**).

---

## Architecture (V2)

| Layer | Implementation |
|-------|----------------|
| **Frontend** | React 18, TypeScript, Vite, Tailwind, shadcn/ui — `src/pages/*`, `src/components/*` |
| **Routing & data** | React Router, TanStack Query, Zustand (`useStore.ts`) |
| **Backend** | Supabase — Postgres, Storage, Realtime, Edge Functions (`supabase/functions/*`) |
| **Authentication** | Society-scoped table credentials; optional Firebase Auth for resident SMS OTP; WebAuthn biometrics; superadmin TOTP MFA |
| **Authorization** | Admin RBAC via `society_roles.permissions` (`src/lib/adminPermissions.ts`); UI tab gates |
| **Notification services** | FCM web tokens + `send-push-notification` edge function; OneSignal SDK + REST fallback |
| **Reporting engine** | `ReportPage.tsx`, `financePeriodReportPdf.ts`, meeting print helpers |
| **Finance module** | `FinanceManager.tsx`, `HeadFundReconciliation.tsx`, `MonthlyOperatingFundPanel.tsx`, audit libs |
| **Meeting module** | `MeetingManager.tsx` |
| **Security layer** | `auditLogger.ts`, geofence hooks, `SensitiveAdminVerifyModal.tsx`, reCAPTCHA edge functions |

See **[docs/architecture/OVERVIEW.md](./docs/architecture/OVERVIEW.md)** for diagrams and data flows.

---

## Features (overview)

### Authentication & session
- Society-first flow (`SocietyLoginGate`); guard / resident / admin / super admin roles
- Session restore via `src/lib/appSession.ts`; admin permissions re-fetched on load (not stale `localStorage` only)
- WebAuthn biometrics; password reset; superadmin TOTP MFA + email recovery
- Optional Firebase phone OTP for residents (`send-otp` / `verify-otp` edge functions)

### Guards (admin)
- CRUD, password/OTP login, KYC status; **worker photo** on list (thumbnail + guard ID, double-tap enlarge)
- Capture via **camera** or **gallery**; **Photo ID** (front/back); **unlimited attachments** (images/PDF)

### Gate & security
- Visitors, approvals, OTP passes, delivery & service, vehicles, blacklist, quick entry, directory
- Geofence: login boundary for guards + runtime shift monitor → `geofence_violation` in `audit_logs`

### Finance
- Maintenance charges & resident payment verification; ledger (`finance_entries` + allocations)
- **Sub-tabs:** Create Receipts · Record receipt · Record payment · **Transactions** · Period report · Totals · Flat Report · Reminders
- Society pool (record to pool, distribute to flats later); head fund reconciliation; reserve/operating fund transfers
- Period report + PDF + targeted send with **read receipts** (`delivery_batch_id`, `read_at`)

### Audit & governance
- **Security audit logs** — login, password, biometric, geofence events (`AuditLogViewer.tsx`)
- **Duplicate maintenance alarms** — inline edit/delete (`FinanceAuditAlarms.tsx`)
- **Self-Audit engine** — 10 automated checks (`FinanceIntegrityAudit.tsx`) — see [Audit section](#audit-section-detailed)
- **Manual Audit Tracer** — month-level cross-check of period report vs payments vs Transactions tab
- **Society Governance Framework** — in-app reference (`SocietyGovernanceGuide.tsx`)
- **About page** (`/about`) — public vision, purpose, module map (`AboutPage.tsx`)

### Meetings
Full module — see **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)** (schedule, attendance, decisions, documents, signatures, publish + notify).

### Community
- Donations (preset campaign titles), **Events & food expenses** (replaces legacy Splitwise tab), polls & elections, parking, committee roster

### Reporting (`ReportPage.tsx`)
- **Financial** — month finance summaries, gross ledger, verified net, maintenance from ledger, event food from groups, donations
- **Visitor** / **Vehicle** — day/month statistics
- **All Modules** — cross-module monthly overview
- CSV export and print-ready HTML where supported

### Ops & integrations
- Notifications (FCM + OneSignal fallback), emergency alerts (push + WhatsApp), REPORTS, geofence, settings
- Society signup + PhonePe provisioning (`/society-signup`)
- Superadmin backup export (`backup-export` edge function)
- Resident support tickets; **Capacitor** for native Android/iOS builds

---

## Audit Section (detailed)

The Audit tab in the Admin Dashboard is a governance and integrity hub:

### 1. Security Audit Logs
Login success/failure, password changes, biometric registrations, geofence violations. Searchable and filterable (`audit_logs`).

### 2. Duplicate Maintenance Alarms
Auto-detects when the same flat is credited twice in the same month via the same channel. Inline **Edit** and **Delete**; includes ledger overcount panel.

### 3. Internal Self-Audit Engine
**"Run Self-Audit"** performs **10 automated checks**:

| Check | Severity | What it detects |
|-------|----------|-----------------|
| Negative Cash Balance | Critical | Cash outflow > cash inflow (with channel trace) |
| Negative Bank Balance | Critical | Bank outflow > bank inflow |
| Duplicate Payments | Critical | Same flat + charge + month + channel > 1 row |
| Recording vs Reporting | Warning | `maintenance_payments` total ≠ `finance_entries` total |
| Ledger Double-Count | Warning | Period report inflation from overlapping ledger rows |
| Orphaned Payments | Warning | Verified payments with no `finance_entry_id` link |
| Flat Count Mismatch | Warning | Ledger entry flat count ≠ linked payments |
| Non-Standard Amounts | Info | Payment amount differs from charge definition |
| Stuck Pending (>7 days) | Warning | Unverified payments older than a week |
| Unpaid Flats This Month | Info | Occupied flats with no current-month payment |

Each finding shows root cause, rectification steps, and raw figures.

### 4. Manual Audit Tracer
Month-level reconciliation across period report totals, verified payments, and Transactions tab figures.

### 5. Society Governance Framework
Expandable reference: Principal, Purpose, Vision, Planning & Structure, Policy & Compliance (Co-op Societies Act, IT, GST).

---

## Security model

| Control | Implementation |
|---------|----------------|
| **Authentication** | Society-scoped credentials; WebAuthn; superadmin TOTP MFA |
| **Authorization** | `society_roles.permissions` JSON — 22 module flags; legacy admins without `role_id` get full access |
| **Session handling** | `appSession.ts` persistence; admin role re-fetch on app load |
| **Audit logging** | Security events in `audit_logs` (IP, device, severity) — finance CRUD not fully logged |
| **Activity tracking** | Geofence violations, login events, backup exports |
| **Data integrity** | Self-audit engine, duplicate alarms, manual tracer |
| **Database RLS** | Many tables use permissive policies (`USING (true)`); **society isolation is enforced in application queries**. Harden RLS before high-assurance multi-tenant deployment. |

---

## About Page (`/about`)

Public page from login footer: Vision, Purpose, 10-module map, collaboration roles, guiding principles.

Route: `/about` · Component: `src/pages/AboutPage.tsx` · Linked from: `LoginFooter.tsx`

---

## Tech stack

| Layer | Technology |
|-------|------------|
| Frontend | React 18, TypeScript, Vite |
| Routing | React Router |
| Data fetching | TanStack Query |
| Styling | Tailwind CSS, shadcn/ui (Radix), Lucide |
| State | Zustand |
| Backend | **Supabase** — Postgres, RLS, Realtime, Storage, Edge Functions |
| Auth (app) | Society-scoped table credentials; **Firebase Auth** optional for SMS OTP |
| Push | **FCM** (web tokens + HTTP v1 from Edge Functions) with **OneSignal** alternate/fallback |
| PDF | jsPDF (finance period report) |
| Alerts | SweetAlert2, Sonner |
| i18n | English / Hindi context |
| Native | Capacitor (Android / iOS) |
| Biometric | WebAuthn / FIDO2 |
| Scheduling | pg_cron + pg_net (maintenance reminders) |

---

## Capacitor (native)

```bash
npm install && npm run build && npx cap sync && npx cap run android
```

Use `npx cap add ios` on macOS. For production builds, remove dev `server.url` from `capacitor.config.ts` before `npm run build && npx cap sync`.

---

## Database (core tables)

**Core:** `societies`, `super_admins`, `admins`, `society_roles`, `guards` (`photo_url`), `guard_documents`, `guard_attachments`, `guard_shifts`

**Gate:** `visitors`, `resident_vehicles`, `approval_requests`, `visitor_passes`, `blacklist`

**Residents:** `flats`, `members`, `resident_users`

**Finance:** `maintenance_charges`, `maintenance_payments`, `finance_entries`, `finance_entry_allocations`, `finance_entry_counterparties`, `finance_reminder_settings`, `head_fund_adjustments`, `reserve_fund_transfers`

**Community:** `donation_campaigns`, `donation_payments`, `expense_groups`, `expenses`, `expense_splits`, `events`, `event_contributions`, `polls`, `poll_options`, `poll_votes`, `poll_election_ballots`, `meetings`, `meeting_attendees`, `meeting_decisions`, `meeting_documents`, `committee_members`

**Ops:** `notifications` (`delivery_batch_id`, `read_at`), `fcm_web_tokens`, `emergency_alerts`, `support_tickets`, `parking_spaces`, `geofence_settings`, `biometric_credentials`, `audit_logs`, `password_reset_tokens`

**Storage buckets:** `guard-documents` (profile photos, ID scans); `notification-media` (alerts, finance PDFs, meetings)

---

## Getting started

### Local development

```bash
npm install
cp .env.example .env   # Windows: copy .env.example .env
npm run dev
npm run test
npm run lint
npm run build
```

### Configuration

Copy [`.env.example`](.env.example) to `.env` and fill in values.

| Area | Variables |
|------|-----------|
| Supabase | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` |
| Firebase (optional) | `VITE_FIREBASE_*` — phone OTP, Analytics; `VITE_FIREBASE_VAPID_KEY` for FCM web push |
| reCAPTCHA Enterprise | `VITE_RECAPTCHA_ENTERPRISE_SITE_KEY` (+ matching Edge Function secrets) |
| Push (server) | Supabase secret `FIREBASE_SERVICE_ACCOUNT_JSON` for FCM, or `ONESIGNAL_REST_API_KEY` for OneSignal-only |
| Emergency WhatsApp | `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID` on `send-emergency-alert` |
| Superadmin recovery | `RESEND_API_KEY`, `RESEND_FROM` on recovery edge functions |

Edge Function secrets (PhonePe, etc.) are documented in `.env.example` and the Supabase dashboard.

### Migrations & storage

Apply **all pending** SQL under `supabase/migrations/` (see VERSION-2-RELEASE migration table). Ensure Storage buckets **`notification-media`** and **`guard-documents`** exist with upload policies.

### Deployment

- **Web:** Vite build → Vercel or static host; set all `VITE_*` env vars in production
- **Supabase:** Push migrations via CLI or dashboard; configure Edge Function secrets
- **Native:** `npm run build && npx cap sync`; remove dev server URL from Capacitor config
- **Rollback:** Restore prior migration snapshot or DB backup; no automated down-migrations — test on staging first

### Push notification setup

1. Configure FCM (`VITE_FIREBASE_VAPID_KEY` + `FIREBASE_SERVICE_ACCOUNT_JSON`) and/or OneSignal.
2. Sign in; allow browser notification permission when prompted.
3. Admins send from Notifications UI; finance period reports use batched delivery with read receipts.

**Code map:** `AdminGuardManager.tsx`, `FinanceManager.tsx`, `FinanceAuditAlarms.tsx`, `FinanceIntegrityAudit.tsx`, `ManualAuditTracer.tsx`, `SocietyGovernanceGuide.tsx`, `AboutPage.tsx`, `MeetingManager.tsx`, `CommitteeManager.tsx`, `EventsModule.tsx`, `EventFoodReconciliation.tsx`, `PollManager.tsx`, `ElectionModule.tsx`, `EmergencyAlertPanel.tsx`, `ReportPage.tsx`, `NotificationCenter.tsx`, `AdminDashboard.tsx`, `useStore.ts`, `supabase/functions/*`.

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

| Document | Purpose |
|----------|---------|
| **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)** | V2 shipped features & full migration index |
| **[CHANGELOG.md](./CHANGELOG.md)** | Keep a Changelog entries |
| **[docs/PRODUCT-V2.md](./docs/PRODUCT-V2.md)** | **Future** roadmap (V2.1–V3; not all shipped) |
| **[docs/architecture/OVERVIEW.md](./docs/architecture/OVERVIEW.md)** | Architecture overview & diagrams |
| **[docs/architecture/FINANCIAL-DATA-FLOW.md](./docs/architecture/FINANCIAL-DATA-FLOW.md)** | Finance traceability |
| **[docs/architecture/USER-ROLE-MATRIX.md](./docs/architecture/USER-ROLE-MATRIX.md)** | Role × module access |

---

## Public Pages

| Route | Page | Description |
|-------|------|-------------|
| `/about` | About Kutumbika | Vision, Purpose, Planning & Structure, Guiding Principles |
| `/privacy` | Privacy Policy | Data collection, usage, retention, security |
| `/terms` | Terms of Service | Usage terms and conditions |
| `/contact` | Contact | Support and communication channels |
| `/delete-account` | Delete Account | Account deletion instructions |
| `/society-signup` | Society Signup | PhonePe-paid new society registration |

---

## License

Copyright © 2026. **MCSPL**.
