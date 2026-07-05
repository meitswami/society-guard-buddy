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

# Fill SUPABASE_URL, SUPABASE_ANON_KEY, and FIREBASE_* (same as web)

flutter pub get

flutter run

```



3. For **native push**, add Firebase platform files — see [docs/mobile/FIREBASE-NATIVE-SETUP.md](../docs/mobile/FIREBASE-NATIVE-SETUP.md).



4. Apply the `platform_branding` migration on Supabase before testing dynamic logo/colors.



## Build for stores



```bash

flutter build apk --release

flutter build appbundle --release

flutter build ios --release   # macOS + Xcode

```



## What's built



- Kutumbika orange theme + **dynamic branding** from `platform_branding`

- **Login** — society, role, password + Firebase OTP (resident/guard)

- **Session restore** — shared `sgb_app_session_v1` key with web

- **Resident** — home, alerts, approvals, passes, directory, payments, profile, family, vehicles, feedback, polls, elections, meetings, committee, emergency

- **Guard** — dashboard, entry (photos), visitors, quick entry, delivery, blacklist, emergency, pass OTP verify, settings (biometric lock)

- **Admin** — overview, broadcast, residents/guards CRUD, **flats & members**

- **FCM** — token registration; foreground notifications on native

- **Biometric** — fingerprint/Face ID app lock + quick login (`local_auth` + secure storage)



See [docs/mobile/PARITY-ROADMAP.md](../docs/mobile/PARITY-ROADMAP.md) for full parity status.



## API reference



See [docs/mobile/API-STRATEGY.md](../docs/mobile/API-STRATEGY.md).

