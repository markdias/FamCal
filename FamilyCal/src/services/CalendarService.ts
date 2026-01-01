import { Platform } from 'react-native';
import * as Calendar from 'expo-calendar';
import { Event } from 'expo-calendar/build/Calendar.types';
import supabaseDataService from './supabase/SupabaseDataService';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';
import { NativeCalendar, NativeCalendarEvent } from '@/types';
import { format, parseISO } from 'date-fns';

class CalendarService {
  private familyCalendarId: string | null = null;
  private isInitialized = false;

  // Initialize calendar service
  async initialize(): Promise<boolean> {
    try {
      const permissionStatus = await this.requestPermissions();
      if (!permissionStatus) {
        console.log('Calendar permissions not granted');
        return false;
      }

      // Get or create family calendar
      this.familyCalendarId = await this.getOrCreateFamilyCalendar();
      this.isInitialized = true;
      
      return true;
    } catch (error) {
      console.error('Failed to initialize calendar service:', error);
      return false;
    }
  }

  // Request calendar permissions
  async requestPermissions(): Promise<boolean> {
    try {
      const { status } = await Calendar.requestCalendarPermissionsAsync();
      return status === 'granted';
    } catch (error) {
      console.error('Failed to request calendar permissions:', error);
      return false;
    }
  }

  // Check calendar permissions
  async checkPermissions(): Promise<boolean> {
    try {
      const { status } = await Calendar.getCalendarPermissionsAsync();
      return status === 'granted';
    } catch (error) {
      console.error('Failed to check calendar permissions:', error);
      return false;
    }
  }

  // Get or create the family calendar
  private async getOrCreateFamilyCalendar(): Promise<string | null> {
    try {
      // Check if we already have a family calendar ID stored
      const storedId = await AsyncStorage.getItem('com.famcal.familyCalendarId');
      if (storedId) {
        return storedId;
      }

      // Get all available calendars
      const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);

      // Look for existing FamCal calendar
      const existingCalendar = calendars.find(
        cal => cal.title === 'FamilyCal' || cal.title === 'FamCal'
      );

      if (existingCalendar) {
        await AsyncStorage.setItem('com.famcal.familyCalendarId', existingCalendar.id);
        return existingCalendar.id;
      }

      // Create new calendar
      const calendarId = await Calendar.createCalendarAsync({
        title: 'FamilyCal',
        color: '#FF6B6B',
        entityType: Calendar.EntityTypes.EVENT,
        sourceId: Platform.OS === 'ios' 
          ? calendars.find(cal => cal.source?.type === 'local')?.source?.id 
          : undefined,
        source: {
          name: 'FamilyCal',
          type: Platform.OS === 'ios' ? 'local' : 'local',
        },
        accessLevel: Calendar.CalendarAccessLevel.OWNER,
        isLocal: true,
      });

      await AsyncStorage.setItem('com.famcal.familyCalendarId', calendarId);
      return calendarId;
    } catch (error) {
      console.error('Failed to get/create family calendar:', error);
      return null;
    }
  }

  // Get all available calendars
  async getAvailableCalendars(): Promise<NativeCalendar[]> {
    try {
      const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);
      
      return calendars.map(cal => ({
        id: cal.id,
        title: cal.title,
        color: cal.color || '#007AFF',
        source: {
          type: cal.source?.type || 'local',
          name: cal.source?.name || 'Unknown',
        },
        isLocal: cal.source?.isLocalAccount || false,
        allowsModifications: cal.allowsModifications,
      }));
    } catch (error) {
      console.error('Failed to get available calendars:', error);
      return [];
    }
  }

  // Create an event in the device calendar
  async createEvent(
    calendarId: string,
    event: {
      title: string;
      startDate: Date;
      endDate: Date;
      location?: string;
      notes?: string;
      allDay?: boolean;
      recurrenceRule?: string;
    }
  ): Promise<string | null> {
    try {
      const eventId = await Calendar.createEventAsync(calendarId, {
        title: event.title,
        startDate: event.startDate,
        endDate: event.endDate,
        location: event.location,
        notes: event.notes,
        allDay: event.allDay || false,
        recurrenceRule: event.recurrenceRule,
      });

      return eventId;
    } catch (error) {
      console.error('Failed to create event:', error);
      return null;
    }
  }

  // Update an existing event
  async updateEvent(
    eventId: string,
    updates: {
      title?: string;
      startDate?: Date;
      endDate?: Date;
      location?: string;
      notes?: string;
      allDay?: boolean;
    }
  ): Promise<boolean> {
    try {
      await Calendar.updateEventAsync(eventId, {
        title: updates.title,
        startDate: updates.startDate,
        endDate: updates.endDate,
        location: updates.location,
        notes: updates.notes,
        allDay: updates.allDay,
      });

      return true;
    } catch (error) {
      console.error('Failed to update event:', error);
      return false;
    }
  }

  // Delete an event
  async deleteEvent(eventId: string): Promise<boolean> {
    try {
      await Calendar.deleteEventAsync(eventId);
      return true;
    } catch (error) {
      console.error('Failed to delete event:', error);
      return false;
    }
  }

  // Get events for a specific calendar and date range
  async getEvents(
    calendarIds: string[],
    startDate: Date,
    endDate: Date
  ): Promise<NativeCalendarEvent[]> {
    try {
      const allEvents: NativeCalendarEvent[] = [];

      for (const calendarId of calendarIds) {
        const events = await Calendar.getEventsAsync([calendarId], startDate, endDate);
        
        const mappedEvents = events.map(event => ({
          id: event.id,
          title: event.title,
          startDate: event.startDate,
          endDate: event.endDate,
          allDay: event.allDay,
          location: event.location,
          notes: event.notes,
          calendarId: event.calendarId,
          recurrenceRule: event.recurrenceRule,
        }));

        allEvents.push(...mappedEvents);
      }

      return allEvents;
    } catch (error) {
      console.error('Failed to get events:', error);
      return [];
    }
  }

  // Get events for a specific calendar
  async getCalendarEvents(
    calendarId: string,
    startDate: Date,
    endDate: Date
  ): Promise<NativeCalendarEvent[]> {
    try {
      const events = await Calendar.getEventsAsync([calendarId], startDate, endDate);
      
      return events.map(event => ({
        id: event.id,
        title: event.title,
        startDate: event.startDate,
        endDate: event.endDate,
        allDay: event.allDay,
        location: event.location,
        notes: event.notes,
        calendarId: event.calendarId,
        recurrenceRule: event.recurrenceRule,
      }));
    } catch (error) {
      console.error('Failed to get calendar events:', error);
      return [];
    }
  }

  // Get events for today
  async getTodayEvents(): Promise<NativeCalendarEvent[]> {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const calendars = await this.getAvailableCalendars();
    const calendarIds = calendars.map(cal => cal.id);

    return this.getEvents(calendarIds, startOfDay, endOfDay);
  }

  // Get events for this week
  async getWeekEvents(): Promise<NativeCalendarEvent[]> {
    const startOfWeek = new Date();
    startOfWeek.setHours(0, 0, 0, 0);
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(endOfWeek.getDate() + 7);
    endOfWeek.setHours(23, 59, 59, 999);

    const calendars = await this.getAvailableCalendars();
    const calendarIds = calendars.map(cal => cal.id);

    return this.getEvents(calendarIds, startOfWeek, endOfWeek);
  }

  // Get events for this month
  async getMonthEvents(month: number, year: number): Promise<NativeCalendarEvent[]> {
    const startOfMonth = new Date(year, month - 1, 1);
    const endOfMonth = new Date(year, month, 0, 23, 59, 59, 999);

    const calendars = await this.getAvailableCalendars();
    const calendarIds = calendars.map(cal => cal.id);

    return this.getEvents(calendarIds, startOfMonth, endOfMonth);
  }

  // Sync events from Supabase to local calendar
  async syncFromSupabase(): Promise<void> {
    try {
      const { data: events } = await supabaseDataService.getFamilyEvents();
      if (!events) return;

      // For each event from Supabase, ensure it exists in device calendar
      // This is a basic implementation - in production, you'd want more sophisticated sync logic
    } catch (error) {
      console.error('Failed to sync events from Supabase:', error);
    }
  }

  // Push local events to Supabase
  async pushToSupabase(calendarId: string, events: NativeCalendarEvent[]): Promise<void> {
    try {
      const familyId = await AsyncStorage.getItem(STORAGE_KEYS.FAMILY_ID);
      if (!familyId) return;

      for (const event of events) {
        await supabaseDataService.createFamilyEvent({
          family_id: familyId,
          event_identifier: event.id,
          calendar_id: calendarId,
          is_shared_calendar_event: false,
          is_important: false,
          driver_id: null,
          driver_family_member_id: null,
        });
      }
    } catch (error) {
      console.error('Failed to push events to Supabase:', error);
    }
  }

  // Find events matching a search query
  async searchEvents(query: string, startDate: Date, endDate: Date): Promise<NativeCalendarEvent[]> {
    const events = await this.getWeekEvents();
    const lowerQuery = query.toLowerCase();

    return events.filter(event => 
      event.title.toLowerCase().includes(lowerQuery) ||
      event.location?.toLowerCase().includes(lowerQuery) ||
      event.notes?.toLowerCase().includes(lowerQuery)
    );
  }

  // Get the family calendar ID
  getFamilyCalendarId(): string | null {
    return this.familyCalendarId;
  }

  // Check if service is initialized
  isReady(): boolean {
    return this.isInitialized;
  }
}

export const calendarService = new CalendarService();
export default calendarService;
