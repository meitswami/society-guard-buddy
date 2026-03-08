# 🏢 Evergreen Heights — Society Management System

A comprehensive, mobile-first society gate management application built for security guards and residents to manage visitor entries, approvals, vehicle tracking, resident directories, and daily reporting.

## ✨ Features

### 🔐 Dual Authentication
- **Guard login** with ID & password — shift tracking with timestamps
- **Resident login** with phone & password — manage approvals & visitor passes
- Role-based dashboards for guards and residents

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
- Powered by real-time database subscriptions

### 🔑 OTP Visitor Pass System
- Residents (or guards) generate **6-digit OTP passes** for expected guests
- Passes include **date + time slot** restrictions
- Guard verifies OTP at the gate — auto-registers the visitor if valid
- Pass status tracking: active → used → expired
- Copy-to-clipboard for easy sharing

### 🚗 Vehicle Registry
- Resident vehicle registration linked to flats
- Vehicle type categorization (car, bike, delivery, other)
- Search by vehicle number, flat, or resident name

### 📦 Delivery & Service Entry
- Quick logging for delivery partners (Amazon, Flipkart, Swiggy, etc.)
- Service staff tracking (electrician, plumber, etc.)
- Photo capture support

### 🏠 Flat & Member Directory
- Complete flat registry with wing, floor, and owner details
- Member profiles with relation, age, gender
- Vehicle linking per flat
- Visitor history directory with visit counts

### 🚫 Blacklist Management
- Flag visitors by phone number or vehicles by registration
- Reason tracking and guard attribution
- Real-time blacklist alerts during entry

### 📊 Daily Reports
- Date-wise visitor statistics
- Guard shift logs
- CSV export & print-ready HTML reports

### ⚙️ Settings & Data Management
- One-click clear all dummy data for production readiness
- Data summary dashboard
- Theme & language settings

### 🎨 UI/UX
- **Dual theme**: Light / Dark / System auto-detect
- **Bilingual**: English 🇬🇧 & Hindi 🇮🇳 with instant toggle
- **Mobile-first**: Optimized for guard phones with bottom navigation
- **SweetAlert2**: Beautiful confirmation dialogs for all destructive actions
- **Interactive dashboard**: Clickable stat cards filter entries, today/yesterday toggle

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

## 📱 Navigation Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | 🏠 Home | Dashboard with stats, alerts, recent entries |
| 2 | ⚡ Quick | One-tap re-entry for frequent visitors |
| 3 | 👤 Visitor | Full registration + Ask Permission + OTP Verify |
| 4 | 📦 Delivery | Delivery & service staff entry |
| 5 | 🚗 Vehicles | Resident vehicle registry |
| 6 | 🚫 Blacklist | Flagged visitors & vehicles |
| 7 | 📒 Directory | Flats, members & visitor history |
| 8 | 📊 Report | Daily reports with export |
| 9 | 📄 Logs | Searchable entry/exit records |
| 10 | ⚙️ Settings | Theme, language, data management |

## 🗄 Database Schema

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

## 🚀 Getting Started

### Demo Logins

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

### Approval Flow
1. Guard fills visitor details → clicks **"Ask Permission"**
2. Resident sees real-time notification with sound alert
3. Resident taps **Approve** or **Reject**
4. Guard screen updates instantly — auto-registers visitor if approved

### OTP Pass Flow
1. Resident creates a pass with guest name, date & time slot
2. System generates a **6-digit OTP** — resident shares with guest
3. Guest arrives → Guard clicks **"Verify OTP"** → enters code
4. System validates date/time → auto-registers entry

### Going to Production
1. Navigate to **Settings** (⚙️ tab)
2. Click **"Clear All Data & Go Production"**
3. All dummy data will be permanently removed
4. Start entering real visitor and resident data

## 📄 License

Copyright © 2026. Developed by **MCSPL** with ❤️
