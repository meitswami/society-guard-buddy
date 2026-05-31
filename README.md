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
| **Audit & Governance** | Duplicate maintenance alarms (edit/remove in-place); **Internal Self-Audit** engine (negative cash/bank detection with reasons & rectification, recording vs reporting discrepancy, orphaned payments, stuck pending, flat count mismatch, non-standard amounts); **Society Governance Framework** (Principal, Purpose, Vision, Planning & Structure, Policy & Compliance). |
| **Polls** | Standard polls + **MC elections** (ranked ballots, 2 ballots/fl max, `election_results`, home banners). |
| **Donations** | Preset campaign titles + custom. |
| **Admin Home** | Extra KPIs, usage-sorted quick access, A–Z bottom nav. |
| **Guards (admin)** | Worker **profile photo** (camera + gallery) shown as thumbnail next to guard ID; **double-tap** to enlarge; **multiple documents** per guard (images + PDF); Photo ID front/back with camera or gallery. |
| **Store** | `setSocietyId` skips wiping data when society id unchanged. |

Apply SQL in `supabase/migrations/` (full table: **[docs/VERSION-2-RELEASE.md](./docs/VERSION-2-RELEASE.md)** — includes `20260515120000`, `20260515140000`, `20260524120000`, `20260524130000_committee_members`).

---

## Features (overview)

- **Auth:** Society-first flow; guard / resident / admin / super admin; WebAuthn biometrics; password reset; admin RBAC via `society_roles.permissions`.
- **Guards (admin):** CRUD, password/OTP login, KYC status; **worker photo** on list (thumbnail + guard ID, double-tap enlarge); capture via **camera** or **gallery**; **Photo ID** (front/back per document type); **unlimited attachments** (multi-select browse + take photo, images/PDF).
- **Gate:** Visitors, approvals, OTP passes, delivery & service, vehicles, blacklist, quick entry, directory.
- **Finance:** Maintenance, ledger, reminders, period report + PDF + targeted notifications, Transactions list.
- **Audit & Governance:** Duplicate maintenance credit alarms (expand, edit, delete in-place); **Self-Audit engine** — Run button checks negative cash/bank balances (with reason + rectification steps), recording vs reporting discrepancy, orphaned payments, flat count mismatch, non-standard amounts, stuck pending entries, unpaid flats; **Society Governance Framework** — expandable reference for Principal (authority structure), Purpose (why the system exists), Vision (short & long-term), Planning & Structure (modules, data flow, collaboration roles), Policy & Compliance (financial policies, audit policies, common issues & resolution, regulatory compliance).
- **Meetings:** Full module (see readme.md).
- **Community:** Donations (presets), Splitwise, events, polls & elections, parking.
- **Ops:** Notifications (FCM / OneSignal), REPORTS, audit, geofence, settings; **Capacitor** for native builds.
- **About Page (`/about`):** Public-facing page reflecting the society's Vision, Purpose, Planning & Project Structure, and Guiding Principles. Linked from login footer.

---

## Audit Section (detailed)

The Audit tab in the Admin Dashboard is a comprehensive governance and integrity hub:

### 1. Security Audit Logs
Standard event log — login success/failure, password changes, biometric registrations, geofence violations. Searchable and filterable.

### 2. Duplicate Maintenance Alarms
Auto-detects when the same flat is credited twice in the same month via the same channel (cash or bank). Each alarm expands to show individual payment entries with **Edit** and **Delete** buttons — fix directly from the audit section without navigating elsewhere.

### 3. Internal Self-Audit Engine
A **"Run Self-Audit"** button that performs 9 automated checks:

| Check | Severity | What it detects |
|-------|----------|-----------------|
| Negative Cash Balance | 🔴 Critical | Cash outflow > cash inflow |
| Negative Bank Balance | 🔴 Critical | Bank outflow > bank inflow |
| Duplicate Payments | 🔴 Critical | Same flat + charge + month + channel > 1 entry |
| Recording vs Reporting | 🟡 Warning | maintenance_payments total ≠ finance_entries total |
| Orphaned Payments | 🟡 Warning | Verified payments with no finance_entry link |
| Flat Count Mismatch | 🟡 Warning | Ledger entry flat count ≠ actual linked payments |
| Non-Standard Amounts | 🔵 Info | Payment amount differs from charge definition |
| Stuck Pending (>7 days) | 🟡 Warning | Unverified payments older than a week |
| Unpaid Flats This Month | 🔵 Info | Occupied flats with no current-month payment |

Each finding shows: **Why it happens** (root cause), **How to rectify** (step-by-step), and **Raw data** (actual figures).

### 4. Society Governance Framework
Expandable reference panel covering:

- **Principal** — Governing authority, accountability chain, fiduciary responsibilities
- **Purpose** — Core purpose, problems addressed, digital-first approach
- **Vision** — Short-term (zero manual registers, auto-reports) and long-term (self-auditing, predictive budgeting, paperless AGM)
- **Planning & Structure** — Module breakdown, data flow, collaboration guidelines (who does what)
- **Policy & Compliance** — Financial policies, audit policies, common issue resolution, regulatory compliance (Co-op Societies Act, IT, GST)

---

## About Page (`/about`)

A public-facing standalone page accessible from the login footer. Communicates the project's identity to residents, committee members, and prospective societies.

### Sections

| Section | Content |
|---------|---------|
| **Vision** | Immediate goals (digital-first, 100% tracking, auto-reports) + Long-term vision (self-auditing, predictive budgeting, paperless AGM, vendor management, multi-society federation, AI insights). North star statement. |
| **Purpose** | Core purpose cards (transparency, accountability, trust, error elimination). Problems solved (duplicates, negative balances, unverified payments, mismatches, paper logs). |
| **Planning & Structure** | 10-module system map with descriptions. Data flow pipeline visualization. Collaboration roles table (Admin, Treasurer, Secretary, Committee, Residents). Technology stack badges. |
| **Guiding Principles** | Transparency First · Accountability by Design · Member-Centric · Data Integrity · Simplicity · Compliance Ready |

Route: `/about` · Component: `src/pages/AboutPage.tsx` · Linked from: `LoginFooter.tsx`

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

`societies`, `super_admins`, `admins`, `society_roles`, `guards` (**`photo_url`**), `guard_documents`, **`guard_attachments`**, `guard_shifts`, `visitors`, `resident_vehicles`, `approval_requests`, `visitor_passes`, `flats`, `members`, `resident_users`, `blacklist`, `maintenance_charges`, `maintenance_payments`, `finance_entries` (+ allocations, counterparties), `finance_reminder_settings`, **`committee_members`**, donations & expense split tables, `events` (+ RSVPs, contributions), `polls` / `poll_options` / `poll_votes` / **`poll_election_ballots`**, **`meetings`** (+ attendees, decisions, documents), `notifications` (**`delivery_batch_id`**, **`read_at`**), `fcm_web_tokens`, `parking_spaces`, `geofence_settings`, `biometric_credentials`, `audit_logs`, `password_reset_tokens`.

Storage buckets: **`guard-documents`** (guard profile photos, ID scans, attachments); **`notification-media`** (alerts, finance PDFs, meetings, etc.).

---

## Getting started

```bash
npm install
cp .env.example .env
npm run dev
```

Set **`VITE_SUPABASE_URL`** and **`VITE_SUPABASE_PUBLISHABLE_KEY`**. Optional: Firebase / FCM / reCAPTCHA per `.env.example`. Run all Supabase migrations.

**Code map:** `AdminGuardManager.tsx` (guard photos & documents), `FinanceManager.tsx`, `FinanceAuditAlarms.tsx` (duplicate detection + inline edit/delete), `FinanceIntegrityAudit.tsx` (self-audit engine), `SocietyGovernanceGuide.tsx` (governance framework), `AboutPage.tsx` (public vision/purpose/planning page), `MeetingManager.tsx`, `PollManager.tsx`, `electionTally.ts`, `ElectionResultsBanner.tsx`, `DonationManager.tsx`, `AdminDashboard.tsx`, `ResidentDashboard.tsx`, `ReportPage.tsx`, `NotificationCenter.tsx`, `PhotoCapture.tsx`, `useStore.ts`, `supabase/functions/*`.

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

## Public Pages

| Route | Page | Description |
|-------|------|-------------|
| `/about` | About Kutumbika | Vision, Purpose, Planning & Structure, Guiding Principles |
| `/privacy` | Privacy Policy | Data collection, usage, retention, security |
| `/terms` | Terms of Service | Usage terms and conditions |
| `/contact` | Contact | Support and communication channels |
| `/delete-account` | Delete Account | Account deletion instructions |
| `/society-signup` | Society Signup | New society registration form |

---

## License

Copyright © 2026. **MCSPL**.
