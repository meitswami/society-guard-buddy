# 🏢 Evergreen Heights — Society Management System

A comprehensive, mobile-first society gate management application built for security guards and residents to manage visitor entries, approvals, vehicle tracking, resident directories, and daily reporting.

## ✨ Features

### 🔐 Multi-Tier Authentication
- **Guard login** with ID & password — shift tracking with timestamps
- **Resident login** with phone & password — manage approvals & visitor passes
- **Admin login** with ID & password — full society management
- **Super Admin login** — multi-society management
- **Biometric login** — fingerprint/face unlock for quick access (all user types)
- Role-based dashboards for each tier

### 👤 Visitor Management
- Full visitor registration (name, phone, document, photos)
- Auto-fill from previous visits (phone-based lookup)
- Repeat visitor alerts & blacklist checking on entry
- Vehicle tracking per visit
- Quick re-entry for frequent visitors (2+ visits)

### ✅ Resident Approval System
- Guard sends **real-time approval request** to resident's dashboard
- Resident receives **sound notification** for pending approvals
- One-tap **Approve / Reject** with 2-minute timeout
- Full approval history for residents

### 🔑 OTP Visitor Pass System
- Residents (or guards) generate **6-digit OTP passes** for expected guests
- Passes include **date + time slot** restrictions
- Guard verifies OTP at the gate — auto-registers the visitor if valid

### 🚗 Vehicle Registry
- Resident vehicle registration linked to flats
- Vehicle type categorization (car, bike, delivery, other)

### 📦 Delivery & Service Entry
- Quick logging for delivery partners (Amazon, Flipkart, Swiggy, etc.)
- Service staff tracking (electrician, plumber, etc.)

### 🏠 Flat & Member Directory
- Complete flat registry with wing, floor, and owner details
- Member profiles with relation, age, gender

### 🚫 Blacklist Management
- Flag visitors by phone number or vehicles by registration
- Real-time blacklist alerts during entry

### 📊 Daily Reports
- Date-wise visitor statistics
- Guard shift logs
- CSV export & print-ready HTML reports

### 🛡️ Admin Features
- Manage guards (add/delete/reset passwords)
- Manage residents (add/edit/delete)
- Geofence setup for guard login boundary
- Admin password change
- Biometric setup
- Full access to all modules (reports, logs, etc.)

### 👑 Super Admin Features
- Create & manage multiple societies
- Define custom RBAC roles (President, Secretary, Treasurer, etc.)
- Appoint society-specific admins with roles
- Society branding (logo, contact person, email, phone)

### 🔒 Security Features
- **Geofencing** — Guards can only login within a configurable radius
- **Biometric login** — Fingerprint/Face ID via WebAuthn API
- **FLAG_SECURE** — Screenshot prevention on native Android app

### 🎨 UI/UX
- **Dual theme**: Light / Dark / System auto-detect
- **Bilingual**: English 🇬🇧 & Hindi 🇮🇳 with instant toggle
- **Mobile-first**: Optimized for guard phones with bottom navigation

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, TypeScript, Vite |
| Styling | Tailwind CSS, CSS variables (HSL tokens) |
| State | Zustand |
| Backend | Lovable Cloud (real-time subscriptions) |
| UI Components | shadcn/ui, Lucide icons |
| Alerts | SweetAlert2 |
| i18n | Custom context-based translation system |
| Native | Capacitor (Android/iOS) |
| Biometric | WebAuthn / FIDO2 API |

## 📱 Capacitor Setup (Native Android/iOS App)

### Prerequisites
- Node.js 18+
- Android Studio (for Android)
- Xcode (for iOS, Mac only)

### Step-by-Step Setup

```bash
# 1. Export project to GitHub and clone it
git clone <your-github-repo-url>
cd society-guard-buddy

# 2. Install dependencies
npm install

# 3. Add native platforms
npx cap add android
npx cap add ios

# 4. Build the web app
npm run build

# 5. Sync web assets to native projects
npx cap sync

# 6. Run on Android emulator or device
npx cap run android

# 7. Run on iOS simulator or device (Mac only)
npx cap run ios
```

### Enable FLAG_SECURE (Screenshot Prevention - Android)

After running `npx cap add android`, edit the file:
`android/app/src/main/java/.../MainActivity.java`

```java
import android.os.Bundle;
import android.view.WindowManager;

public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Prevent screenshots and screen recording
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        );
    }
}
```

### Hot Reload During Development

The `capacitor.config.ts` is pre-configured with the live preview URL for hot reload. When building for production:

1. Remove or comment out the `server.url` in `capacitor.config.ts`
2. Run `npm run build && npx cap sync`
3. The app will use the locally bundled files

### Updating After Code Changes

```bash
# Pull latest changes
git pull

# Rebuild and sync
npm run build
npx cap sync

# Run on device
npx cap run android  # or ios
```

## 🗄 Database Schema

- **societies** — Multi-society management with branding
- **super_admins** — Super admin credentials
- **admins** — Admin credentials with society & role links
- **society_roles** — Custom RBAC roles per society
- **guards** — Guard credentials and IDs
- **guard_shifts** — Login/logout timestamps per shift
- **visitors** — Complete visitor entry records
- **resident_vehicles** — Registered resident vehicles
- **flats** — Flat details (number, wing, floor, owner)
- **members** — Family members linked to flats
- **blacklist** — Flagged visitors and vehicles
- **resident_users** — Resident login credentials linked to flats
- **approval_requests** — Guard → Resident approval flow (real-time)
- **visitor_passes** — OTP-based pre-approved visitor passes
- **geofence_settings** — GPS-based login boundary
- **biometric_credentials** — WebAuthn credential storage

## 🚀 Getting Started

### Demo Logins

**Super Admin:**
```
Username: SUPERADMIN
Password: super123
```

**Admin:**
```
Admin ID: ADMIN
Password: admin123
```

**Guard:**
```
Guard ID: G001
Password: guard123
```

**Resident:**
```
Phone: 9876543210
Password: resident123
```

### Biometric Setup
1. Login with password first
2. Go to Settings/Biometric tab
3. Tap "Enable Fingerprint Login"
4. Use your device's fingerprint sensor
5. Next time, use the fingerprint button on the login screen

### Going to Production
1. Navigate to **Settings** (⚙️ tab)
2. Click **"Clear All Data & Go Production"**
3. All dummy data will be permanently removed
4. Start entering real visitor and resident data

## 📄 License

Copyright © 2026. Developed by **MCSPL** with ❤️
