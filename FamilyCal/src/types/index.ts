// Core domain types for FamilyCal

export interface User {
  id: string;
  email: string;
  createdAt: string;
  updatedAt: string;
}

export interface AuthSession {
  user: User;
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
}

export interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  accessToken: string | null;
  isGuest: boolean;
}

// Family Types
export interface Family {
  id: string;
  name: string;
  createdAt: string;
  updatedAt: string;
  ownerId: string;
}

export interface FamilyMember {
  id: string;
  familyId: string;
  name: string;
  linkedCalendarId: string | null;
  colorHex: string;
  avatarInitials: string;
  isDriver: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface FamilyMemberCalendar {
  id: string;
  familyMemberId: string;
  calendarId: string;
  calendarName: string;
  calendarColorHex: string;
  isAutoLinked: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface SharedCalendar {
  id: string;
  calendarId: string;
  calendarName: string;
  calendarColorHex: string;
  createdAt: string;
  updatedAt: string;
}

export interface SharedCalendarMember {
  familyMemberId: string;
  sharedCalendarId: string;
}

// Event Types
export interface CalendarEvent {
  id: string;
  familyId: string;
  eventGroupId: string | null;
  eventIdentifier: string;
  calendarId: string;
  isSharedCalendarEvent: boolean;
  isImportant: boolean;
  driverId: string | null;
  driverFamilyMemberId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface EventAttendee {
  familyEventId: string;
  familyMemberId: string;
  createdAt: string;
}

export interface EventWithDetails {
  id: string;
  title: string;
  startDate: string;
  endDate: string;
  location: string | null;
  notes: string | null;
  isAllDay: boolean;
  recurrenceRule: string | null;
  calendarId: string;
  calendarTitle: string;
  memberIds: string[];
  memberNames: string[];
  memberColors: string[];
  isImportant: boolean;
  driverId: string | null;
  driverName: string | null;
  alertMinutes: number | null;
  createdAt: string;
  updatedAt: string;
}

export interface GroupedEvent {
  id: string;
  title: string;
  timeRange: string | null;
  location: string | null;
  startDate: string;
  endDate: string;
  memberNames: string[];
  memberColor: string;
  calendarTitle: string;
  hasRecurrence: boolean;
  recurrenceRule: string | null;
  memberColors: string[];
  recurrenceChips: RecurrenceChip[];
}

export interface RecurrenceChip {
  id: string;
  date: string;
  label: string;
}

export interface MemberEventGroup {
  id: string;
  memberName: string;
  memberColor: string;
  nextEvent: GroupedEvent | null;
  upcomingEvents: GroupedEvent[];
}

// Driver Types
export interface Driver {
  id: string;
  familyId: string;
  name: string;
  phone: string | null;
  email: string | null;
  notes: string | null;
  travelTimeMinutes: number;
  familyMemberId: string | null;
  travelEventIdentifier: string | null;
  createdAt: string;
  updatedAt: string;
}

// Checklist Types
export interface Checklist {
  id: string;
  eventIdentifier: string;
  title: string;
  isCompleted: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ChecklistItem {
  id: string;
  checklistId: string;
  text: string;
  isChecked: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

// Saved Address Types
export interface SavedAddress {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  createdAt: string;
  updatedAt: string;
}

export interface RecentSearch {
  id: string;
  query: string;
  address: string;
  latitude: number;
  longitude: number;
  timestamp: string;
  createdAt: string;
}

// Settings Types
export interface AppSettings {
  id: string;
  userId: string;
  theme: 'light' | 'dark' | 'system';
  isProUser: boolean;
  eventsPerPerson: number;
  defaultAlertMinutes: number;
  morningBriefEnabled: boolean;
  morningBriefTime: string;
  createdAt: string;
  updatedAt: string;
}

export interface NotificationSettings {
  eventReminders: boolean;
  morningBrief: boolean;
  driverAlerts: boolean;
  inviteNotifications: boolean;
}

// API Response Types
export interface ApiResponse<T> {
  data: T | null;
  error: ApiError | null;
  success: boolean;
}

export interface ApiError {
  message: string;
  code: string;
  details?: Record<string, unknown>;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

// Deep Linking Types
export interface DeepLinkEvent {
  eventId: string;
}

export interface DeepLinkFamily {
  familyId: string;
}

export interface DeepLinkInvite {
  token: string;
  action: 'accept' | 'decline';
}

export type DeepLink =
  | { type: 'event'; payload: DeepLinkEvent }
  | { type: 'family'; payload: DeepLinkFamily }
  | { type: 'invite'; payload: DeepLinkInvite };

// Native Calendar Types
export interface NativeCalendar {
  id: string;
  title: string;
  color: string;
  source: {
    type: string;
    name: string;
  };
  isLocal: boolean;
  allowsModifications: boolean;
}

export interface NativeCalendarEvent {
  id: string;
  title: string;
  startDate: string;
  endDate: string;
  allDay: boolean;
  location: string | null;
  notes: string | null;
  calendarId: string;
  recurrenceRule: string | null;
}
