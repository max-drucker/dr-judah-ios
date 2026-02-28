# Dr. Judah iOS — Health Intelligence Companion App

A native SwiftUI app that turns your iPhone and Apple Watch into the data backbone for [Dr. Judah](https://github.com/max-drucker/dr-judah), syncing 20+ Apple Health data types to Supabase with background sync, AI-powered health chat, and proactive alerts.

---

## Features

### 📊 Dashboard
Executive health summary with composite health score, signal cards with sparkline trends, key insights, and interactive trend charts — all pulled from your synced Apple Health + lab data.

### 💬 Ask Judah
AI chat powered by Claude with your full health context — genetics, labs, vitals, CGM, medications, supplements, imaging. Same intelligence as the web app, native on your phone.

### 📈 Trends
Longitudinal trend analysis across vitals and biomarkers with interactive charts.

### 💡 Insights
AI-generated health insights and personalized recommendations with action cards.

### ❤️ Vitals
Real-time vitals dashboard from Apple Health data.

### 📋 More
Access to Labs, DNA/Genomics, Imaging, Medications, Supplements, Screenings, and Sleep data — all synced from the web platform.

### 🔄 Background Sync
Automatic HealthKit → Supabase pipeline every 1-2 hours. No manual intervention needed.

### 🔔 Proactive Alerts
Local notifications for critical health events: dangerous HR, glucose spikes/crashes, HRV drops, blood pressure anomalies.

### 📱 Omron Import
Upload blood pressure CSV readings directly from the app.

---

## Tabs

| Tab | View | Description |
|-----|------|-------------|
| Dashboard | `DashboardView` | Executive summary, health score, signals, insights, charts |
| Trends | `TrendsView` | Longitudinal biomarker and vital trends |
| Insights | `InsightsView` | AI-generated insights and recommendations |
| Ask Judah | `AskJudahView` | Multi-model AI chat with full health context |
| Vitals | `VitalsView` | Real-time Apple Health vitals |
| More | `MoreView` | Labs, DNA, Imaging, Meds, Supplements, Screenings, Sleep |

---

## Health Data Synced

Steps, Heart Rate, Resting HR, HRV, Blood Oxygen, Active Calories, Exercise Minutes, VO₂ Max, Weight, Body Fat, Workouts, Sleep stages (deep, REM, core, awake), and more — 20+ HealthKit data types with 2 years of historical data on first sync.

---

## Architecture

```
49 Swift source files

DrJudah/
├── Config.swift                    # Supabase credentials
├── DrJudahApp.swift                # Entry point, auth gate
├── Models/
│   ├── ChatMessage.swift
│   ├── DashboardData.swift
│   ├── HealthData.swift
│   ├── TrendsData.swift
│   └── User.swift
├── Services/
│   ├── APIManager.swift            # API communication
│   ├── AuthManager.swift           # Supabase auth (magic link)
│   ├── BackgroundSyncManager.swift # Periodic HealthKit → Supabase
│   ├── HealthKitManager.swift      # HealthKit read access
│   ├── NotificationManager.swift   # Local alert notifications
│   ├── OmronCSVImporter.swift      # Blood pressure CSV import
│   └── SupabaseManager.swift       # Database operations
├── Views/
│   ├── ContentView.swift           # Tab bar (6 tabs)
│   ├── LoginView.swift             # Magic link auth
│   ├── Dashboard/                  # Executive summary components
│   ├── AskJudah/                   # AI chat + message bubbles
│   ├── Trends/                     # Trend charts
│   ├── Insights/                   # AI insights + recommendations
│   ├── Vitals/                     # Real-time vitals
│   ├── Home/                       # Health score, vital cards
│   ├── Sync/                       # Sync settings
│   ├── More/                       # Labs, DNA, Imaging, etc.
│   └── Components/                 # Shared UI (gradient header, loading)
└── Extensions/
    ├── Color+DrJudah.swift         # Brand colors
    ├── Date+Formatting.swift       # Date helpers
    └── HKQuantityType+Name.swift   # HealthKit type display names
```

---

## Setup

### Prerequisites

- Xcode 16+
- iPhone with iOS 17+
- Apple Developer account (for HealthKit entitlement)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Build & Run

```bash
# 1. Install XcodeGen
brew install xcodegen

# 2. Generate Xcode project
cd dr-judah-ios
xcodegen generate

# 3. Open in Xcode
open DrJudah.xcodeproj

# 4. Set your Development Team in Signing & Capabilities

# 5. Select your iPhone → Build & Run (Cmd+R)

# 6. Grant HealthKit permissions when prompted
```

### Configuration

Supabase credentials are in `DrJudah/Config.swift`. The app connects to the same Supabase project as the Dr. Judah web app.

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI (iOS 17+) |
| Health Data | HealthKit (read-only) |
| Backend | supabase-swift (auth + database) |
| Background Sync | BackgroundTasks framework |
| Notifications | UNUserNotificationCenter (local) |
| AI | Claude via Dr. Judah API |
| Project Gen | XcodeGen |

---

## Related

- **[Dr. Judah Web App](https://github.com/max-drucker/dr-judah)** — The full Next.js platform this app feeds into
- **Live:** [drjudah.thedruckers.com](https://drjudah.thedruckers.com)

## Built With

Built entirely via WhatsApp using [OpenClaw](https://github.com/openclaw/openclaw) — an autonomous AI agent platform. No IDE was opened.

## License

Private — All rights reserved.
