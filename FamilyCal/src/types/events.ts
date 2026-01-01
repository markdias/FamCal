// Event-related types for FamilyCal

import { CalendarEvent as NativeCalendarEvent } from './index';

export interface EventFormData {
  title: string;
  startDate: Date;
  endDate: Date;
  isAllDay: boolean;
  location: string | null;
  notes: string | null;
  recurrenceRule: string | null;
  alertMinutes: number | null;
  attendeeIds: string[];
  calendarId: string;
  isImportant: boolean;
}

export interface EventFormErrors {
  title?: string;
  startDate?: string;
  endDate?: string;
  location?: string;
  attendees?: string;
}

export interface RecurrenceRule {
  frequency: 'daily' | 'weekly' | 'monthly' | 'yearly';
  interval: number;
  byDay?: string[];
  byMonthDay?: number[];
  byYearDay?: number[];
  count?: number;
  until?: string;
}

export interface RecurrenceOptions {
  frequency: 'daily' | 'weekly' | 'monthly' | 'yearly';
  interval: number;
  daysOfWeek?: number[];
  endType: 'never' | 'afterCount' | 'untilDate';
  count?: number;
  untilDate?: Date;
}

export interface EventNotification {
  id: string;
  eventId: string;
  triggerDate: string;
  isScheduled: boolean;
}

export interface EventFilters {
  startDate: Date | null;
  endDate: Date | null;
  memberIds: string[];
  calendarIds: string[];
  searchQuery: string;
  showImportantOnly: boolean;
}

export interface EventSortOption {
  field: 'startDate' | 'title' | 'createdAt';
  direction: 'asc' | 'desc';
}

export interface EventViewMode {
  type: 'day' | 'week' | 'month';
  date: Date;
}

export interface DayViewEvent {
  hour: number;
  events: NativeCalendarEvent[];
}

export interface WeekViewDay {
  date: Date;
  isToday: boolean;
  isSelected: boolean;
  events: NativeCalendarEvent[];
}

export interface MonthViewDay {
  date: Date;
  isCurrentMonth: boolean;
  isToday: boolean;
  isSelected: boolean;
  events: NativeCalendarEvent[];
}

export interface CalendarDateRange {
  startDate: Date;
  endDate: Date;
}

export const RECURRENCE_FREQUENCIES = [
  { value: 'daily', label: 'Daily' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'monthly', label: 'Monthly' },
  { value: 'yearly', label: 'Yearly' },
] as const;

export const DAYS_OF_WEEK = [
  { value: 0, label: 'Sunday', short: 'Sun' },
  { value: 1, label: 'Monday', short: 'Mon' },
  { value: 2, label: 'Tuesday', short: 'Tue' },
  { value: 3, label: 'Wednesday', short: 'Wed' },
  { value: 4, label: 'Thursday', short: 'Thu' },
  { value: 5, label: 'Friday', short: 'Fri' },
  { value: 6, label: 'Saturday', short: 'Sat' },
] as const;

export const ALERT_OPTIONS = [
  { value: 0, label: 'At time of event' },
  { value: 5, label: '5 minutes before' },
  { value: 15, label: '15 minutes before' },
  { value: 30, label: '30 minutes before' },
  { value: 60, label: '1 hour before' },
  { value: 1440, label: '1 day before' },
] as const;
