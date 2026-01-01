// Constants used throughout the app

// Time intervals
export const MILLISECONDS_PER_SECOND = 1000;
export const MILLISECONDS_PER_MINUTE = 60 * MILLISECONDS_PER_SECOND;
export const MILLISECONDS_PER_HOUR = 60 * MILLISECONDS_PER_MINUTE;
export const MILLISECONDS_PER_DAY = 24 * MILLISECONDS_PER_HOUR;
export const MILLISECONDS_PER_WEEK = 7 * MILLISECONDS_PER_DAY;

// Date format constants
export const DATE_FORMAT = {
  ISO: 'yyyy-MM-dd',
  TIME_24H: 'HH:mm',
  TIME_12H: 'h:mm a',
  DATETIME_ISO: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
  DISPLAY_DATE: 'MMM d, yyyy',
  DISPLAY_DATE_FULL: 'EEEE, MMMM d, yyyy',
  DISPLAY_TIME: 'h:mm a',
  RELATIVE: 'relative',
} as const;

// Event constants
export const EVENT_CONSTANTS = {
  DEFAULT_ALERT_MINUTES: 60,
  MAX_TITLE_LENGTH: 100,
  MAX_NOTES_LENGTH: 1000,
  MAX_LOCATION_LENGTH: 200,
  MAX_ATTENDEES: 50,
  MIN_TITLE_LENGTH: 1,
  DEFAULT_EVENTS_PER_PERSON: 3,
  MAX_RECURRENCE_CHIPS: 5,
  RECURRENCE_MAX_COUNT: 100,
  RECURRENCE_MAX_YEARS: 5,
} as const;

// Family constants
export const FAMILY_CONSTANTS = {
  DEFAULT_MAX_MEMBERS: 5,
  PRO_MAX_MEMBERS: 10,
  DEFAULT_MAX_CALENDARS: 5,
  PRO_MAX_CALENDARS: 20,
  DEFAULT_MAX_SHARED_CALENDARS: 2,
  PRO_MAX_SHARED_CALENDARS: 10,
} as const;

// Calendar view constants
export const CALENDAR_CONSTANTS = {
  HOURS_IN_DAY: 24,
  MIN_HOUR_DISPLAY: 0,
  MAX_HOUR_DISPLAY: 23,
  TIME_SLOT_HEIGHT: 60,
  HOUR_COLUMN_WIDTH: 60,
  EVENT_PADDING: 4,
} as const;

// Notification constants
export const NOTIFICATION_CONSTANTS = {
  MORNING_BRIEF_HOUR: 7,
  MORNING_BRIEF_MINUTE: 0,
  DEFAULT_REMINDER_MINUTES: 60,
  CHANNEL_ID: 'famcal_events',
  CHANNEL_NAME: 'Family Events',
  EVENT_NOTIFICATION_CATEGORY: 'EVENT_NOTIFICATION',
  MORNING_BRIEF_CATEGORY: 'MORNING_BRIEF',
  ACTION_VIEW: 'VIEW_EVENT',
  ACTION_DISMISS: 'DISMISS',
  ACTION_SNOOZE: 'SNOOZE',
} as const;

// Deep link constants
export const DEEP_LINK_SCHEME = 'famcal';
export const DEEP_LINK_HOSTS = {
  EVENT: 'event',
  FAMILY: 'family',
  INVITE: 'invite',
  SETTINGS: 'settings',
} as const;

// Validation constants
export const VALIDATION = {
  EMAIL_REGEX: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
  PASSWORD_MIN_LENGTH: 8,
  NAME_MIN_LENGTH: 1,
  NAME_MAX_LENGTH: 50,
} as const;

// Feature flags
export const FEATURE_FLAGS = {
  ENABLE_GOOGLE_SIGN_IN: true,
  ENABLE_GUEST_MODE: true,
  ENABLE_MORNING_BRIEF: true,
  ENABLE_DRIVER_TRACKING: true,
  ENABLE_CHECKLISTS: true,
  ENABLE_ADVANCED_RECURRENCE: true,
} as const;

// Pro tier features
export const PRO_FEATURES = {
  UNLIMITED_MEMBERS: 'unlimited_members',
  UNLIMITED_CALENDARS: 'unlimited_calendars',
  UNLIMITED_SHARED_CALENDARS: 'unlimited_shared_calendars',
  CUSTOM_EVENT_COLORS: 'custom_event_colors',
  ADVANCED_REMINDERS: 'advanced_reminders',
  MORNING_BRIEF: 'morning_brief',
  WIDGET_CUSTOMIZATION: 'widget_customization',
  PRIORITY_SUPPORT: 'priority_support',
} as const;

// API endpoints (relative)
export const API_ENDPOINTS = {
  AUTH: '/auth',
  SIGNIN: '/auth/signin',
  SIGNUP: '/auth/signup',
  SIGNOUT: '/auth/signout',
  RESET_PASSWORD: '/auth/reset-password',
  REFRESH_TOKEN: '/auth/refresh',
  USER: '/user',
  FAMILIES: '/families',
  MEMBERS: '/members',
  EVENTS: '/events',
  CALENDARS: '/calendars',
  DRIVERS: '/drivers',
  ADDRESSES: '/addresses',
  INVITES: '/invites',
  SETTINGS: '/settings',
} as const;
