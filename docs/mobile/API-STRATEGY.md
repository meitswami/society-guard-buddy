# Mobile API Strategy — Kutumbika

## Summary

**Yes — the project has a full backend**, but it is **Supabase-native**, not a traditional REST API layer.

| API type | Available? | Used by web? | Flutter-ready? |
|----------|-------------|--------------|----------------|
| **PostgREST** (table CRUD) | ✅ 50+ tables | ✅ Primary | ✅ via `supabase_flutter` |
| **Edge Functions** | ✅ 13 functions | ✅ Partial | ✅ via `functions.invoke` |
| **Storage** | ✅ 4 buckets | ✅ | ✅ |
| **Realtime** | ✅ | ✅ Notifications, approvals | ✅ |
| **GraphQL** | ⚠️ Enabled in DB | ❌ Not used | Optional |
| **Dedicated REST/BFF** | ❌ | — | Would need to be built |
| **Supabase Auth** | ⚠️ Configured | ❌ Custom table auth | Must reimplement |

## Backend surface

### PostgREST tables (examples)

- Auth: `guards`, `resident_users`, `admins`, `super_admins`, `society_roles`
- Society: `societies`, `flats`, `members`
- Branding: `platform_branding` (Flutter logo + colors; Superadmin Settings)
- Gate: `visitors`, `approval_requests`, `visitor_passes`, `blacklist`
- Finance: `maintenance_payments`, `finance_entries`, `expense_groups`
- Governance: `meetings`, `polls`, `committee_members`, `notifications`
- Full list: `src/integrations/supabase/types.ts`

### Edge functions (`supabase/functions/`)

| Function | Purpose |
|----------|---------|
| `send-push-notification` | FCM / OneSignal |
| `send-emergency-alert` | Push + WhatsApp |
| `send-otp` / `verify-otp` | OTP store (web uses Firebase instead) |
| `recaptcha-assessment` | Phone auth abuse protection |
| `phonepe-init-order` / `phonepe-poll-status` / `phonepe-callback` | Society signup payments |
| `maintenance-reminder` | Finance reminders |
| `backup-export` | Superadmin backup |
| `superadmin-recovery-send` / `verify` | TOTP recovery |
| `send-feedback-alert` | Support tickets |

### External services

- **Firebase Auth** — resident/guard OTP (web client SDK)
- **FCM / OneSignal** — push notifications
- **PhonePe** — payments (edge functions)
- **WhatsApp Graph API** — emergency alerts

## How web talks to the backend

1. Single client: `src/integrations/supabase/client.ts`
2. Custom session in `localStorage` (`src/lib/appSession.ts`) — **not** Supabase Auth JWT
3. Queries scattered across `src/lib/*` and page components
4. Society scoping via client-side `society_id` filters (RLS is mostly permissive)

## Flutter approach (hybrid)

```
┌─────────────────┐     ┌─────────────────┐
│  React Web      │     │  Flutter Mobile │
│  (unchanged)    │     │  (new /mobile)  │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
         ┌───────────────────────┐
         │  Supabase             │
         │  PostgREST + Storage  │
         │  + Edge Functions     │
         └───────────────────────┘
```

### Port order (recommended)

1. **Theme + resident home** ✅ dynamic branding from `platform_branding` + society logos
2. Society gate + session (`societiesLogin.ts`, `appSession.ts`)
3. Resident login (phone/password + Firebase OTP)
4. Notifications, visitors, maintenance modules
5. Guard + admin apps (separate entry or role-based shell)
6. Push (FCM Flutter SDK)
7. **Security hardening** — tighten RLS, server-side password verify (before production)

## Gaps to fix before production mobile

| Gap | Risk | Fix |
|-----|------|-----|
| Permissive RLS + anon key in app | High | Society-scoped RLS policies |
| Plaintext password compare via PostgREST | High | Edge function auth or Supabase Auth migration |
| `send-reset-email` missing | Medium | Add edge function or remove web call |
| Types lag migrations | Low | Regenerate `types.ts` / Dart models |

## Env mapping (web → Flutter)

| Web (`.env`) | Flutter (`mobile/.env`) |
|--------------|-------------------------|
| `VITE_SUPABASE_URL` | `SUPABASE_URL` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | `SUPABASE_ANON_KEY` |
| `VITE_FIREBASE_*` | `FIREBASE_*` (add `firebase_core` when wiring OTP) |
