# Firebase native setup (Android & iOS)

The Flutter app reads Firebase web config from `mobile/.env` (`FIREBASE_*`). **Native push (FCM)** also needs platform files from the same Firebase project.

## 1. Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/) → your Kutumbika project.
2. **Project settings → General → Your apps**

### Android

1. Add app → Android  
   - Package name: `app.kutumbika.kutumbika_mobile`
2. Download **`google-services.json`**
3. Copy to:

```
mobile/android/app/google-services.json
```

The Gradle build applies the Google Services plugin only when this file exists.

### iOS (macOS + Xcode)

1. Add app → iOS  
   - Bundle ID: match `PRODUCT_BUNDLE_IDENTIFIER` in Xcode (default Flutter: `app.kutumbika.kutumbikaMobile` or similar)
2. Download **`GoogleService-Info.plist`**
3. Copy to:

```
mobile/ios/Runner/GoogleService-Info.plist
```

4. In Xcode: open `ios/Runner.xcworkspace` → drag the plist into Runner (Copy items if needed).
5. Enable **Push Notifications** capability.
6. Upload your **APNs key** (or certificate) under Firebase → Project settings → Cloud Messaging.

## 2. Environment variables

`mobile/.env` (same Firebase project as web):

```env
FIREBASE_API_KEY=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_PROJECT_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=...

# Chrome / Flutter web push only
FIREBASE_VAPID_KEY=...
```

`FIREBASE_VAPID_KEY` is the same as web `VITE_FIREBASE_VAPID_KEY` (Firebase Console → Cloud Messaging → Web configuration).

## 3. Supabase edge function

Server-side push uses `FIREBASE_SERVICE_ACCOUNT_JSON` on Supabase (see root `.env.example`). Mobile only registers tokens in `fcm_web_tokens` on login.

## 4. Verify

```bash
cd mobile
flutter pub get
flutter run   # device or emulator
```

After login, check `fcm_web_tokens` for a new row with your device token.

**Foreground alerts:** Android/iOS show a local notification when a push arrives while the app is open (`flutter_local_notifications`).

## 5. Do not commit secrets

These files are gitignored:

- `mobile/android/app/google-services.json`
- `mobile/ios/Runner/GoogleService-Info.plist`

Use `mobile/android/app/google-services.json.example` as a structural reference only.
