// Settings-related types for FamilyCal

export type ThemeMode = 'light' | 'dark' | 'system';

export interface UserSettings {
  theme: ThemeMode;
  isProUser: boolean;
  eventsPerPerson: number;
  defaultAlertMinutes: number;
  morningBriefEnabled: boolean;
  morningBriefTime: string;
  notificationsEnabled: boolean;
  contactSyncEnabled: boolean;
}

export interface NotificationSettings {
  eventReminders: boolean;
  morningBrief: boolean;
  driverAlerts: boolean;
  inviteNotifications: boolean;
  reminderSound: boolean;
  vibrationEnabled: boolean;
}

export interface PrivacySettings {
  showLocationInEvents: boolean;
  shareCalendarWithFamily: boolean;
  allowInviteNotifications: boolean;
}

export interface AccountSettings {
  email: string;
  name: string;
  createdAt: string;
  lastSignInAt: string;
  emailConfirmed: boolean;
}

export interface ProSubscription {
  isActive: boolean;
  tier: 'monthly' | 'yearly' | null;
  expiresAt: string | null;
  features: ProFeature[];
}

export type ProFeature =
  | 'unlimited_members'
  | 'unlimited_calendars'
  | 'unlimited_shared_calendars'
  | 'custom_event_colors'
  | 'advanced_reminders'
  | 'morning_brief'
  | 'widget_customization'
  | 'priority_support';

export const PRO_FEATURES: Record<ProFeature, { name: string; description: string }> = {
  unlimited_members: {
    name: 'Unlimited Family Members',
    description: 'Add more than 5 family members',
  },
  unlimited_calendars: {
    name: 'Unlimited Calendars',
    description: 'Link more than 5 calendars per person',
  },
  unlimited_shared_calendars: {
    name: 'Unlimited Shared Calendars',
    description: 'Add more than 2 shared calendars',
  },
  custom_event_colors: {
    name: 'Custom Event Colors',
    description: 'Choose custom colors for events',
  },
  advanced_reminders: {
    name: 'Advanced Reminders',
    description: 'Multiple reminder options and custom times',
  },
  morning_brief: {
    name: 'Morning Brief',
    description: 'Daily summary of upcoming family events',
  },
  widget_customization: {
    name: 'Widget Customization',
    description: 'Customize widget appearance and content',
  },
  priority_support: {
    name: 'Priority Support',
    description: 'Get help faster from our team',
  },
};

export interface FeatureGate {
  feature: ProFeature;
  isEnabled: boolean;
  requiresUpgrade: boolean;
  upgradePrompt?: string;
}

export interface WidgetConfiguration {
  selectedMemberId: string | null;
  showTimeUntil: boolean;
  showLocation: boolean;
  theme: 'light' | 'dark' | 'auto';
}

export const DEFAULT_USER_SETTINGS: UserSettings = {
  theme: 'system',
  isProUser: false,
  eventsPerPerson: 3,
  defaultAlertMinutes: 60,
  morningBriefEnabled: true,
  morningBriefTime: '07:00',
  notificationsEnabled: true,
  contactSyncEnabled: false,
};

export const DEFAULT_NOTIFICATION_SETTINGS: NotificationSettings = {
  eventReminders: true,
  morningBrief: true,
  driverAlerts: true,
  inviteNotifications: true,
  reminderSound: true,
  vibrationEnabled: true,
};
