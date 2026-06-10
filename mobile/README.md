# Kutumbika Mobile (Flutter)

Native **Android & iOS** hybrid apps for Kutumbika. The existing **web app stays unchanged** in the repo root (`src/`, Vite, React).

## Architecture

| Layer | Path | Notes |
|-------|------|-------|
| Web (unchanged) | `/` | React + Vite + Capacitor WebView option |
| Mobile (new) | `/mobile` | Flutter + `supabase_flutter` |

Both clients talk to the **same Supabase backend** (PostgREST + Edge Functions). Branding (logo + colors) is managed from **Superadmin → Settings → Mobile app branding** and stored in `platform_branding`. Society logos upload from **Superadmin → Societies**.

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

3. Apply the `platform_branding` migration on Supabase before testing dynamic logo/colors:

```bash
# from repo root, with Supabase CLI linked
supabase db push
```

## Build for stores

```bash
# Android APK / App Bundle
flutter build apk --release
flutter build appbundle --release

# iOS (macOS + Xcode required)
flutter build ios --release
```

## What's built

- Kutumbika orange theme matching the resident home mockup (`#F58220`)
- **Dynamic branding** from `platform_branding` (logo, app name, tagline, primary/background colors)
- Resident home screen (header, 3×2 quick actions, announcements, promo banner, bottom nav + FAB)
- Society gate screen with society logos from `societies.logo_url`
- `NotificationService` — reads `notifications` table with resident targeting rules from web
- Session helper mirroring web `appSession.ts`

## Superadmin branding

| Setting | Where | Used by |
|---------|-------|---------|
| App logo, colors, tagline | Settings → Mobile app branding | Flutter header, theme, splash |
| Society logo | Societies → Upload society logo | Society gate list, future login screens |

Web resident/admin UI is **not** changed by mobile branding.

## Next milestones

1. Resident / guard / admin login flows (Firebase OTP + password)
2. Wire quick-action badges to real counts
3. Firebase Cloud Messaging for push
4. Geofence for guard login (`geolocator`)
5. CI: `flutter build apk` / `flutter build ipa`

## API reference

See [docs/mobile/API-STRATEGY.md](../docs/mobile/API-STRATEGY.md).
