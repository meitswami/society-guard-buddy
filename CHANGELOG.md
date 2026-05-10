# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
when version tags are published.

## [Unreleased]

### Added

- **Society meetings** — Admin meetings flow with scheduling, attendees, decisions, documents, minutes/discussion, optional audio; database tables `meetings`, `meeting_attendees`, `meeting_decisions`, `meeting_documents`, plus executives-present migration.
- **Finance — period report** — Sub-tab under Finance with default range (financial year from 1 April to today), verified collections by payment channel, head-wise separate-entry expenses, and balance summary cards.
- **Finance — period PDF** — Client-side PDF export via jsPDF (`src/lib/financePeriodReportPdf.ts`).
- **Finance — send to members** — Upload period PDF to `notification-media`, insert per-resident `notifications` rows with shared `delivery_batch_id`, optional invoke of `send-push-notification` with `target_type: user`; audience modes: all residents, selected flats, or individually picked residents.
- **Finance — read receipts** — Admin dialog listing recipients for the last batch, using `is_read` / `read_at` from `notifications`.
- **Meetings — attachments** — Single **Browse files** control with `multiple` selection for many images and/or PDFs from the device file manager; **Take photo** for one camera capture; **`sort_order`** on `meeting_documents` with up/down controls to reorder the list.
- **Meetings — attendance** — Checkbox multi-select, **Select all** / **Clear**, bulk **Mark present** / **Mark absent** / **Remove selected** (each with SweetAlert2 confirmation where destructive or broad).
- **Meetings — confirmations** — SweetAlert2 (`confirmAction`) on save meeting details, save notes & minutes, save executives, status change, publish toggle, publish-to-all, flat present/remove, remove attendee/decision, single present toggle, replace audio upload, save/overwrite signature, and delete meeting (already present).
- **Notifications schema** — Columns `delivery_batch_id` (uuid) and `read_at` (timestamptz) on `public.notifications` for batched delivery and read tracking.
- **Resident read tracking** — `NotificationCenter` updates `read_at` together with `is_read` when a user opens or marks notifications read (resident and generic bulk paths).
- **RBAC — Finance** — `NEW_CUSTOM_ROLE_PERMISSIONS` includes `finance: true` for newly defined custom roles; migration `20260512100000_enable_finance_on_society_roles.sql` backfills `permissions.finance` to true on existing `society_roles` where it was not already true.

### Changed

- **README** — Documented finance period report, PDF/push/read receipts, meetings, notification columns, migration reference table, storage paths, and main code touchpoints.
- **Admin dashboard** — Passes `adminId` into `FinanceManager` alongside `adminName` for consistency with other admin modules.
- **Admin session restore** — On app load, re-fetch `admins` + `society_roles` and recompute `permissions` instead of trusting only `localStorage`, so RBAC updates (e.g. Finance) appear after refresh without a full logout.

### Migration notes

Apply pending SQL under `supabase/migrations/` to your Supabase project. Relevant files include:

| File prefix | Summary |
|-------------|---------|
| `20260503100000` | Finance ledger (`finance_entries`, allocations, counterparties) |
| `20260502154500` | `finance_reminder_settings` |
| `20260510180000`, `20260510200000` | Meetings + executives present |
| `20260511120000` | `notifications.delivery_batch_id`, `notifications.read_at` |
| `20260512100000` | Enable `finance` in `society_roles.permissions` |

Ensure Storage bucket **`notification-media`** exists and policies allow the app to upload finance report PDFs where used.
