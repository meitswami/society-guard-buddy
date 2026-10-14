# Kutumbika Mobile (Flutter)

Native **Android** (and later **iOS**) app for Kutumbika. It replaces the AppMySite PWA wrapper on the Play Store.
The **web app stays unchanged** in the repo root (`src/`, React + Vite) and remains the reference design: the Flutter
screens copy its mobile layout, colours, copy (Hindi default + English) and behaviour.

Both clients use the **same Supabase backend**: PostgREST, Storage, Realtime and Edge Functions.

## Layout

| Path | What |
|------|------|
| `lib/core/theme/` | `AppTokens`: the web `src/index.css` design tokens (light + dark). `KutumbikaTheme` builds Material from them |
| `lib/core/i18n/` | `context.t('web.key')`, `context.tr(en, hi)`. Strings in `assets/i18n/translations.json` come from the web `translations.ts` |
| `lib/core/ui/` | UI kit mirroring the web components: `PageContainer`, `PageHeader`, `CardSection`, `AppButton`, `AppTextField` (CAPS-entry mode), `DescriptiveStatCard`, `StatusBadge`, `AppFeedback` (SweetAlert-style dialogs / toasts), `ScrollableBottomNav`, `LanguageToggle`, `ThemeToggle` |
| `lib/core/export/` | PDF (Hindi-capable fonts), Excel, CSV, share sheet, WhatsApp, print |
| `lib/core/prefs/` | Theme / language / CAPS-entry preferences (same keys as the web localStorage) |
| `lib/features/<area>/` | Role shells and feature modules: `admin/*`, `gate/` + `guard/`, `kiosk/`, `resident/`, `governance/`, `comms/`, `auth/`, `public/`, `superadmin/` |
| `lib/features/admin/core/` | `AdminTab`, `AdminModuleContext`, navigation/search/quick-access (port of `adminNavigation.ts`) and the module registry |
| `tool/sync_translations.mjs` | Regenerates `assets/i18n/translations.json` from the web strings |

## First-time setup

```bash
# Flutter 3.47.x (CI uses 3.47.5)
cd mobile
cp .env.example .env          # SUPABASE_URL, SUPABASE_ANON_KEY, FIREBASE_*, optional WEB_APP_URL
flutter pub get
flutter run
```

After changing web strings (`src/i18n/translations.ts`), run this from the repo root: `node mobile/tool/sync_translations.mjs`.

Native Firebase (phone OTP on Android, FCM push) needs `android/app/google-services.json`. See
[docs/mobile/FIREBASE-NATIVE-SETUP.md](../docs/mobile/FIREBASE-NATIVE-SETUP.md).

## Checks

```bash
flutter analyze --no-fatal-infos
flutter test
```

## Builds & release

CI (`.github/workflows/android.yml`) runs analyze, tests, a signed APK and an AAB on every push that touches `mobile/`.
A manual run can upload to the Play **internal** track. The full guide covers replacing the AppMySite listing, the
upload key, version codes, Firebase SHA fingerprints and the store listing:
**[docs/mobile/PLAY-STORE-RELEASE.md](../docs/mobile/PLAY-STORE-RELEASE.md)**.

```bash
flutter build apk --release
flutter build appbundle --release -PappId=<play package name>
flutter build ios --release      # later: macOS + Xcode
```

## Parity status

See [docs/mobile/PARITY-ROADMAP.md](../docs/mobile/PARITY-ROADMAP.md).

## API reference

See [docs/mobile/API-STRATEGY.md](../docs/mobile/API-STRATEGY.md).
