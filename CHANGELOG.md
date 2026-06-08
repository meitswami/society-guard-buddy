# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
when version tags are published.

## [Unreleased]

### Added

- **Emergency / Alert mode** — Guards get a dedicated **Alert** tab; residents get an **Emergency or Alert** button. Photos, FCM push, and WhatsApp broadcast via `send-emergency-alert`. Migration `20260524140000`.
- **Committee module** — MC roster (`committee_members`): position, flat, tenure, elected/nominated, election trace. Migration `20260524130000`, `20260606150000`.
- **Audit & financial integrity** — Duplicate maintenance alarms with inline edit/delete; self-audit engine (10 checks); manual audit tracer; ledger overcount panel; society governance guide; public About page.
- **Events & food** (replaces Splitwise tab) — Event-linked groups, food vs payment category, headcount splits, EventFoodReconciliation panel. Migrations `20260602110000`–`20260602120000`, `20260606122832`, `20260607110651`.
- **Events & food — contribution receipts** — Flat owners or outsiders; individual, headcount, lump, or same-per-flat collection; flat-wise or non-flat receipt lines with batch grouping. Migrations `20260608120000`, `20260608130000`.
- **Events & food — receipt edit/delete** — Shared modals across Events, Food expenses, and Reconciliation with cross-section refresh.
- **Events & food — cash/bank breakdown** — Channel totals at reconciliation and event levels.
- **Events & food — fund adjustments** — Shortfall cover (member advance, maintenance pool, corpus) or surplus transfer to society pool. Migration `20260608140000`.
- **Head fund reconciliation** — Per expense-head inflow/outflow/adjustments. Migration `20260607111313`.
- **Reserve / operating fund** — Surplus/deficit tracking and reserve transfers. Migration `20260607111507`.
- **Society pool receipts** — Record to pool, distribute to flats later. Migration `20260602100000`.
- **Finance — transaction_date** — Accurate period report dating. Migration `20260602130000`.
- **Finance — recording_date** — Separate recording vs billing date on payments/expenses. Migration `20260530110000`.
- **Chart of accounts** — `major_head` on expense groups. Migration `20260606140000`.
- **Election governance** — Nomination/voting/closed/applied phases, VP post. Migration `20260607120000`.
- **Guard worker photos & documents** — Profile photo, Photo ID, unlimited attachments. Migration `20260524120000`.
- **Society meetings** — Full admin workflow: schedule, attendees, decisions, documents, signatures, audio, publish + notify.
- **Finance — period report** — FY-style range, verified collections by channel, balance cards.
- **Finance — period PDF** — Client-side jsPDF export.
- **Finance — send to members** — Batched notifications with `delivery_batch_id` and optional push.
- **Finance — read receipts** — Admin dialog using `read_at` / `is_read`.
- **Meetings — attachments, attendance, auto-save, meeting_kind, table picker.**
- **Notifications schema** — `delivery_batch_id`, `read_at` on `notifications`.
- **Polls — society elections** — Ranked ballots, `poll_election_ballots`, election results banners.
- **Donations — campaign title presets.**
- **Admin home** — Expanded KPIs, usage-sorted quick access, A–Z bottom nav.
- **Architecture docs** — `docs/architecture/OVERVIEW.md`, `FINANCIAL-DATA-FLOW.md`, `USER-ROLE-MATRIX.md`.

### Changed

- **README** — System objectives, architecture table, security model, 10-check self-audit, Events & food naming, full migration reference, env/deployment guidance.
- **`docs/VERSION-2-RELEASE.md`** — Extended through `20260608140000`; audit, committee, emergency, head/reserve fund, events/food receipt & adjustment sections; breaking changes table.
- **`docs/PRODUCT-V2.md`** — Clarified shipped vs future scope.
- **Finance — Receipts tab** — UI label renamed to **Transactions** (internal id still `receipts`).
- **REPORTS** — Replaced legacy "Daily Reports" with `ReportPage.tsx` (Financial, Visitor, Vehicle, All Modules).
- **Backend docs** — Lovable Cloud → Supabase; FCM primary + OneSignal fallback.
- **Admin session restore** — Re-fetch `admins` + `society_roles` on load for fresh RBAC.
- **Zustand `setSocietyId`** — Skip clearing lists when society UUID unchanged.
- **Splitwise → Events & food** — Admin tab and KPI naming aligned in UI copy.

### Migration notes

Apply **all pending** SQL under `supabase/migrations/` in timestamp order.

| File prefix | Summary |
|-------------|---------|
| `20260502154500` | `finance_reminder_settings` |
| `20260503100000` | Finance ledger (`finance_entries`, allocations, counterparties) |
| `20260510180000`, `20260510200000` | Meetings + executives present |
| `20260511120000` | `notifications.delivery_batch_id`, `read_at` |
| `20260512100000` | Enable `finance` in `society_roles.permissions` |
| `20260513120000` | `meeting_documents.sort_order` |
| `20260515120000` | `meetings.meeting_kind` |
| `20260515140000` | Poll elections |
| `20260524120000` | Guard photos + `guard_attachments` |
| `20260524130000` | `committee_members` |
| `20260524140000` | Emergency alerts + WhatsApp |
| `20260530110000` | `recording_date` columns |
| `20260602100000` | Society pool record mode |
| `20260602110000` | Event groups + headcount splits |
| `20260602120000` | Food vs payment expense category |
| `20260602130000` | `finance_entries.transaction_date` |
| `20260602140000` | Ledger titles from expense heads |
| `20260606122832` | Migrate non-food out of Events |
| `20260606140000` | `major_head` chart of accounts |
| `20260606150000` | Committee flat + tenure |
| `20260607110651` | Event food ↔ finance correlation |
| `20260607111313` | Head fund reconciliation |
| `20260607111507` | Reserve fund transfers |
| `20260607120000` | Election governance phases |
| `20260608120000` | Event contributions: contributor type, headcount, split mode |
| `20260608130000` | Receipt basis (flat / non_flat), batch grouping |
| `20260608140000` | Event food fund adjustments |

Ensure Storage buckets **`notification-media`** and **`guard-documents`** exist with upload policies.

### Rollback considerations

No automated down-migrations. Restore Supabase backup before applying on production if uncertain. Schema and frontend deploy together — partial rollback requires matching git tag to migration state.
