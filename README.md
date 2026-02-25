# Dr. Judah — iOS Companion App

A premium SwiftUI app that syncs Apple Health data to Supabase and provides a personal health dashboard with AI-powered insights.

## Features

- **Health Dashboard** — Today's vitals at a glance with sparkline trends and a composite health score
- **Ask Judah** — AI chat powered by Claude, with full health context from your Apple Watch/iPhone
- **Background Sync** — Automatic HealthKit → Supabase sync every 1-2 hours
- **Proactive Alerts** — Local notifications for HRV drops, elevated resting HR, inactivity
- **Magic Link Auth** — Passwordless sign-in via Supabase Auth

## Setup

### Prerequisites

- Xcode 16+ (macOS)
- iPhone with iOS 17+
- Apple Developer account (for HealthKit)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Build

```bash
# 1. Install XcodeGen
brew install xcodegen

# 2. Generate Xcode project
cd dr-judah-ios
xcodegen generate

# 3. Open in Xcode
open DrJudah.xcodeproj

# 4. Set your Development Team in Signing & Capabilities

# 5. Select your iPhone, Build & Run (Cmd+R)

# 6. Grant HealthKit permissions when prompted
```

### Configuration

The Supabase credentials are in `DrJudah/Config.swift`. The app connects to the same Supabase project as the Dr. Judah web app.

## Architecture

| Layer | Files |
|-------|-------|
| **App** | `DrJudahApp.swift` — Entry point, auth gate |
| **Models** | `HealthData.swift`, `User.swift`, `ChatMessage.swift` |
| **Services** | `HealthKitManager`, `SupabaseManager`, `AuthManager`, `NotificationManager`, `BackgroundSyncManager` |
| **Views** | `HomeView` (dashboard), `AskJudahView` (chat), `SyncView` (settings), `LoginView` |
| **Extensions** | Brand colors, date helpers, HK type names |

## Health Data Synced

Steps, Heart Rate, Resting HR, HRV, Blood Oxygen, Active Calories, Exercise Minutes, VO₂ Max, Weight, Body Fat, Workouts, Sleep stages.

## Tech Stack

- **SwiftUI** (iOS 17+)
- **HealthKit** (read-only)
- **supabase-swift** (auth + database)
- **BackgroundTasks** framework (periodic sync)
- **UNUserNotificationCenter** (local alerts)
