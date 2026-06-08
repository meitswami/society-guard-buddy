# Version 2 — release notes (shipped to date)

**Kutumbika / Society Guard Buddy** — expanded list of **Version 2** product and schema changes. For install, env vars, stack, and the short overview, see the root **[README.md](../README.md)**.

**Architecture:** [OVERVIEW.md](./architecture/OVERVIEW.md) · [FINANCIAL-DATA-FLOW.md](./architecture/FINANCIAL-DATA-FLOW.md) · [USER-ROLE-MATRIX.md](./architecture/USER-ROLE-MATRIX.md)

---

## V2.0 — what shipped

### Meetings & governance

- Full **Meetings** admin workflow: title, schedule, venue, executives (free text), discussion & minutes, decisions, documents, per-attendee signatures, optional audio, publish + notify residents.
- **`meeting_kind`**: General body, Annual, Executive committee, Other — filter meeting list; print current view, all types grouped, or single meeting detail.
- **Attendance:** flat **Present** shortcut; **Table pick** dialog to bulk-add flat members; guests and admin line; checkbox multi-select with bulk present / absent / remove.
- **Documents:** multi-select **Browse files** (images + PDFs), reorder with up/down; **Take photo** for single capture.
- **Auto-save** (~1s debounce) for header, notes, executives, decisions; drafts rehydrate only when switching meeting.

### Finance

- **Period report** sub-tab: financial-year-style default range, verified inflows by channel, separate-entry expenses, balance cards.
- **PDF export** (client jsPDF) and **send to members** with optional push; **`delivery_batch_id`** + **`read_at`** on notifications for batches and read receipts.
- **Transactions** tab (UI label; internal id `receipts`) — filter event/function expense records vs society receipt records; society pool default on record (distribute to flats later).
- **Record payment** sub-tab with **Head fund reconciliation** — per expense-head inflow/outflow/adjustments (`head_fund_adjustments`).
- **Totals** sub-tab — operating surplus/deficit and **reserve fund transfers** (`reserve_fund_transfers`).
- **Flat Report** — per-flat financial statement.
- **Society pool** — `record_mode: society_pool`; record to pool first, distribute equally to flats later (`distributed_at`).
- **`transaction_date`** on `finance_entries` for accurate period reporting.
- **`recording_date`** on payments and expenses (vs billing/due date).
- Ledger, maintenance payments, reminders, and admin verification flows.

### Events & food (formerly Splitwise)

- Admin tab **Events & food** (legacy permission flag: `splits`; tab id `events`).
- `expense_groups.group_kind`: `event` | `general`; optional link to **Events** calendar.
- `expenses.expense_category`: `food` | `payment`; default split by **adults & kids per flat** (member age/relation).
- Non-food society expenses migrated to Finance → Record payment / Transactions (`20260606122832`).
- **EventFoodReconciliation** — event contributions (in) vs food/catering bills (out); separate from Finance → Transactions.
- Chart of accounts: `expense_groups.major_head`.
- **Contribution receipts** — flat owners or outsiders; per-flat, headcount (adults/kids), lump equal, or same-per-flat modes (`event_contributions.contributor_type`, `split_mode`, `adult_count`, `kid_count`).
- **Receipt structure** — flat-wise lines or **without flat** (single payer/description); batch grouping via `batch_id` / `batch_label`; `receipt_basis` flat | non_flat.
- **Edit & delete** — contribution receipts and food bills from Events, Food expenses, or Reconciliation; sections refresh together.
- **Cash / bank breakdown** — channel totals at event, reconciliation, and summary levels.
- **Shortfall / surplus adjustments** — `event_food_fund_adjustments`: cover food shortfall from member advance, maintenance pool, corpus, or transfer excess to society pool.

### Audit & financial integrity

- **Duplicate maintenance alarms** — same flat + charge + month + channel; inline edit/delete in Audit tab.
- **Self-audit engine** — 10 automated checks: negative cash/bank, duplicates, recording vs reporting, ledger double-count, orphans, flat count mismatch, non-standard amounts, stuck pending, unpaid flats.
- **Manual Audit Tracer** — month-level cross-check of period report vs payments vs Transactions tab.
- **Ledger overcount panel** — embedded in duplicate alarms section.
- **Society Governance Framework** — in-app reference (Principal, Purpose, Vision, Planning & Structure, Policy & Compliance).
- **About page** (`/about`) — public vision, purpose, 10-module map, guiding principles.

### Committee & election governance

- **`committee_members`** — MC roster CRUD: position, flat link, tenure dates, elected/nominated, photos, female representative flag.
- **Election apply** — close election → publish `election_results` → apply winners to committee roster.
- **Election phases** — nomination → voting → closed → applied; VP post; ballot phone validation (`20260607120000`).

### Polls & society elections

- **Standard polls** — single choice per resident; vote breakdown by option (admin).
- **Elections** — candidates per President, Secretary, Treasurer, Committee; ranked ballots (unique ranks 1…n); **max two ballots per flat**; Borda-style tally on close.
- **ElectionResultsBanner** on admin Home, resident Approvals, and Polls screen.

### Donations

- **Campaign title** presets (anniversary, birthdays, festivals, voluntary contribution, visitors parking, etc.) + optional custom title.

### Emergency & monitoring

- **Emergency / Alert mode** — guard Alert tab; resident Emergency button; photos; society-wide FCM push + WhatsApp to saved numbers (`emergency_alerts`, `send-emergency-alert`).
- **Admin KPIs** — meetings held; verified maintenance collected; **event food expenses** (active); visitors (guest vs serviceman); vehicles (cars vs two-wheelers); flats + member count; guards + blacklist; KYC-pending guard alerts.
- **Quick access** — all allowed module tiles ordered by local usage count (`localStorage`), then A–Z.
- **Bottom navigation** — tabs sorted A–Z by label.

### Guards (admin)

- **Worker profile photo** — camera or gallery → `guards.photo_url` (Storage `guard-documents`).
- **List UI** — thumbnail beside guard ID; double-tap to enlarge.
- **Photo ID** — front/back per document type; **guard_attachments** for unlimited documents (images + PDF).

### Platform / integrations

- **`setSocietyId`** — skip clearing society-scoped lists when UUID unchanged.
- **Society signup** — PhonePe payment + provisioning (`phonepe-*` edge functions).
- **Superadmin backup export** — JSON export of all tables via `backup-export` edge function.
- **Support tickets** — resident feedback form; superadmin ticket viewer.
- **Dual push stack** — FCM web tokens primary; OneSignal SDK registration + REST fallback when FCM service account not configured.

---

## Architecture (V2 logical layers)

```
UI (pages/components)
  → Core (Zustand, TanStack Query, appSession)
    → Security (adminPermissions, auditLogger, geofence, WebAuthn, TOTP)
      → Domain modules (Finance, Meetings, Events, Polls, Gate)
        → Integration (Supabase client, Edge Functions)
          → Postgres + Storage + Realtime
```

Society scoping is applied in application queries (`society_id` filters). See [OVERVIEW.md](./architecture/OVERVIEW.md) for the full layer map.

---

## Breaking changes & renames (V2)

| Before | After | Notes |
|--------|-------|-------|
| Splitwise tab | **Events & food** | Permission `splits` legacy; use `events` |
| Receipts tab (Finance) | **Transactions** | Internal sub-tab id still `receipts` |
| Daily Reports | **REPORTS (Admin)** | `ReportPage.tsx` with Financial/Visitor/Vehicle/All Modules |
| Lovable Cloud (docs) | **Supabase** | Actual backend |
| OneSignal-only push (docs) | **FCM primary + OneSignal fallback** | `send-push-notification` |

Non-food expenses previously in Events were migrated to Finance ledger rows — re-run migration `20260606122832` on existing deployments if upgrading from mid-V2 builds.

---

## Schema & migrations (V2-related)

Apply **all pending** files under `supabase/migrations/` in timestamp order.

| Migration (prefix) | Summary |
|--------------------|---------|
| `20260502154500` | Finance reminder settings |
| `20260503100000` | Finance ledger tables (`finance_entries`, allocations, counterparties) |
| `20260510180000` | Meetings core tables |
| `20260510200000` | `meetings.executives_present` |
| `20260511120000` | `notifications.delivery_batch_id`, `read_at` |
| `20260512100000` | Enable `finance` in `society_roles.permissions` |
| `20260513120000` | `meeting_documents.sort_order` |
| `20260515120000` | `meetings.meeting_kind` |
| `20260515140000` | Poll elections (`poll_kind`, `election_*`, `poll_election_ballots`) |
| `20260524120000` | `guards.photo_url`, `guard_attachments` |
| `20260524130000` | `committee_members`; RBAC `committee` permission |
| `20260524140000` | Emergency alerts + WhatsApp phones on members/residents |
| `20260530110000` | `recording_date` on expenses, maintenance_payments |
| `20260602100000` | Society pool record mode + `distributed_at` |
| `20260602110000` | Event groups + headcount split weights |
| `20260602120000` | `expense_category` food vs payment |
| `20260602130000` | `finance_entries.transaction_date` |
| `20260602140000` | Ledger titles from expense heads |
| `20260606122832` | Migrate non-food out of Events to society payments |
| `20260606140000` | `expense_groups.major_head` chart of accounts |
| `20260606150000` | Committee flat link + tenure |
| `20260607110651` | Event food ↔ finance correlation |
| `20260607111313` | Head fund reconciliation + `head_fund_adjustments` |
| `20260607111507` | Reserve fund transfers |
| `20260607120000` | Election governance phases + VP post |
| `20260608120000` | Event contributions: contributor type, headcount, split mode |
| `20260608130000` | Receipt basis (flat / non_flat), batch grouping; optional flat_number |
| `20260608140000` | Event food fund adjustments (shortfall cover / surplus to pool) |

Ensure Storage buckets **`notification-media`** and **`guard-documents`** exist with upload policies.

---

## Environment & deployment

See README **Getting started** for `VITE_*` variables and Edge Function secrets. Minimum production requirements:

- Supabase project with all migrations applied
- `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`
- FCM: `VITE_FIREBASE_VAPID_KEY` + `FIREBASE_SERVICE_ACCOUNT_JSON` secret
- Optional: OneSignal, WhatsApp, PhonePe, Resend (per feature)

**Rollback:** No automated down-migrations. Restore from Supabase backup before applying if unsure. Feature flags are not used — schema and code deploy together.

---

## Future (not shipped — see PRODUCT-V2.md)

- Society-admin in-app **role editor** (V2.1)
- Action-level CRUD permissions + hardened RLS (V2.1)
- Guard voice wizard / AI slot-fill (V2.2–V2.3)
- Advanced analytics, compliance pack, multi-org federation (V3)

---

## Related docs

- **[README.md](../README.md)** — main readme (overview + setup).
- **[CHANGELOG.md](../CHANGELOG.md)** — Keep a Changelog `[Unreleased]` entries.
- **[PRODUCT-V2.md](./PRODUCT-V2.md)** — **future** roadmap; distinguish from shipped V2 above.

---

*Document version: aligned with repo through `20260608140000` (meetings, finance, audit, events/food receipts & adjustments, committee, emergency, head/reserve funds, election governance).*
