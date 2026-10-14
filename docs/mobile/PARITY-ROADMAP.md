# Mobile ↔ Web parity

The Flutter app (`mobile/`) is a full native port of the web app (`src/`). Both use the same Supabase tables,
storage buckets and Edge Functions. The web app is unchanged and stays the reference for design and behaviour.

## Ported (all roles)

| Area | Web source | Flutter |
|---|---|---|
| Unified login: society picker (retry/backoff), password, Firebase OTP, first-time resident onboarding, guard geofence, password reset, fingerprint quick login | `UnifiedLoginPage`, `OTPLoginFlow`, `SocietyLoginGate` | `features/auth/` |
| Public pages: privacy, terms, contact, delete account, about, society signup + PhonePe status | `src/pages/*` | `features/public/` (routes `/privacy`, `/terms`, …) |
| Guard shell: home, duty, visitor entry + resident approval, delivery, quick entry, vehicles, blacklist, directory, alerts, settings, tour | `GuardDashboard`, `pages/guard/*` | `features/guard/`, `features/gate/` |
| AI receptionist kiosk (face framing → Hindi/Hinglish/English voice check-in) | `KioskPage`, `lib/kiosk/*` | `features/kiosk/` (ML Kit face detection, native speech/TTS) |
| Resident shell: approvals, passes, family, vehicles, payments + receipts/statements, profile/360°, feedback, directory, alerts, meetings, documents, committee, polls/elections | `ResidentDashboard` | `features/resident/`, `features/governance/` |
| Admin shell: overview, module drawer, global search, quick access | `AdminPage`, `adminNavigation.ts` | `features/admin/admin_shell.dart` |
| Admin finance (receipt/payment types, record receipt, transactions, totals, reminders, receipts PDF) | `FinanceManager` | `features/admin/finance/` |
| Audit log, finance alarms, self-audit, bank reconciliation, manual tracer, governance guide | `AuditLogs`, `audit/*` | `features/admin/audit/` |
| Fixed assets register + exports | `FixedAssets*` | `features/admin/fixed_assets/` |
| Reports (financial, flat-wise, cash flow, custom reports, send to members) and visitor logs | `Reports*`, `customReports/*` | `features/admin/reports/`, `shared/pdf/` |
| Events & food, expense splitter, reconciliation, donations | `EventsManager`, `ExpenseSplitter`, `Donations*` | `features/admin/events/` |
| Meetings, documents, committee, polls/elections (admin + resident) | `Meetings*`, `Documents*`, `Committee*`, `Polls*` | `features/governance/` |
| Residents, guards, directory, parking, flat 360° | `ResidentsManager`, `GuardsManager`, `Directory*` | `features/admin/people/`, `features/shared/directory/` |
| Notifications (compose, sounds, attachments, push health), settings panels, geofence, password, biometric, emergency, tour guide | `Notifications*`, `Settings*`, `TourGuide*` | `features/comms/` |
| Superadmin console (TOTP login, societies, roles + permission matrix, admins, backups, payments, settings, support tickets) | `SuperadminDashboard` | `features/superadmin/` |

## Deliberate differences

- **Biometrics:** the web uses WebAuthn passkeys. The app uses the phone's fingerprint/face unlock, enrolled per device (max 3, as on the web).
- **Speech:** the kiosk uses Android's native recogniser and TTS instead of the browser Web Speech API.
- **Download:** "Download" opens the share sheet (save to Files, WhatsApp, Drive, print).
- **Video attachments** open in the phone's player.
- **Fixed web bugs, not copied:**
  - A tenant's vehicle in the admin member form is now saved; the web drops it and deletes the linked row.
  - Signup upper-cases the admin ID so it can log in.
  - Resident audit rows record the right role and method.
  - Two-digit years in bank CSVs are parsed correctly.
  - The All-modules Excel export no longer crashes on duplicate sheet names.
  - Totals shows the "Other" channel value instead of a literal `₹{…}`.
- **Web quirks kept so both apps show the same numbers:** the operating-fund month table maps a "June" title to May. Fix it in both clients together if wanted.
- **Hindi in PDFs:** the PDF engine does not shape Devanagari, so conjuncts can render imperfectly. Report labels are English, as on the web.

## Still to do

1. Device testing on real Android phones: camera, kiosk voice, OTP, push, and uploads against production Supabase.
2. `google-services.json` for the Play package name (see [PLAY-STORE-RELEASE.md](./PLAY-STORE-RELEASE.md)).
3. iOS build (Xcode on macOS, APNs key, `GoogleService-Info.plist`).
