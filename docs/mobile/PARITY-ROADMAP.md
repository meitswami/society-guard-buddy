# Mobile ↔ Web parity roadmap

## Done (this milestone)

- Unified login: society + role + password (resident, guard, admin)
- **Firebase OTP login** (resident + guard) on web/Android/iOS via `firebase_auth`
- Session restore from `sgb_app_session_v1` (same key as web)
- Resident shell: home, alerts, approvals, passes, directory, **payments**, profile
- Real Supabase data: notifications, approval requests, visitor passes, maintenance payments
- Resident more menu: **family members**, **vehicles**, **feedback**, **polls**, **elections** (nomination + ranked voting), **meetings**, **committee**
- **OTP first-time resident onboarding** (primary setup + household member linking)
- Guard shell: dashboard, visitor entry, visitors, **more** (quick entry, delivery/service, blacklist, emergency, pass OTP verify, **settings**)
- Guard: **geofence on login**, **visitor entry photos**
- Resident: **election self-nomination**, **ranked ballots**, **feedback photo/voice attachments**, **emergency alert**
- Admin: overview, **broadcast notifications**, **residents/guards CRUD**, **flats & members**, **bulk flat generation**, **polls hub** (elections + general polls CRUD), **finance** (pending maintenance payment verify/reject)
- **FCM push**: token registration; foreground local notifications on Android/iOS
- **Native FCM scaffolding** + setup doc
- **Biometric**: app lock, fingerprint login, enrollment prompt, device management
- Dynamic branding from `platform_branding`

## Next (high priority)

1. Drop real `google-services.json` / `GoogleService-Info.plist` + APNs key (see [FIREBASE-NATIVE-SETUP.md](./FIREBASE-NATIVE-SETUP.md))
2. Full finance ledger on mobile (receipts, splits, donations — web `FinanceManager`)
3. WebAuthn passkeys cross-device sync (web `biometric_credentials` vs native secure enclave)

## Web-only for now

- Superadmin console (desktop-first)
- Society signup / PhonePe
- Public legal pages
