# 🏢 Evergreen Heights — Society Management System

A comprehensive, mobile-first society gate management application built for security guards to manage visitor entries, vehicle tracking, resident directories, and daily reporting.

## ✨ Features

### 🔐 Guard Authentication
- Guard login with ID & password
- Shift tracking with login/logout timestamps
- Multi-guard support

### 👤 Visitor Management
- Full visitor registration (name, phone, document, photos)
- Auto-fill from previous visits (phone-based lookup)
- Repeat visitor alerts & blacklist checking on entry
- Vehicle tracking per visit
- Quick re-entry for frequent visitors (2+ visits)

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
| Backend | Lovable Cloud |
| UI Components | shadcn/ui, Lucide icons |
| Alerts | SweetAlert2 |
| i18n | Custom context-based translation system |

## 📱 Navigation Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | 🏠 Home | Dashboard with stats, alerts, recent entries |
| 2 | ⚡ Quick | One-tap re-entry for frequent visitors |
| 3 | 👤 Visitor | Full visitor registration form |
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

## 🚀 Getting Started

### Demo Login
```
Guard ID: G001
Password: guard123
```

### Going to Production
1. Navigate to **Settings** (⚙️ tab)
2. Click **"Clear All Data & Go Production"**
3. All dummy data will be permanently removed
4. Start entering real visitor and resident data

## 📄 License

Copyright © 2026. Developed by **MCSPL** with ❤️
