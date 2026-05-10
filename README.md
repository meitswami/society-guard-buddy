# 🏢 Kutumbika — Society Management System

*Parivaar Jaisi Society*

A comprehensive, mobile-first multi-society gate management application built for security guards, residents, admins, and super admins to manage visitor entries, approvals, vehicle tracking, finance, events, notifications, and daily reporting. Users choose their society before signing in so credentials are always scoped to the correct community.

## ✨ Features

### 🔐 Multi-Tier Authentication
- **Society selection first** — active societies (same order as the superadmin list: A–Z by name), then role-specific login
- **Guard login** with ID & password — shift tracking with timestamps
- **Resident login** with phone & password — manage approvals & visitor passes
- **Admin login** with ID & password — full society management
- **Super Admin login** — platform-wide multi-society management (no society required)
- **Biometric login** — fingerprint/face unlock via WebAuthn API (all user types)
- **Password reset** — email-based OTP reset for admins & residents; admin-only guard reset
- Role-based dashboards for each tier

### 👤 Visitor Management
- Full visitor registration (name, phone, document, photos)
- Auto-fill from previous visits (phone-based lookup)
- Repeat visitor alerts & blacklist checking on entry
- Vehicle tracking per visit
- Quick re-entry for frequent visitors (2+ visits)

### ✅ Resident Approval System
- Guard sends **real-time approval request** to resident's dashboard
- Resident receives **sound notification** for pending approvals
- One-tap **Approve / Reject** with 2-minute timeout
- Full approval history for residents

### 🔑 OTP Visitor Pass System
- Residents (or guards) generate **6-digit OTP passes** for expected guests
- Passes include **date + time slot** restrictions
- Guard verifies OTP at the gate — auto-registers the visitor if valid

### 🚗 Vehicle Registry
- Resident vehicle registration linked to flats
- Vehicle type categorization (car, bike, delivery, other)

### 📦 Delivery & Service Entry
- Quick logging for delivery partners (Amazon, Flipkart, Swiggy, etc.)
- Service staff tracking (electrician, plumber, etc.)

### 🏠 Flat & Member Directory
- Complete flat registry with wing, floor, and owner details
- Member profiles with relation, age, gender

### 🚫 Blacklist Management
- Flag visitors by phone number or vehicles by registration
- Real-time blacklist alerts during entry

### 📊 Daily Reports
- Date-wise visitor statistics
- Guard shift logs
- CSV export & print-ready HTML reports

### 💰 Finance Management
- **Maintenance charges** — create recurring charges with custom frequency & due dates
- **Payment tracking** — residents pay via Cash, UPI, or upload payment screenshots
- **Admin verification** — treasurer/admin verifies & approves each payment with receipt
- **Payment status** — pending, verified, rejected statuses with full audit trail
- **Ledger / receipts** — `finance_entries` (flat + outsider flows, separate-entry expenses) with per-flat allocations; linked to verified maintenance payments where applicable
- **Auto-reminders** — configurable schedule (`finance_reminder_settings`); cron + Edge Function sends push + in-app reminders for unpaid dues
- **Period report** (Finance → *Period report*) — default range financial year (1 Apr → today), adjustable: verified collections by cash / bank / other, expenses head-wise (separate-entry ledger), footer balances (cash in hand, bank, other, total)
- **PDF export** — download the same period summary as a PDF (client-side jsPDF)
- **Send report to members** — upload PDF to `notification-media`, create one in-app notification per resident (`target_type: user`) with a shared `delivery_batch_id`; optional **push** via `send-push-notification`; audience: **all residents**, **selected flats**, or **hand-picked residents**
- **Read receipts** — when a resident opens an alert, the app sets `read_at` (and read); admins can open **Read receipts** on the period tab to see who has seen that send

### 🎁 Donation Management
- Create donation campaigns with target amounts & deadlines
- Track contributions per flat with progress bars
- Support Cash & UPI with screenshot uploads

### 💸 Splitwise (Expense Splitting)
- Create expense groups for shared society costs
- Split expenses equally or custom across flats
- Track who owes whom with settlement status

### 🎉 Events & Functions
- Create events with date, time, location, and contribution amounts
- RSVP tracking per flat with member counts
- Contribution collection & verification per event

### 📊 Polls & Voting
- Create polls with multiple options (single or multi-select)
- Residents vote from their dashboard
- Live percentage-based results

### 📋 Society Meetings
- **Meetings** (admin) — schedule with date/time/place, attendees (flat-wise presence), discussion notes / minutes, decisions, document uploads, optional audio; publish and notify members when ready
- Related tables: `meetings`, `meeting_attendees`, `meeting_decisions`, `meeting_documents`, signatures / executive presence per migrations

### 🔔 Notifications & Push
- **In-app notifications** — stored in the database with read/unread; **`read_at`** records when the recipient first opened the item (used for finance report read receipts and similar batched sends via **`delivery_batch_id`**)
- **Web push** — **Firebase Cloud Messaging (FCM)** for web: device tokens in `fcm_web_tokens`; the `send-push-notification` Edge Function sends via FCM when `FIREBASE_SERVICE_ACCOUNT_JSON` is configured
- **OneSignal** — web SDK registers users/tags; Edge Function **falls back** to the OneSignal REST API when FCM service-account JSON is not set (`ONESIGNAL_REST_API_KEY`)
- **Targeted sending** — admin can send to all residents, specific flats (multi-select), or specific persons (multi-select); finance period report uses the same targeting model
- **Auto-reminders** — scheduled push + in-app reminders for unpaid maintenance dues (cron + Edge Function)
- Notification types include: General, Alert, Event, Payment Reminder, and **`finance_period_report`** (period PDF + link to each resident)

### 🅿️ Parking Management
- Add parking spaces with floor levels & types (car/bike/visitor)
- Allocate spaces to flats with vehicle numbers
- Track available vs. allocated spaces

### 🛡️ Admin Features
- Manage guards (add/delete/reset passwords)
- Manage residents (add/edit/delete)
- Geofence setup for guard login boundary
- Admin password change
- Biometric setup
- Full audit log viewer with filters
- **RBAC** — panel tabs (including **Finance**) follow `society_roles.permissions` JSON; admins with **no** `role_id` keep full access (legacy). New custom roles default **Finance on** in code; a migration can backfill `finance: true` for existing roles (see migrations list below)

### 👑 Super Admin Features
- Create & manage multiple societies
- Define custom RBAC roles (President, Secretary, Treasurer, etc.) with per-tab booleans in `permissions`
- Appoint society-specific admins with roles
- Society branding (logo, contact person, email, phone)

### 🔒 Security Features
- **Geofencing** — Guards can only login within a configurable radius
- **Biometric login** — Fingerprint/Face ID via WebAuthn API
- **FLAG_SECURE** — Screenshot prevention on native Android app
- **Comprehensive audit logging** — all logins (success/fail), password changes, logouts
- **Device & IP tracking** — browser, OS, screen resolution, IP address captured
- **reCAPTCHA Enterprise** — optional bot protection on selected Edge Function flows when Google / Firebase assessment is configured

### 🎨 UI/UX
- **Dual theme**: Light / Dark / System auto-detect
- **Bilingual**: English 🇬🇧 & Hindi 🇮🇳 with instant toggle
- **Mobile-first**: Optimized for guard phones with bottom navigation

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, TypeScript, Vite |
| Routing | React Router |
| Data fetching | TanStack Query (React Query) |
| Styling | Tailwind CSS, CSS variables (HSL tokens) |
| State | Zustand |
| Backend | **Supabase** — Postgres, Row Level Security, Realtime, Storage, Edge Functions |
| Auth (app) | Society-scoped credentials in Supabase tables (guards, admins, residents, super admins); **Firebase Auth** optional for **SMS / phone OTP** resident flows when `VITE_FIREBASE_*` is set |
| Push | **FCM** (web tokens + HTTP v1 from Edge Functions) with **OneSignal** as alternate web registration / REST fallback |
| UI | shadcn/ui (Radix), Lucide icons |
| PDF (finance period report) | jsPDF |
| Alerts | SweetAlert2, Sonner |
| i18n | Custom context-based translation (English / Hindi) |
| Native | Capacitor (Android / iOS) |
| Biometric | WebAuthn / FIDO2 |
| Scheduling | pg_cron + pg_net (e.g. maintenance reminders) |

## 📱 Capacitor Setup (Native Android/iOS App)

### Prerequisites
- Node.js 18+
- Android Studio (for Android)
- Xcode (for iOS, Mac only)

### Step-by-Step Setup

```bash
# 1. Export project to GitHub and clone it
git clone <your-github-repo-url>
cd society-guard-buddy

# 2. Install dependencies
npm install

# 3. Add native platforms
npx cap add android
npx cap add ios

# 4. Build the web app
npm run build

# 5. Sync web assets to native projects
npx cap sync

# 6. Run on Android emulator or device
npx cap run android

# 7. Run on iOS simulator or device (Mac only)
npx cap run ios
```

### Enable FLAG_SECURE (Screenshot Prevention - Android)

After running `npx cap add android`, edit the file:
`android/app/src/main/java/.../MainActivity.java`

```java
import android.os.Bundle;
import android.view.WindowManager;

public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Prevent screenshots and screen recording
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        );
    }
}
```

### Hot Reload During Development

The `capacitor.config.ts` is pre-configured with the live preview URL for hot reload. When building for production:

1. Remove or comment out the `server.url` in `capacitor.config.ts`
2. Run `npm run build && npx cap sync`
3. The app will use the locally bundled files

### Updating After Code Changes

```bash
# Pull latest changes
git pull

# Rebuild and sync
npm run build
npx cap sync

# Run on device
npx cap run android  # or ios
```

## 🗄 Database Schema

### Core Tables
- **societies** — Multi-society management with branding
- **super_admins** — Super admin credentials
- **admins** — Admin credentials with society & role links
- **society_roles** — Custom RBAC roles per society
- **guards** — Guard credentials and IDs
- **guard_shifts** — Login/logout timestamps per shift

### Visitor & Entry
- **visitors** — Complete visitor entry records
- **resident_vehicles** — Registered resident vehicles
- **approval_requests** — Guard → Resident approval flow (real-time)
- **visitor_passes** — OTP-based pre-approved visitor passes

### Residents & Flats
- **flats** — Flat details (number, wing, floor, owner)
- **members** — Family members linked to flats
- **resident_users** — Resident login credentials linked to flats
- **blacklist** — Flagged visitors and vehicles

### Finance
- **maintenance_charges** — Recurring maintenance fee definitions
- **maintenance_payments** — Payment records with verification workflow (optional `finance_entry_id` link to ledger)
- **finance_entries** — Ledger rows (record mode, destination, amounts, payment method/status, separate-entry expenses)
- **finance_entry_allocations** — Per-flat amounts on a ledger entry
- **finance_entry_counterparties** — Outsider / counterparty on an entry
- **finance_reminder_settings** — Society-level auto-reminder on/off and schedule
- **donation_campaigns** — Fundraising campaigns with targets
- **donation_payments** — Individual donation contributions
- **expense_groups** — Splitwise-style expense groups
- **expenses** — Individual expense records
- **expense_splits** — Per-flat split amounts with settlement tracking

### Community
- **events** — Society events with dates, locations, contributions
- **event_rsvps** — RSVP tracking per event
- **event_contributions** — Event payment contributions
- **polls** — Community polls/voting
- **poll_options** — Poll answer options
- **poll_votes** — Individual votes cast
- **meetings**, **meeting_attendees**, **meeting_decisions**, **meeting_documents** — Society meetings, attendance, decisions, attachments (see migrations)

### Notifications & Security
- **notifications** — In-app notifications with targeting; optional **`delivery_batch_id`** (same UUID across a per-resident batch) and **`read_at`** (first open in app)
- **fcm_web_tokens** — FCM web push tokens per user / society (when Firebase web push is enabled)
- **parking_spaces** — Parking allocation management
- **geofence_settings** — GPS-based login boundary
- **biometric_credentials** — WebAuthn credential storage
- **audit_logs** — Comprehensive security audit trail
- **password_reset_tokens** — Email-based password reset flow

### Automated Jobs
- **Daily 9 AM** — `maintenance-reminder` cron checks for unpaid dues and sends push + in-app reminders to affected flats

## 🚀 Getting Started

### Local Development

```bash
npm install
cp .env.example .env   # Windows: copy .env.example .env
npm run dev            # Vite dev server
npm run test           # Vitest (once)
npm run lint
npm run build          # production bundle
```

See **Configuration** below for required environment variables.

### Supabase migrations (recent capabilities)

Apply all pending files under `supabase/migrations/` to your project (CLI **db push** / linked remote, or SQL editor). Notable additions:

| Migration (prefix) | Purpose |
|--------------------|--------|
| `20260503100000` | Finance ledger (`finance_entries`, allocations, counterparties) |
| `20260502154500` | Finance auto-reminder settings |
| `20260510180000` + `20260510200000` | Meetings module + executives present |
| `20260511120000` | Notifications `delivery_batch_id`, `read_at` |
| `20260512100000` | RBAC: set `permissions.finance` true on existing `society_roles` |

Storage bucket **`notification-media`** is used for alert attachments and finance report PDFs (`finance-reports/{societyId}/{batchId}.pdf`).

**Main code touchpoints:** `src/components/FinanceManager.tsx` (period tab, PDF download, send, read-receipt dialog), `src/lib/financePeriodReportPdf.ts`, `src/components/NotificationCenter.tsx` (marks `read_at` when read), `src/lib/adminPermissions.ts` (default `finance` for new custom roles), `src/pages/AdminDashboard.tsx` (passes admin into Finance), Edge Function `supabase/functions/send-push-notification`.

### Configuration

Copy [`.env.example`](.env.example) to `.env` and fill in values.

| Area | What to set |
|------|------------------|
| Supabase | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` |
| Firebase (optional) | `VITE_FIREBASE_*` — phone sign-in, Analytics, reCAPTCHA config; `VITE_FIREBASE_VAPID_KEY` for **FCM web push** |
| reCAPTCHA Enterprise | `VITE_RECAPTCHA_ENTERPRISE_SITE_KEY` (and matching Supabase Edge Function secrets per `.env.example`) |
| Push (server) | Supabase secret `FIREBASE_SERVICE_ACCOUNT_JSON` for FCM sends, or `ONESIGNAL_REST_API_KEY` for OneSignal-only |

Edge Function secrets (Resend, PhonePe, etc.) are documented in `.env.example` and the Supabase dashboard.

### Demo Logins

**Super Admin:**
```
Username: SUPERADMIN
Password: Hello#123
```

After migration, first login walks through Microsoft Authenticator (TOTP) setup, then recovery email. Email recovery needs Edge Function secrets `RESEND_API_KEY` (and optional `RESEND_FROM`), or local dev `ALLOW_SUPERADMIN_RECOVERY_DEV_CODE=true`.

**Admin:**
```
Admin ID: ADMIN
Password: admin123
```

**Guard:**
```
Guard ID: G001
Password: guard123
```

**Resident:**
```
Phone: 9876543210
Password: resident123
```

### Push Notification Setup
1. Configure **FCM** (`VITE_FIREBASE_VAPID_KEY` + service account on the Edge Function) and/or **OneSignal** per `.env.example`.
2. Sign in as any user type; the app registers for push where configured.
3. Allow notification permission in the browser when prompted.
4. Admins can send targeted notifications from the **Notify** tab; finance period reports use the same Edge Function with `target_type: user` and resident ids. Residents receive items under **Alerts**; opening an alert records **`read_at`** for read-receipt flows.
5. Use in-app diagnostics if delivery fails.

### Biometric Setup
1. Login with password first
2. Go to Settings/Biometric tab
3. Tap "Enable Fingerprint Login"
4. Use your device's fingerprint sensor
5. Next time, use the fingerprint button on the login screen

### Going to Production
1. Navigate to **Settings** (⚙️ tab)
2. Click **"Clear All Data & Go Production"**
3. All dummy data will be permanently removed
4. Start entering real visitor and resident data

## 🗺 Roadmap

Planned **V2** themes (RBAC editor, guard-friendly voice flows, optional AI) are described in [`docs/PRODUCT-V2.md`](docs/PRODUCT-V2.md).

## 📝 Changelog

Release notes and migration-oriented summaries live in [`CHANGELOG.md`](CHANGELOG.md).

## 📄 License

Copyright © 2026. Developed by **MCSPL** with ❤️
