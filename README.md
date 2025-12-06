# FamCal

A family calendar application for iOS, watchOS, and widgets.

## Project Structure

```
FamCal/
├── FamCal/                      # Main iOS app
│   ├── Managers/                # Business logic managers
│   │   ├── AppSettingsManager.swift
│   │   ├── CalendarManager.swift
│   │   ├── ContactsManager.swift
│   │   ├── NotificationManager.swift
│   │   ├── Supabase*Manager.swift
│   │   ├── SyncMetadataManager.swift
│   │   └── WatchSessionManager.swift
│   ├── Views/                   # UI Views organized by feature
│   │   ├── Calendar/           # Calendar and daily views
│   │   ├── Events/             # Event creation, editing, display
│   │   ├── Family/             # Family management views
│   │   ├── Notifications/      # Notification settings
│   │   ├── Onboarding/         # First-time user experience
│   │   ├── Settings/           # All settings screens
│   │   └── Shared/             # Reusable UI components
│   ├── Models/                  # Data models and enums
│   ├── Utilities/               # Helper classes and extensions
│   ├── Assets.xcassets/        # Images and colors
│   ├── FamCal.xcdatamodeld/    # Core Data model
│   ├── ContentView.swift       # Root view
│   ├── FamCalApp.swift         # App entry point
│   ├── MainTabView.swift       # Tab navigation
│   └── Persistence.swift       # Core Data stack
├── NextEventWidget/             # Widget extension
├── WatchApp/                    # watchOS app
├── WatchAppExtension/           # watchOS extension
├── WatchShared/                 # Shared code for Watch
├── FamCalNotificationContent/   # Rich notifications
├── Documentation/               # Project documentation
│   ├── admob/                  # AdMob integration docs
│   ├── auth/                   # Authentication docs
│   ├── deployment/             # Deployment guides
│   ├── family/                 # Family features docs
│   ├── features/               # Feature implementation docs
│   ├── migration/              # Historical migration docs
│   ├── supabase/               # Backend setup docs
│   └── README.md               # Documentation index
├── supabase/                    # Supabase configuration
│   └── migrations/             # Database migrations
├── emails/                      # Email templates
├── Podfile                      # CocoaPods dependencies
└── FamCal.xcodeproj            # Xcode project

```

## Tech Stack

- **Frontend:** SwiftUI
- **Backend:** Supabase (PostgreSQL, Auth, Storage)
- **Data Sync:** Custom sync with conflict resolution
- **Ads:** Google AdMob (for free tier)
- **Local Storage:** Core Data
- **Dependencies:** CocoaPods

## Getting Started

1. **Clone the repository**
2. **Install dependencies:**
   ```bash
   pod install
   ```
3. **Configure Supabase:** See [Documentation/supabase/SUPABASE_SETUP.md](Documentation/supabase/SUPABASE_SETUP.md)
4. **Open workspace:**
   ```bash
   open FamCal.xcworkspace
   ```

## Documentation

See the [Documentation](Documentation/) folder for detailed guides on:
- Supabase setup and schema
- AdMob integration
- Authentication flow
- Feature implementations
- Apple Watch connectivity

## Features

- Family calendar with shared events
- Personal calendars integration
- Event linking and management
- Morning briefing
- Push notifications
- Apple Watch companion app
- Home screen widgets
- Driver tracking
- Saved addresses
- Dark mode support

## Requirements

- iOS 16.0+
- watchOS 9.0+
- Xcode 15.0+
- CocoaPods

## License

Proprietary
