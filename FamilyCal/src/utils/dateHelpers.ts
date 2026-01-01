import { format, formatDistanceToNow, parseISO, isToday, isTomorrow, isYesterday, addDays, addHours, differenceInMinutes } from 'date-fns';

// Date formatting utilities
export function formatDate(date: Date | string, formatString: string): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  return format(d, formatString);
}

export function formatDisplayDate(date: Date | string): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  
  if (isToday(d)) return 'Today';
  if (isTomorrow(d)) return 'Tomorrow';
  if (isYesterday(d)) return 'Yesterday';
  
  return format(d, "EEEE, MMM d");
}

export function formatTimeRange(startDate: Date | string, endDate: Date | string): string {
  const start = typeof startDate === 'string' ? parseISO(startDate) : startDate;
  const end = typeof endDate === 'string' ? parseISO(endDate) : endDate;
  
  const startTime = format(start, 'h:mm a');
  const endTime = format(end, 'h:mm a');
  
  return `${startTime} – ${endTime}`;
}

export function formatAllDay(date: Date | string): string {
  return format(date instanceof Date ? date : parseISO(date), 'MMM d');
}

export function getRelativeTime(date: Date | string): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  return formatDistanceToNow(d, { addSuffix: true });
}

export function getTimeUntil(date: Date | string): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  const now = new Date();
  const minutesUntil = differenceInMinutes(d, now);
  
  if (minutesUntil < 0) {
    const absMinutes = Math.abs(minutesUntil);
    if (absMinutes < 60) return `${absMinutes}m ago`;
    if (absMinutes < 1440) return `${Math.floor(absMinutes / 60)}h ago`;
    return `${Math.floor(absMinutes / 1440)}d ago`;
  }
  
  if (minutesUntil < 60) return `in ${minutesUntil}m`;
  if (minutesUntil < 1440) return `in ${Math.floor(minutesUntil / 60)}h`;
  if (minutesUntil < 2880) return `Tomorrow`;
  return `in ${Math.floor(minutesUntil / 1440)}d`;
}

// Time range utilities
export function getDayRange(date: Date): { start: Date; end: Date } {
  const start = new Date(date);
  start.setHours(0, 0, 0, 0);
  
  const end = new Date(date);
  end.setHours(23, 59, 59, 999);
  
  return { start, end };
}

export function getWeekRange(date: Date): { start: Date; end: Date } {
  const start = new Date(date);
  const dayOfWeek = start.getDay();
  start.setDate(start.getDate() - dayOfWeek);
  start.setHours(0, 0, 0, 0);
  
  const end = addDays(start, 6);
  end.setHours(23, 59, 59, 999);
  
  return { start, end };
}

export function getMonthRange(date: Date): { start: Date; end: Date } {
  const start = new Date(date);
  start.setDate(1);
  start.setHours(0, 0, 0, 0);
  
  const end = new Date(date);
  end.setMonth(end.getMonth() + 1);
  end.setDate(0);
  end.setHours(23, 59, 59, 999);
  
  return { start, end };
}

// Date manipulation utilities
export function addMinutes(date: Date, minutes: number): Date {
  return addHours(date, minutes / 60);
}

export function getStartOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function getEndOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

export function getStartOfWeek(date: Date): Date {
  const d = new Date(date);
  const dayOfWeek = d.getDay();
  d.setDate(d.getDate() - dayOfWeek);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function getEndOfWeek(date: Date): Date {
  const start = getStartOfWeek(date);
  return addDays(start, 6);
}

// Time slot utilities
export function generateTimeSlots(startHour: number = 0, endHour: number = 23): Date[] {
  const slots: Date[] = [];
  for (let hour = startHour; hour <= endHour; hour++) {
    const slot = new Date();
    slot.setHours(hour, 0, 0, 0);
    slots.push(slot);
  }
  return slots;
}

// Recurrence utilities
export function parseRecurrenceRule(rule: string): {
  frequency: string;
  interval: number;
  byDay?: string[];
} | null {
  if (!rule) return null;
  
  const parts = rule.split(';');
  const result: { frequency: string; interval: number; byDay?: string[] } = {
    frequency: 'daily',
    interval: 1,
  };
  
  for (const part of parts) {
    const [key, value] = part.split('=');
    switch (key) {
      case 'FREQ':
        result.frequency = value.toLowerCase();
        break;
      case 'INTERVAL':
        result.interval = parseInt(value, 10) || 1;
        break;
      case 'BYDAY':
        result.byDay = value.split(',');
        break;
    }
  }
  
  return result;
}

export function getNextRecurrenceDate(
  baseDate: Date,
  rule: string
): Date | null {
  const parsed = parseRecurrenceRule(rule);
  if (!parsed) return null;
  
  const { frequency, interval, byDay } = parsed;
  let nextDate = new Date(baseDate);
  
  switch (frequency) {
    case 'daily':
      nextDate = addDays(nextDate, interval);
      break;
    case 'weekly':
      nextDate = addDays(nextDate, interval * 7);
      if (byDay) {
        const currentDay = nextDate.getDay();
        const targetDays = byDay.map(d => {
          const dayMap: Record<string, number> = { 'SU': 0, 'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6 };
          return dayMap[d] ?? 0;
        });
        const daysUntil = targetDays.find(d => d > currentDay) ?? targetDays[0] + 7;
        nextDate = addDays(nextDate, daysUntil);
      }
      break;
    case 'monthly':
      nextDate.setMonth(nextDate.getMonth() + interval);
      break;
    case 'yearly':
      nextDate.setFullYear(nextDate.getFullYear() + interval);
      break;
  }
  
  return nextDate;
}
