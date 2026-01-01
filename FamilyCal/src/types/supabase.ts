// Supabase table types - Generated from database schema

export interface FamilyMemberRow {
  id: string;
  user_id: string | null;
  family_id: string | null;
  name: string | null;
  linked_calendar_id: string | null;
  color_hex: string | null;
  avatar_initials: string | null;
  is_driver: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export interface FamilyMemberCalendarRow {
  id: string;
  family_member_id: string | null;
  calendar_id: string | null;
  calendar_name: string | null;
  calendar_color_hex: string | null;
  is_auto_linked: boolean;
  created_at: string;
  updated_at: string;
}

export interface SharedCalendarRow {
  id: string;
  calendar_id: string | null;
  calendar_name: string | null;
  calendar_color_hex: string | null;
  created_at: string;
  updated_at: string;
}

export interface FamilyEventRow {
  id: string;
  event_group_id: string | null;
  event_identifier: string | null;
  calendar_id: string | null;
  is_shared_calendar_event: boolean;
  is_important: boolean;
  driver_id: string | null;
  driver_family_member_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface DriverRow {
  id: string;
  name: string | null;
  phone: string | null;
  email: string | null;
  notes: string | null;
  travel_time_minutes: number;
  family_member_id: string | null;
  travel_event_identifier: string | null;
  created_at: string;
  updated_at: string;
}

export interface SavedAddressRow {
  id: string;
  name: string | null;
  address: string | null;
  latitude: number;
  longitude: number;
  created_at: string;
  updated_at: string;
}

export interface RecentSearchRow {
  id: string;
  query: string | null;
  address: string | null;
  latitude: number;
  longitude: number;
  timestamp: string | null;
  created_at: string;
}

export interface FamilyRow {
  id: string;
  name: string | null;
  created_at: string;
  updated_at: string;
}

export interface UserSettingsRow {
  id: string;
  user_id: string | null;
  theme: string | null;
  is_pro_user: boolean;
  events_per_person: number | null;
  default_alert_minutes: number | null;
  morning_brief_enabled: boolean;
  morning_brief_time: string | null;
  created_at: string;
  updated_at: string;
}

export interface FamilyMemberSharedCalendarRow {
  family_member_id: string;
  shared_calendar_id: string;
  created_at: string;
}

export interface FamilyEventAttendeeRow {
  family_event_id: string;
  family_member_id: string;
  created_at: string;
}

// Junction table types
export interface FamilyMemberSharedCalendars {
  family_member_id: string;
  shared_calendar_id: string;
  created_at: string;
}

export interface FamilyEventAttendees {
  family_event_id: string;
  family_member_id: string;
  created_at: string;
}
