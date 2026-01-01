# FamCal - React Native + Expo

FamilyCal is a cross-platform family calendar application built with React Native and Expo, supporting iOS, Android, and Web platforms.

## Features

- **Family Calendar Management**: Sync and manage family events across multiple calendars
- **Multi-Platform Support**: iOS, Android, and Web
- **Offline-First**: Local storage with Supabase cloud sync
- **Event Notifications**: Push notifications for upcoming family events
- **Family Members**: Add and manage family members with custom colors
- **Shared Calendars**: Link personal and shared calendars

## Prerequisites

- Node.js 18+
- npm or yarn
- Expo CLI: `npm install -g expo-cli`
- EAS CLI: `npm install -g eas-cli`

## Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/famcal.git
cd famcal
```

2. Install dependencies:
```bash
npm install
```

3. Create environment file:
```bash
cp .env.example .env
```

4. Configure environment variables in `.env`:
   - SUPABASE_URL: Your Supabase project URL
   - SUPABASE_ANON_KEY: Your Supabase anon key
   - GOOGLE_SIGN_IN_CLIENT_ID: (Optional) For Google OAuth

## Running the App

### Development Mode

```bash
# Start Metro bundler
npx expo start

# Run on iOS simulator
npx expo start --ios

# Run on Android emulator
npx expo start --android

# Run on web
npx expo start --web
```

### Production Build

```bash
# Build for preview (development build)
eas build --profile preview

# Build for production
eas build --profile production
```

## Project Structure

```
FamilyCal/
├── src/
│   ├── app/                 # App entry point and providers
│   ├── components/          # Reusable UI components
│   ├── context/             # React Context providers
│   ├── hooks/               # Custom React hooks
│   ├── navigation/          # Navigation configuration
│   ├── screens/             # Screen components
│   │   ├── Auth/           # Login, Signup, Forgot Password
│   │   ├── Onboarding/     # Onboarding flow screens
│   │   ├── Family/         # Family management screens
│   │   ├── Calendar/       # Calendar views
│   │   ├── Events/         # Event management screens
│   │   ├── Checklists/     # Checklist screens
│   │   └── Settings/       # App settings
│   ├── services/            # API and service layer
│   │   └── supabase/       # Supabase client and services
│   ├── styles/              # Design tokens and themes
│   ├── types/               # TypeScript type definitions
│   └── utils/               # Utility functions
├── app.json                 # Expo configuration
├── app.config.js           # Environment-specific config
├── eas.json                # EAS Build configuration
├── tsconfig.json           # TypeScript configuration
└── package.json
```

## Configuration

### Supabase Setup

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Run the migration scripts from the `/supabase` directory
3. Enable Row Level Security (RLS) on all tables
4. Add your Supabase URL and anon key to `.env`

### Calendar Permissions

The app requires calendar permissions on iOS and Android. These are configured in `app.json` and requested at runtime through `expo-calendar`.

### Notifications

Push notifications are configured in `app.json` and implemented through `expo-notifications`. Make sure to configure notification channels for Android.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| SUPABASE_URL | Supabase project URL | Yes |
| SUPABASE_ANON_KEY | Supabase anonymous key | Yes |
| SUPABASE_SERVICE_ROLE_KEY | Supabase service role key | No (dev only) |
| GOOGLE_SIGN_IN_CLIENT_ID | Google OAuth client ID | No |
| EAS_PROJECT_ID | EAS Build project ID | No |

## Testing

```bash
# Run type checking
npm run typecheck

# Run linting
npm run lint

# Run tests
npm test
```

## Building for Release

### iOS

1. Configure signing in `eas.json`
2. Run: `eas build --profile production`
3. Submit to App Store: `eas submit`

### Android

1. Configure signing in `eas.json`
2. Run: `eas build --profile production`
3. Submit to Play Store: `eas submit`

## Troubleshooting

### Metro Bundler Issues

```bash
# Clear Metro cache
npx expo start --clear
```

### TypeScript Errors

```bash
# Check for type errors
npm run typecheck
```

### Build Failures

Check the EAS Build logs for detailed error messages. Common issues:
- Missing environment variables
- Incorrect signing configuration
- Incompatible dependency versions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details.
