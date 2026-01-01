import { ExpoConfig } from '@expo/config-types';

const config: ExpoConfig = {
  expo: {
    name: 'FamilyCal',
    slug: 'famcal',
    version: '1.0.0',
    orientation: 'portrait',
    icon: './src/assets/icons/icon.png',
    userInterfaceStyle: 'automatic',
    splash: {
      image: './src/assets/icons/splash.png',
      resizeMode: 'contain',
      backgroundColor: '#FFFFFF',
    },
    assetBundlePatterns: ['**/*'],
    ios: {
      supportsTablet: true,
      bundleIdentifier: 'com.famcal.app',
      infoPlist: {
        NSCalendarsUsageDescription:
          'FamilyCal needs access to your calendar to sync and display family events.',
        NSCalendarsFullAccessUsageDescription:
          'FamilyCal needs full access to your calendar to sync and display family events.',
        NSContactsUsageDescription:
          'FamilyCal uses your contacts to help find and invite family members.',
        NSUserNotificationUsageDescription:
          'FamilyCal uses notifications to remind you about upcoming family events.',
      },
      config: {
        googleSignIn: {
          reservedClientId: process.env.GOOGLE_SIGN_IN_CLIENT_ID || '',
        },
      },
    },
    android: {
      adaptiveIcon: {
        foregroundImage: './src/assets/icons/adaptive-icon.png',
        backgroundColor: '#FFFFFF',
      },
      package: 'com.famcal.app',
      permissions: [
        'android.permission.READ_CALENDAR',
        'android.permission.WRITE_CALENDAR',
        'android.permission.READ_CONTACTS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
      ],
      versionCode: 1,
    },
    web: {
      favicon: './src/assets/icons/favicon.png',
      bundler: 'metro',
    },
    plugins: [
      [
        'expo-calendar',
        {
          calendarPermission: 'Allow FamilyCal to access your calendar.',
        },
      ],
      [
        'expo-notifications',
        {
          icon: './src/assets/icons/notification-icon.png',
          color: '#FF6B6B',
          iosDisplayInForeground: true,
        },
      ],
      [
        'expo-camera',
        {
          cameraPermission: 'Allow FamilyCal to access your camera.',
        },
      ],
    ],
    extra: {
      eas: {
        projectId: process.env.EAS_PROJECT_ID || '',
      },
      supabaseUrl: process.env.SUPABASE_URL || '',
      supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
    },
    runtimeVersion: {
      policy: 'appVersion',
    },
    updates: {
      url: `https://u.expo.dev/${process.env.EAS_PROJECT_ID || ''}`,
    },
    hooks: {
      postPublish: [
        {
          file: 'expo-updates/post-publish',
          config: {},
        },
      ],
    },
  },
};

export default config;
