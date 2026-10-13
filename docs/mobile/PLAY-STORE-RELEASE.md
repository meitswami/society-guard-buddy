# Publishing the Flutter app on Google Play (replacing the AppMySite app)

The Flutter app in `mobile/` replaces the AppMySite PWA wrapper. It talks to the same Supabase backend as the web app.
GitHub Actions (`.github/workflows/android.yml`) builds a signed APK and a Play App Bundle (AAB) on every push that touches `mobile/`.

## A. Replace the existing listing (keep installs, ratings, reviews)
To update an existing Play listing in place, the new app must match it in two ways:

1. **Same package name.** The live listing is `app.kutumbikaparivaarjaisi.android` (https://play.google.com/store/apps/details?id=app.kutumbikaparivaarjaisi.android).
   Set it in GitHub → Settings → Variables → `ANDROID_APPLICATION_ID`. The build uses it as `applicationId`; the code package stays `app.kutumbika.kutumbika_mobile`, which is fine.
2. **A key Google accepts.** Check *Play Console → Setup → App signing*:
   - **Play App Signing is on** (normal since 2021). Google holds the app signing key and you only need an *upload key*.
     If AppMySite gave you the upload keystore, use it. If not, click **Request upload key reset**, upload the certificate of a new keystore (below), and wait about 2 days for Google to approve.
   - **Play App Signing is off.** You need the original keystore from AppMySite. Ask their support for the `.jks` and passwords.
3. **Higher version code.** Find the current versionCode under *Release → Production → release details*.
   Set the GitHub variable `ANDROID_VERSION_CODE_BASE` higher than it (e.g. current 12 → base 100). CI uses `base + run number`.

If you would rather start a **new listing**, leave `ANDROID_APPLICATION_ID` unset (default `app.kutumbika.kutumbika_mobile`) and create a new app in Play Console.

## B. Create the upload keystore (once)
```bash
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
keytool -export -rfc -keystore upload-keystore.jks -alias upload -file upload_certificate.pem   # for "upload key reset"
base64 -w0 upload-keystore.jks > upload-keystore.b64
```
GitHub secrets: `ANDROID_KEYSTORE_BASE64` (contents of `.b64`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), `ANDROID_KEY_PASSWORD`.
Store the `.jks` and passwords somewhere safe. Losing them means another key reset.

## C. Firebase (phone OTP login + push notifications)
1. Firebase console → project `kutumbika-5ce7d` → *Add app → Android*. Use the **same package name** as `ANDROID_APPLICATION_ID`.
2. Add the SHA-1 and SHA-256 fingerprints:
   - of your upload key: `keytool -list -v -keystore upload-keystore.jks -alias upload`
   - **and** of Google's app signing key: Play Console → *Setup → App signing* → "App signing key certificate". Phone auth on Play-installed builds needs this one.
3. Download `google-services.json`, run `base64 -w0 google-services.json`, and save the output as the GitHub secret `GOOGLE_SERVICES_JSON`.
4. Optional: put the full `mobile/.env` in the `APP_ENV` secret. Otherwise CI uses `mobile/.env.example`, which holds the public Supabase and Firebase web keys.

## D. Build and publish
- Every push to `mobile/` → Actions → **Android app (Flutter)** → download the `kutumbika-android-…` artifact (APK for testing on a phone, AAB for Play).
- Manual: *Run workflow* with **publish = true**. This uploads the AAB to the **internal testing** track and needs the `PLAY_SERVICE_ACCOUNT_JSON` secret.
  To create that account: Play Console → *Setup → API access* → link a Google Cloud project, create a service account, and grant it *Release manager* on the app.
- Then promote internal → closed/open testing → production in Play Console.

## E. Store listing checklist
- App icon 512×512: `mobile/store/play_icon_512.png` (same building photo as the web app's icon).
- Privacy policy URL: `<web domain>/privacy`. Account deletion URL (Play *Data safety* requirement): `<web domain>/delete-account`.
- Permissions to declare in the Data safety form:
  - Camera: visitor photos, AI kiosk.
  - Microphone: AI kiosk speech, voice notes.
  - Location: guard geofence.
  - Notifications.
  - Biometric: app lock.
- Target audience: adults (society residents/staff). Contains no ads.

## F. Local build (optional, needs Android Studio / SDK)
```bash
cd mobile
cp .env.example .env
flutter pub get
flutter build apk --release            # debug-signed unless android/key.properties exists
flutter build appbundle --release -PappId=com.your.package
```
