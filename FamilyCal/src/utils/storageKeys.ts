// Storage Keys for AsyncStorage and SecureStore
// These keys are used throughout the app for persistence
// NEVER change these keys - they are used for backward compatibility

export const STORAGE_KEYS = {
  // Onboarding state
  HAS_COMPLETED_ONBOARDING: 'hasCompletedOnboarding',
  HAS_COMPLETED_FAMILY_SETUP: 'hasCompletedFamilySetup',

  // Family data
  FAMILY_ID: 'com.famcal.familyId',
  CURRENT_FAMILY_ID: 'com.famcal.currentFamilyId',

  // User preferences
  USER_ID: 'com.famcal.userId',
  USER_EMAIL: 'com.famcal.user.email',
  USER_NAME: 'com.famcal.user.name',

  // Pro status
  PRO_ENABLED: 'com.famcal.pro.enabled',
  PRO_EXPIRES_AT: 'com.famcal.pro.expiresAt',

  // Auth tokens (SecureStore)
  AUTH_TOKEN: 'com.famcal.auth.token',
  AUTH_REFRESH_TOKEN: 'com.famcal.auth.refresh',
  AUTH_TOKEN_EXPIRY: 'com.famcal.auth.expiry',

  // Theme preference
  THEME_PREFERENCE: 'com.famcal.theme',
  
  // Notification settings
  NOTIFICATION_SETTINGS: 'com.famcal.notifications',
  MORNING_BRIEF_ENABLED: 'com.famcal.morningBrief.enabled',
  MORNING_BRIEF_TIME: 'com.famcal.morningBrief.time',
  DEFAULT_ALERT_MINUTES: 'com.famcal.defaultAlertMinutes',

  // App settings
  EVENTS_PER_PERSON: 'com.famcal.eventsPerPerson',
  SELECTED_MEMBER_ID: 'com.famcal.selectedMemberId',

  // Widget configuration
  WIDGET_CONFIG: 'com.famcal.widget.config',
  WIDGET_SELECTED_MEMBER: 'com.famcal.widget.selectedMember',

  // Cached data
  CACHED_MEMBERS: 'com.famcal.cache.members',
  CACHED_CALENDARS: 'com.famcal.cache.calendars',
  CACHED_EVENTS: 'com.famcal.cache.events',
  CACHED_ADDRESSES: 'com.famcal.cache.addresses',

  // Last sync timestamps
  LAST_SYNC_MEMBERS: 'com.famcal.sync.members',
  LAST_SYNC_EVENTS: 'com.famcal.sync.events',
  LAST_SYNC_SETTINGS: 'com.famcal.sync.settings',

  // Guest mode
  IS_GUEST_MODE: 'com.famcal.guestMode',
  GUEST_SESSION_ID: 'com.famcal.guestSessionId',

  // Deep link pending state
  PENDING_DEEP_LINK: 'com.famcal.pendingDeepLink',

  // Analytics
  ANALYTICS_ENABLED: 'com.famcal.analytics.enabled',
  LAST_ANALYTICS_SYNC: 'com.famcal.analytics.lastSync',

  // Migration tracking
  SCHEMA_VERSION: 'com.famcal.schemaVersion',
  MIGRATION_COMPLETED: 'com.famcal.migration.completed',
} as const;

export type StorageKey = keyof typeof STORAGE_KEYS;

export const SECURE_STORAGE_KEYS = {
  AUTH_TOKEN: 'com.famcal.auth.token',
  AUTH_REFRESH_TOKEN: 'com.famcal.auth.refresh',
  ENCRYPTED_USER_DATA: 'com.famcal.encrypted.userData',
} as const;
