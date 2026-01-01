import { useState, useEffect, useCallback } from 'react';
import { EventWithDetails, GroupedEvent, RecurrenceChip, MemberEventGroup } from '@/types';
import supabaseDataService from '@/services/supabase/SupabaseDataService';
import { useFamilyData } from './useFamilyData';
import { useCalendar } from './useCalendar';
import { useEventsPerPerson } from './useAppSettings';
import { format, parseISO, addDays, isSameDay } from 'date-fns';

export function useEvents() {
  const { isLoading, error, members, getCurrentMember } = useFamilyData();
  const { events, loadEvents, isLoading: calendarLoading } = useCalendar();
  const eventsPerPerson = useEventsPerPerson();
  
  const [groupedEvents, setGroupedEvents] = useState<MemberEventGroup[]>([]);
  const [isLoadingEvents, setIsLoadingEvents] = useState(false);

  // Get next events for each family member
  const getNextEvents = useCallback(async (): Promise<GroupedEvent[]> => {
    const now = new Date();
    const memberEventGroups = await buildMemberEventGroups(
      members,
      events,
      eventsPerPerson,
      now
    );

    const nextEvents: GroupedEvent[] = [];
    memberEventGroups.forEach(group => {
      if (group.nextEvent) {
        nextEvents.push(group.nextEvent);
      }
    });

    return nextEvents;
  }, [members, events, eventsPerPerson]);

  // Build member event groups (next events + upcoming events with chips)
  const buildMemberEventGroups = useCallback(async (
    familyMembers: typeof members,
    calendarEvents: typeof events,
    limitPerPerson: number,
    now: Date
  ): Promise<MemberEventGroup[]> => {
    const memberGroups: MemberEventGroup[] = [];

    for (const member of familyMembers) {
      // Filter events for this member's calendars
      const memberEvents = calendarEvents.filter(event => {
        // In a real app, we'd check if the event belongs to one of the member's calendars
        return true; // Simplified for now
      });

      // Sort by start date
      const sortedEvents = memberEvents.sort((a, b) => {
        const dateA = new Date(a.startDate);
        const dateB = new Date(b.startDate);
        return dateA.getTime() - dateB.getTime();
      });

      // Filter future events only
      const futureEvents = sortedEvents.filter(event => new Date(event.startDate) >= now);

      // Build grouped events with recurrence chips
      const groupedEvents = await buildGroupedEventsWithChips(
        futureEvents,
        calendarEvents,
        limitPerPerson
      );

      memberGroups.push({
        id: member.id,
        memberName: member.name || 'Unknown',
        memberColor: member.colorHex || '#007AFF',
        nextEvent: groupedEvents[0] || null,
        upcomingEvents: groupedEvents,
      });
    }

    // Sort groups by next event time
    return memberGroups.sort((a, b) => {
      if (!a.nextEvent && !b.nextEvent) return 0;
      if (!a.nextEvent) return 1;
      if (!b.nextEvent) return -1;
      return new Date(a.nextEvent.startDate).getTime() - new Date(b.nextEvent.startDate).getTime();
    });
  }, []);

  // Build grouped events with recurrence chips
  const buildGroupedEventsWithChips = useCallback(async (
    futureEvents: typeof events,
    allEvents: typeof events,
    limit: number
  ): Promise<GroupedEvent[]> => {
    const result: GroupedEvent[] = [];
    let eventCount = 0;

    for (const event of futureEvents) {
      if (eventCount >= limit) break;

      const groupedEvent = await buildGroupedEvent(event, allEvents, 5);
      result.push(groupedEvent);
      eventCount++;
    }

    return result;
  }, []);

  // Build a single grouped event with recurrence chips
  const buildGroupedEvent = useCallback(async (
    event: typeof events[0],
    allEvents: typeof events[],
    chipLimit: number
  ): Promise<GroupedEvent> => {
    const startDate = new Date(event.startDate);
    const endDate = new Date(event.endDate);

    // Generate recurrence chips if event is recurring
    const recurrenceChips: RecurrenceChip[] = [];
    const timeRange = format(startDate, 'h:mm a') + ' – ' + format(endDate, 'h:mm a');

    if (event.recurrenceRule) {
      // Calculate next occurrences
      const nextOccurrences = calculateNextOccurrences(
        event,
        allEvents,
        chipLimit
      );

      recurrenceChips.push(...nextOccurrences);
    }

    return {
      id: event.id,
      title: event.title,
      timeRange,
      location: event.location || null,
      startDate: event.startDate,
      endDate: event.endDate,
      memberNames: ['Member'], // Would be populated from attendee data
      memberColor: '#007AFF',
      calendarTitle: '',
      hasRecurrence: !!event.recurrenceRule,
      recurrenceRule: event.recurrenceRule || null,
      memberColors: ['#007AFF'],
      recurrenceChips,
    };
  }, []);

  // Calculate next recurrence occurrences
  const calculateNextOccurrences = (
    baseEvent: typeof events[0],
    allEvents: typeof events[],
    limit: number
  ): RecurrenceChip[] => {
    const chips: RecurrenceChip[] = [];
    const baseDate = new Date(baseEvent.startDate);
    const currentDate = addDays(baseDate, 1);

    // Find when this recurring event should stop (next different event)
    const differentEvents = allEvents.filter(e => {
      const eventDate = new Date(e.startDate);
      return eventDate > baseDate && e.title !== baseEvent.title;
    });

    const stopDate = differentEvents.length > 0
      ? new Date(differentEvents[0].startDate)
      : addDays(baseDate, 365);

    let count = 0;
    while (count < limit) {
      // Calculate next occurrence based on recurrence rule
      const nextDate = getNextOccurrenceDate(baseDate, baseEvent.recurrenceRule || '');

      if (!nextDate || nextDate >= stopDate) break;

      if (nextDate > baseDate) {
        chips.push({
          id: `chip_${nextDate.toISOString()}`,
          date: nextDate.toISOString(),
          label: format(nextDate, 'EEE d MMM'),
        });
        count++;
      }
    }

    return chips;
  };

  // Get next occurrence date based on recurrence rule
  const getNextOccurrenceDate = (baseDate: Date, rule: string): Date | null => {
    if (!rule) return null;

    // Simple recurrence parsing
    const freqMatch = rule.match(/FREQ=(\w+)/);
    const intervalMatch = rule.match(/INTERVAL=(\d+)/);
    
    const frequency = freqMatch?.[1]?.toLowerCase() || 'daily';
    const interval = parseInt(intervalMatch?.[1] || '1', 10);

    const nextDate = new Date(baseDate);

    switch (frequency) {
      case 'daily':
        nextDate.setDate(nextDate.getDate() + interval);
        break;
      case 'weekly':
        nextDate.setDate(nextDate.getDate() + (interval * 7));
        break;
      case 'monthly':
        nextDate.setMonth(nextDate.getMonth() + interval);
        break;
      case 'yearly':
        nextDate.setFullYear(nextDate.getFullYear() + interval);
        break;
      default:
        return null;
    }

    return nextDate;
  };

  // Load events for a date range
  const loadEventsForDateRange = useCallback(async (
    startDate: Date,
    endDate: Date
  ) => {
    setIsLoadingEvents(true);
    try {
      // Get all calendar IDs
      const calendarIds = events.map(e => e.calendarId);
      await loadEvents(calendarIds, startDate, endDate);
    } finally {
      setIsLoadingEvents(false);
    }
  }, [events, loadEvents]);

  // Search events
  const searchEvents = useCallback(async (query: string): Promise<EventWithDetails[]> => {
    try {
      const { data } = await supabaseDataService.searchEvents(query);
      return (data as unknown as EventWithDetails[]) || [];
    } catch (err) {
      console.error('Search events error:', err);
      return [];
    }
  }, []);

  return {
    isLoading: isLoading || calendarLoading || isLoadingEvents,
    error,
    events,
    groupedEvents,
    getNextEvents,
    loadEventsForDateRange,
    searchEvents,
    buildMemberEventGroups,
  };
}
