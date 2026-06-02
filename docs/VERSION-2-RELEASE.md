# Version 2 — release notes (shipped to date)

**Kutumbika / Society Guard Buddy** — expanded list of **Version 2** product and schema changes. For install, env vars, stack, and the short overview, see the root **[README.md](../README.md)**.

---

## V2.0 — what shipped

### Meetings & governance

- Full **Meetings** admin workflow: title, schedule, venue, executives (free text), discussion & minutes, decisions, documents, per-attendee signatures, optional audio, publish + notify residents.
- **`meeting_kind`**: General body, Annual, Executive committee, Other — set on create and in the record; **filter** meeting list by type; **print** current view, all types grouped, or open meeting detail.
- **Attendance:** flat **Present** shortcut; **Table pick** dialog to add many flat members at once; guests and admin line; checkbox multi-select with bulk present / absent / remove (confirmations where needed).
- **Documents:** multi-select **Browse files** (images + PDFs), reorder with up/down, extra **Choose files** under Documents & signatures; **Take photo** for single capture.
- **Auto-save** (~1s debounce) for header, notes, executives, decisions; **Save all fields now**; drafts rehydrate only when switching meeting so refetch does not wipe typing.

### Finance

- **Period report** sub-tab: financial-year-style default range, verified inflows by channel, separate-entry expenses, balance cards.
- **PDF export** (client jsPDF) and **send to members** with optional push; **`delivery_batch_id`** + **`read_at`** on notifications for batches and read receipts.
- **Transactions** tab — filter **event/function expense records** vs **society receipt records**; **society pool** default on record (distribute equally to flats later).
- **Event expenses** (was Splitwise) — groups link optional **Events**; default split **by adults & kids per flat** (member age/relation); admin nav under Community.
- Ledger, maintenance payments, reminders, and verification flows as documented in migrations.

### Polls & society elections

- **Standard polls** — single choice per resident; vote breakdown by option (admin).
- **Elections** — separate **New society election**: candidates per **President**, **Secretary**, **Treasurer**, and **Committee**; configurable **committee seats** (min 5); residents submit **ranked ballots** (unique ranks 1…n per post); **max two ballots per flat** (e.g. spouses), one ballot per member (upsert).
- **Close election** runs Borda-style tally, stores **`election_results`**, shows **elected names** on admin Home, resident Approvals (home), and Polls screen (`ElectionResultsBanner` + cards).

### Donations

- **Campaign title** presets: marriage anniversary, on birthdays, new born child entry, marriage functions, festivals, voluntary contribution, visitors parking, any other occasion, miscellaneous receipts; optional **custom** title.

### Admin portal (Home)

- Extra **KPI cards**: meetings held; verified **maintenance collected**; **Splitwise** active expense total; visitors (**guest** vs **serviceman**); vehicles total with **cars** vs **two-wheelers**; flats + **member count**; guards + **blacklist** count.
- **Quick access:** every allowed module tile; order by **local usage count** (per society, `localStorage`), then A–Z on ties.
- **Bottom navigation:** tabs sorted **A–Z** by label (with “A–Z navigation” hint).

### Guards (admin)

- **Worker profile photo** per guard: capture via **camera** or **gallery**, stored in `guards.photo_url` (Supabase Storage `guard-documents`).
- **List UI:** small thumbnail beside **guard ID**; **double-tap** thumbnail to enlarge full-screen.
- **Photo ID:** front/back per document type (Aadhaar, PAN, etc.) with camera or gallery upload.
- **Multiple documents:** `guard_attachments` table — browse many files (images + PDF) or take photo; custom label per batch; thumbnails with double-tap enlarge.

### Platform / data

- **`setSocietyId`** in Zustand: if the society UUID **unchanged**, the store **no longer clears** guards/visitors/flats/members (fixes unnecessary wipes on admin re-render / Strict Mode dev double-mount).

---

## Schema & migrations (V2-related)

Apply all pending files under `supabase/migrations/`. Highlights:

| Migration (prefix) | Summary |
|--------------------|---------|
| `20260503100000` | Finance ledger tables |
| `20260502154500` | Finance reminder settings |
| `20260510180000` | Meetings core tables |
| `20260510200000` | `meetings.executives_present` |
| `20260513120000` | `meeting_documents.sort_order` |
| `20260511120000` | `notifications.delivery_batch_id`, `read_at` |
| `20260512100000` | Enable `finance` in `society_roles.permissions` |
| `20260515120000` | `meetings.meeting_kind` |
| `20260515140000` | Poll elections (`poll_kind`, `election_*`, `poll_election_ballots`) |
| `20260524120000` | `guards.photo_url`, `guard_attachments` (worker photos + multi-document uploads) |

---

## Related docs

- **[README.md](../README.md)** — main readme (overview + links).
- **[CHANGELOG.md](../CHANGELOG.md)** — Keep a Changelog–style `[Unreleased]` entries.
- **[PRODUCT-V2.md](./PRODUCT-V2.md)** — **future** roadmap (RBAC editor, guard-centric UX, voice/AI); not all items are shipped.

---

*Document version: aligned with repo through V2 meeting / election / admin / donation / finance UX updates.*
