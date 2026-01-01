import { useState, useEffect, useCallback } from 'react';
import { NativeCalendar, NativeCalendarEvent } from '@/types';
import calendarService from '@/services/CalendarService';

export function useCalendar() {
  const [isInitialized, setIsInitialized] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [calendars, setCalendars] = useState<NativeCalendar[]>([]);
  const [events, setEvents] = useState<NativeCalendarEvent[]>([]);

  // Initialize calendar service
  useEffect(() => {
    const initialize = async () => {
      setIsLoading(true);
      try {
        const success = await calendarService.initialize();
        setIsInitialized(success);
        
        if (success) {
          const availableCalendars = await calendarService.getAvailableCalendars();
          setCalendars(availableCalendars);
        }
      } catch (err) {
        setError(err as Error);
      } finally {
        setIsLoading(false);
      }
    };

    initialize();
  }, []);

  // Load calendars
  const loadCalendars = useCallback(async () => {
    try {
      const availableCalendars = await calendarService.getAvailableCalendars();
      setCalendars(availableCalendars);
    } catch (err) {
      setError(err as Error);
    }
  }, []);

  // Load events for a date range
  const loadEvents = useCallback(async (
    calendarIds: string[],
    startDate: Date,
    endDate: Date
  ) => {
    setIsLoading(true);
    try {
      const fetchedEvents = await calendarService.getEvents(calendarIds, startDate, endDate);
      setEvents(fetchedEvents);
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Load today's events
  const loadTodayEvents = useCallback(async () => {
    setIsLoading(true);
    try {
      const todayEvents = await calendarService.getTodayEvents();
      setEvents(todayEvents);
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Load week's events
  const loadWeekEvents = useCallback(async () => {
    setIsLoading(true);
    try {
      const weekEvents = await calendarService.getWeekEvents();
      setEvents(weekEvents);
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Load month's events
  const loadMonthEvents = useCallback(async (month: number, year: number) => {
    setIsLoading(true);
    try {
      const monthEvents = await calendarService.getMonthEvents(month, year);
      setEvents(monthEvents);
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Create event
  const createEvent = useCallback(async (
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
  ) => {
    try {
      const eventId = await calendarService.createEvent(calendarId, event);
      return eventId;
    } catch (err) {
      setError(err as Error);
      return null;
    }
  }, []);

  // Update event
  const updateEvent = useCallback(async (
    eventId: string,
    updates: {
      title?: string;
      startDate?: Date;
      endDate?: Date;
      location?: string;
      notes?: string;
      allDay?: boolean;
    }
  ) => {
    try {
      const success = await calendarService.updateEvent(eventId, updates);
      return success;
    } catch (err) {
      setError(err as Error);
      return false;
    }
  }, []);

  // Delete event
  const deleteEvent = useCallback(async (eventId: string) => {
    try {
      const success = await calendarService.deleteEvent(eventId);
      return success;
    } catch (err) {
      setError(err as Error);
      return false;
    }
  }, []);

  // Search events
  const searchEvents = useCallback(async (
    query: string,
    startDate: Date,
    endDate: Date
  ) => {
    try {
      const results = await calendarService.searchEvents(query, startDate, endDate);
      return results;
    } catch (err) {
      setError(err as Error);
      return [];
    }
  }, []);

  // Check permissions
  const checkPermissions = useCallback(async () => {
    return await calendarService.checkPermissions();
  }, []);

  // Request permissions
  const requestPermissions = useCallback(async () => {
    const granted = await calendarService.requestPermissions();
    if (granted) {
      setIsInitialized(true);
    }
    return granted;
  }, []);

  return {
    isInitialized,
    isLoading,
    error,
    calendars,
    events,
    loadCalendars,
    loadEvents,
    loadTodayEvents,
    loadWeekEvents,
    loadMonthEvents,
    createEvent,
    updateEvent,
    deleteEvent,
    searchEvents,
    checkPermissions,
    requestPermissions,
  };
}
