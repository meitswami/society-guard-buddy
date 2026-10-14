# Push notifications (guard → resident visitor approvals and everything else)

## How it works
Kutumbika uses **Firebase Cloud Messaging (FCM)**. It is free with no message limit, delivers instantly, and is what
Android uses underneath every push service, OneSignal included. OneSignal is not needed:
`send-push-notification` only falls back to it when `FIREBASE_SERVICE_ACCOUNT_JSON` is missing.

| Event | How the resident is alerted |
|---|---|
| Guard / AI kiosk asks to let a visitor in | **Database trigger** `approval_requests_push` → `send-push-notification` with `kind: visitor_approval`. On Android this goes out at high priority on the **"Visitor at gate"** channel with the doorbell sound (`res/raw/visitor_bell.wav`). It works whichever app created the request (web, Android, kiosk), and also when the resident's app is closed or the phone is locked. If the app is open, the Approvals tab rings and shows the card at once (realtime). |
| Admin notices, bills, reminders, events, meetings, emergency | Each feature calls `send-push-notification` (high priority, "Kutumbika alerts" channel). The society's custom alert sound plays while the app is open. |

Before this change, visitor approvals reached residents only while their app was open. There was no push.

## One-time setup (cloud Supabase, today)
1. **Database trigger**: Supabase dashboard → SQL editor → run
   `supabase/migrations/20261014120000_visitor_approval_push.sql`, or `supabase db push`.
2. **Edge Function**: deploy the updated function with `supabase functions deploy send-push-notification`.
   Check that the secret `FIREBASE_SERVICE_ACCOUNT_JSON` is set (Edge Functions → Secrets).
3. **Android app**: the build must include `google-services.json` for the Play package name:
   - Firebase console → project `kutumbika-5ce7d` → Add app → Android → `app.kutumbikaparivaarjaisi.android`.
   - Download `google-services.json`, open it in Notepad, copy everything and save it as the GitHub secret `GOOGLE_SERVICES_JSON` (base64 also works). Set the GitHub variable `ANDROID_APPLICATION_ID` to `app.kutumbikaparivaarjaisi.android`.
   - Without this file the app cannot get a push token. It then logs "Firebase did not start" in Admin → Notifications → Push health check.

## Test
1. Install the new APK and log in as a resident. Allow notifications when asked. Then close the app.
2. On another phone, or the web, log in as a guard and add a visitor for that flat with **Request approval**.
3. The resident's phone rings with the doorbell sound within a few seconds and shows "Visitor at the gate · गेट पर आगंतुक".
4. Admin → Notifications → **Push health check** shows the token and a test push for the admin's own device.

If the sound is the default one: Android fixes a channel's sound when it is first created. Uninstall and reinstall
the app once.

## After moving to the self-hosted Supabase
`deploy/supabase/post-import.sql` points the trigger at the new Edge Functions URL (`app_runtime_config`). Put
`FIREBASE_SERVICE_ACCOUNT_JSON` in the VPS `functions.env`.
