import supabase from './SupabaseClient';
import { withErrorHandling } from './SupabaseClient';
import {
  FamilyMemberRow,
  FamilyMemberCalendarRow,
  SharedCalendarRow,
  FamilyEventRow,
  DriverRow,
  SavedAddressRow,
  RecentSearchRow,
  FamilyRow,
  UserSettingsRow,
  FamilyMemberSharedCalendarRow,
  FamilyEventAttendeeRow,
} from '@/types/supabase';
import { STORAGE_KEYS } from '@/utils/storageKeys';
import AsyncStorage from '@react-native-async-storage/async-storage';

export class SupabaseDataService {
  // Get the current user's family ID
  private async getCurrentFamilyId(): Promise<string | null> {
    let familyId = await AsyncStorage.getItem(STORAGE_KEYS.FAMILY_ID);
    if (!familyId) {
      familyId = await AsyncStorage.getItem(STORAGE_KEYS.CURRENT_FAMILY_ID);
    }
    return familyId;
  }

  // ============ Family CRUD ============

  async createFamily(name: string): Promise<{ data: FamilyRow | null; error: any }> {
    const { data, error } = await withErrorHandling(
      () => supabase
        .from('families')
        .insert({ name })
        .select()
        .single(),
      'Failed to create family'
    );

    if (data) {
      await AsyncStorage.setItem(STORAGE_KEYS.FAMILY_ID, data.id);
    }

    return { data, error };
  }

  async getFamily(familyId: string): Promise<{ data: FamilyRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('families')
        .select('*')
        .eq('id', familyId)
        .single(),
      'Failed to get family'
    );
  }

  async updateFamily(familyId: string, name: string): Promise<{ data: FamilyRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('families')
        .update({ name })
        .eq('id', familyId)
        .select()
        .single(),
      'Failed to update family'
    );
  }

  async getFamilies(): Promise<{ data: FamilyRow[] | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('families')
        .select('*')
        .order('created_at', { ascending: false }),
      'Failed to get families'
    );
  }

  // ============ Family Members CRUD ============

  async createFamilyMember(member: Omit<FamilyMemberRow, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: FamilyMemberRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_members')
        .insert(member)
        .select()
        .single(),
      'Failed to create family member'
    );
  }

  async getFamilyMembers(familyId?: string): Promise<{ data: FamilyMemberRow[] | null; error: any }> {
    const id = familyId || await this.getCurrentFamilyId();
    if (!id) return { data: null, error: new Error('No family ID') };

    return withErrorHandling(
      () => supabase
        .from('family_members')
        .select('*')
        .eq('family_id', id)
        .order('sort_order', { ascending: true }),
      'Failed to get family members'
    );
  }

  async getFamilyMember(memberId: string): Promise<{ data: FamilyMemberRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_members')
        .select('*')
        .eq('id', memberId)
        .single(),
      'Failed to get family member'
    );
  }

  async updateFamilyMember(memberId: string, updates: Partial<FamilyMemberRow>): Promise<{ data: FamilyMemberRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_members')
        .update(updates)
        .eq('id', memberId)
        .select()
        .single(),
      'Failed to update family member'
    );
  }

  async deleteFamilyMember(memberId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('family_members')
        .delete()
        .eq('id', memberId),
      'Failed to delete family member'
    );

    return { error };
  }

  // ============ Family Member Calendars ============

  async createMemberCalendar(calendar: Omit<FamilyMemberCalendarRow, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: FamilyMemberCalendarRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_member_calendars')
        .insert(calendar)
        .select()
        .single(),
      'Failed to create member calendar'
    );
  }

  async getMemberCalendars(memberId: string): Promise<{ data: FamilyMemberCalendarRow[] | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_member_calendars')
        .select('*')
        .eq('family_member_id', memberId),
      'Failed to get member calendars'
    );
  }

  async deleteMemberCalendar(calendarId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('family_member_calendars')
        .delete()
        .eq('id', calendarId),
      'Failed to delete member calendar'
    );

    return { error };
  }

  // ============ Shared Calendars ============

  async createSharedCalendar(calendar: Omit<SharedCalendarRow, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: SharedCalendarRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('shared_calendars')
        .insert(calendar)
        .select()
        .single(),
      'Failed to create shared calendar'
    );
  }

  async getSharedCalendars(): Promise<{ data: SharedCalendarRow[] | null; error: any }> {
    const familyId = await this.getCurrentFamilyId();
    if (!familyId) return { data: null, error: new Error('No family ID') };

    return withErrorHandling(
      () => supabase
        .from('shared_calendars')
        .select('*')
        .order('created_at', { ascending: true }),
      'Failed to get shared calendars'
    );
  }

  async linkMemberToSharedCalendar(memberId: string, calendarId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('family_member_shared_calendars')
        .insert({ family_member_id: memberId, shared_calendar_id: calendarId }),
      'Failed to link member to shared calendar'
    );

    return { error };
  }

  async unlinkMemberFromSharedCalendar(memberId: string, calendarId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('family_member_shared_calendars')
        .delete()
        .eq('family_member_id', memberId)
        .eq('shared_calendar_id', calendarId),
      'Failed to unlink member from shared calendar'
    );

    return { error };
  }

  // ============ Family Events CRUD ============

  async createFamilyEvent(event: Omit<FamilyEventRow, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: FamilyEventRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_events')
        .insert(event)
        .select()
        .single(),
      'Failed to create family event'
    );
  }

  async getFamilyEvents(options?: {
    startDate?: string;
    endDate?: string;
    memberIds?: string[];
    calendarIds?: string[];
    limit?: number;
  }): Promise<{ data: FamilyEventRow[] | null; error: any }> {
    const familyId = await this.getCurrentFamilyId();
    if (!familyId) return { data: null, error: new Error('No family ID') };

    let query = supabase
      .from('family_events')
      .select('*')
      .eq('family_id', familyId);

    if (options?.startDate) {
      query = query.gte('created_at', options.startDate);
    }
    if (options?.endDate) {
      query = query.lte('created_at', options.endDate);
    }
    if (options?.limit) {
      query = query.limit(options.limit);
    }

    return withErrorHandling(
      () => query.order('created_at', { ascending: false }),
      'Failed to get family events'
    );
  }

  async getFamilyEvent(eventId: string): Promise<{ data: FamilyEventRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_events')
        .select('*')
        .eq('id', eventId)
        .single(),
      'Failed to get family event'
    );
  }

  async updateFamilyEvent(eventId: string, updates: Partial<FamilyEventRow>): Promise<{ data: FamilyEventRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_events')
        .update(updates)
        .eq('id', eventId)
        .select()
        .single(),
      'Failed to update family event'
    );
  }

  async deleteFamilyEvent(eventId: string): Promise<{ error: any }> {
    // Soft delete - update is_deleted flag
    const { error } = await withErrorHandling(
      () => supabase
        .from('family_events')
        .update({ is_deleted: true })
        .eq('id', eventId),
      'Failed to delete family event'
    );

    return { error };
  }

  // ============ Event Attendees ============

  async addEventAttendee(eventId: string, memberId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('family_event_attendees')
        .insert({ family_event_id: eventId, family_member_id: memberId }),
      'Failed to add event attendee'
    );

    return { error };
  }

  async removeEventAttendee(eventId: string, memberId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('family_event_attendees')
        .delete()
        .eq('family_event_id', eventId)
        .eq('family_member_id', memberId),
      'Failed to remove event attendee'
    );

    return { error };
  }

  async getEventAttendees(eventId: string): Promise<{ data: FamilyEventAttendeeRow[] | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_event_attendees')
        .select('*')
        .eq('family_event_id', eventId),
      'Failed to get event attendees'
    );
  }

  // ============ Drivers CRUD ============

  async createDriver(driver: Omit<DriverRow, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: DriverRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('drivers')
        .insert(driver)
        .select()
        .single(),
      'Failed to create driver'
    );
  }

  async getDrivers(): Promise<{ data: DriverRow[] | null; error: any }> {
    const familyId = await this.getCurrentFamilyId();
    if (!familyId) return { data: null, error: new Error('No family ID') };

    return withErrorHandling(
      () => supabase
        .from('drivers')
        .select('*')
        .eq('family_id', familyId),
      'Failed to get drivers'
    );
  }

  async updateDriver(driverId: string, updates: Partial<DriverRow>): Promise<{ data: DriverRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('drivers')
        .update(updates)
        .eq('id', driverId)
        .select()
        .single(),
      'Failed to update driver'
    );
  }

  async deleteDriver(driverId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('drivers')
        .delete()
        .eq('id', driverId),
      'Failed to delete driver'
    );

    return { error };
  }

  // ============ Saved Addresses ============

  async createSavedAddress(address: Omit<SavedAddressRow, 'id' | 'created_at' | 'updated_at'>): Promise<{ data: SavedAddressRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('saved_addresses')
        .insert(address)
        .select()
        .single(),
      'Failed to create saved address'
    );
  }

  async getSavedAddresses(): Promise<{ data: SavedAddressRow[] | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('saved_addresses')
        .select('*')
        .order('created_at', { ascending: false }),
      'Failed to get saved addresses'
    );
  }

  async deleteSavedAddress(addressId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('saved_addresses')
        .delete()
        .eq('id', addressId),
      'Failed to delete saved address'
    );

    return { error };
  }

  // ============ Recent Searches ============

  async createRecentSearch(search: Omit<RecentSearchRow, 'id' | 'created_at'>): Promise<{ data: RecentSearchRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('recent_searches')
        .insert(search)
        .select()
        .single(),
      'Failed to create recent search'
    );
  }

  async getRecentSearches(limit: number = 10): Promise<{ data: RecentSearchRow[] | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('recent_searches')
        .select('*')
        .order('timestamp', { ascending: false })
        .limit(limit),
      'Failed to get recent searches'
    );
  }

  async clearRecentSearches(): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .from('recent_searches')
        .delete(),
      'Failed to clear recent searches'
    );

    return { error };
  }

  // ============ User Settings ============

  async getUserSettings(userId: string): Promise<{ data: UserSettingsRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('user_settings')
        .select('*')
        .eq('user_id', userId)
        .single(),
      'Failed to get user settings'
    );
  }

  async upsertUserSettings(settings: Omit<UserSettingsRow, 'created_at' | 'updated_at'>): Promise<{ data: UserSettingsRow | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('user_settings')
        .upsert(settings)
        .select()
        .single(),
      'Failed to upsert user settings'
    );
  }

  // ============ Invitations ============

  async createInvitation(familyId: string, email: string): Promise<{ data: any | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .rpc('create_family_invitation', { family_id: familyId, invite_email: email }),
      'Failed to create invitation'
    );
  }

  async acceptInvitation(token: string, memberId: string): Promise<{ error: any }> {
    const { error } = await withErrorHandling(
      () => supabase
        .rpc('accept_family_invitation', { invitation_token: token, family_member_id: memberId }),
      'Failed to accept invitation'
    );

    return { error };
  }

  // ============ Search ============

  async searchEvents(query: string, options?: { limit?: number }): Promise<{ data: any[] | null; error: any }> {
    const familyId = await this.getCurrentFamilyId();
    if (!familyId) return { data: null, error: new Error('No family ID') };

    return withErrorHandling(
      () => supabase
        .from('family_events')
        .select('*')
        .eq('family_id', familyId)
        .ilike('title', `%${query}%`)
        .limit(options?.limit || 20),
      'Failed to search events'
    );
  }

  async searchMembers(query: string, options?: { limit?: number }): Promise<{ data: any[] | null; error: any }> {
    return withErrorHandling(
      () => supabase
        .from('family_members')
        .select('*')
        .ilike('name', `%${query}%`)
        .limit(options?.limit || 10),
      'Failed to search members'
    );
  }
}

export const supabaseDataService = new SupabaseDataService();
export default supabaseDataService;
