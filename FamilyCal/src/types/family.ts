// Family-related types for FamilyCal

export interface FamilyFormData {
  name: string;
  memberIds: string[];
}

export interface FamilyMemberFormData {
  name: string;
  colorHex: string;
  linkedCalendarIds: string[];
  isDriver: boolean;
}

export interface FamilyMemberFormErrors {
  name?: string;
  color?: string;
  calendar?: string;
}

export interface FamilyInvite {
  id: string;
  familyId: string;
  email: string;
  token: string;
  status: 'pending' | 'accepted' | 'declined' | 'expired';
  createdAt: string;
  expiresAt: string;
}

export interface FamilyInviteRequest {
  familyId: string;
  email: string;
  message?: string;
}

export interface AcceptInviteRequest {
  token: string;
  familyMemberId: string;
}

export interface MemberCalendarSelection {
  memberId: string;
  calendarIds: string[];
}

export interface FamilyStatistics {
  totalMembers: number;
  totalCalendars: number;
  totalEvents: number;
  upcomingEventsCount: number;
}

export interface FamilyPermissions {
  canAddMembers: boolean;
  canRemoveMembers: boolean;
  canEditMembers: boolean;
  canManageCalendars: boolean;
  canDeleteFamily: boolean;
  canInviteMembers: boolean;
}

export interface ProTierLimits {
  maxMembers: number;
  maxCalendars: number;
  maxSharedCalendars: number;
}

export const DEFAULT_PRO_TIER_LIMITS: ProTierLimits = {
  maxMembers: 10,
  maxCalendars: 20,
  maxSharedCalendars: 10,
};

export const FREE_TIER_LIMITS: ProTierLimits = {
  maxMembers: 5,
  maxCalendars: 5,
  maxSharedCalendars: 2,
};

export interface DriverAssignment {
  eventId: string;
  driverMemberId: string;
  travelTimeMinutes: number;
}

export interface DriverInfo {
  id: string;
  memberId: string;
  memberName: string;
  phone: string | null;
  email: string | null;
  travelTimeMinutes: number;
  isAvailable: boolean;
}
