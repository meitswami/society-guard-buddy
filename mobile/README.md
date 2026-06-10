# Kutumbika Mobile (Flutter)

Native **Android & iOS** app for Kutumbika. The existing **web app stays unchanged** in the repo root (`src/`, Vite, React).

## Architecture

| Layer | Path | Notes |
|-------|------|-------|
| Web (unchanged) | `/` | React + Vite + Capacitor WebView option |
| Mobile (new) | `/mobile` | Flutter + `supabase_flutter` |

Both clients talk to the **same Supabase backend** (PostgREST + Edge Functions). There is no separate REST API server.

## First-time setup

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.5+).
2. From this folder:

```bash
cd mobile
flutter create . --project-name kutumbika_mobile --org app.kutumbika
cp .env.example .env
# Fill SUPABASE_URL and SUPABASE_ANON_KEY (same as web VITE_SUPABASE_*)
flutter pub get
flutter run
```

3. Generate platform folders if missing:

```bash
flutter create . --project-name kutumbika_mobile --org app.kutumbika
```

## What's built so far

- Kutumbika orange theme matching the resident home mockup
- Resident home screen (header, 3×2 quick actions, announcements, promo banner, bottom nav + FAB)
- Society gate screen (loads `societies` from Supabase)
- `NotificationService` — reads `notifications` table with resident targeting rules from web
- Session helper mirroring web `appSession.ts`

## Next milestones

1. Resident / guard / admin login flows (Firebase OTP + password)
2. Wire quick-action badges to real counts (`approval_requests`, `events`, `support_tickets`)
3. Firebase Cloud Messaging for push
4. Geofence for guard login (`geolocator`)
5. CI: `flutter build apk` / `flutter build ipa`

## API reference

See [docs/mobile/API-STRATEGY.md](../docs/mobile/API-STRATEGY.md) for the full backend surface and Flutter porting notes.
