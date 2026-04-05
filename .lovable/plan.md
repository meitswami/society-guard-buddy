## Phase 1: Database Schema Changes
- Add `guard_documents` table (guard_id, doc_type, front_url, back_url, label)
- Add columns to `guards` table: `auth_mode` (password/otp), `police_verification` (done/pending), `police_verification_date`, `kyc_alert_days`
- Create storage bucket `guard-documents` for ID uploads

## Phase 2: Firebase Phone OTP Integration
- Add Firebase SDK dependency
- Request `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID` secrets
- Create OTP login component with phone number input → OTP verification
- Support WhatsApp delivery option via Firebase
- Add WebOTP API integration for auto-fetch on mobile
- Resident login: phone lookup in `resident_users` → send OTP → verify → login
- No registration option on login page (admin creates users first)

## Phase 3: Guard Management Enhancements (Admin Dashboard)
- Add guard identity document upload (front/back, multiple IDs)
- Add police verification dropdown (Done/Pending) with date
- Add configurable KYC alert days field
- Show KYC pending alerts on admin dashboard

## Phase 4: Guard Auth Mode
- Per-guard toggle: Password or OTP login
- Guard login page adapts based on `auth_mode` setting
- If OTP: use Firebase phone OTP for guard's registered phone

## Files to create/edit:
- `src/components/FirebaseOTPLogin.tsx` (new)
- `src/lib/firebase.ts` (new) 
- `src/components/AdminGuardManager.tsx` (edit - add docs, KYC, auth mode)
- `src/pages/AdminDashboard.tsx` (edit - KYC alerts widget)
- `src/pages/UnifiedLoginPage.tsx` (edit - OTP flow for residents)
- `src/pages/LoginPage.tsx` (edit - OTP support for guards)
- DB migration for new columns and table
