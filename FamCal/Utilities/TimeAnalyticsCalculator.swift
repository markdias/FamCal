//
//  TimeAnalyticsCalculator.swift
//  FamCal
//
//  Calculates daily time analytics for family members
//

import Foundation

/// Represents analytics for a single member's day
struct TimeAnalytics {
    let date: Date                      // Which day these analytics are for
    let memberID: UUID                  // Which member
    let totalAvailableMinutes: Int      // wake to bed (e.g., 15 hours = 900 mins)
    let busyMinutes: Int                // time in events (non-overlapping)
    let freeMinutes: Int                // available - busy
    let freePercentage: Int             // (free / available) * 100
    let gaps: [TimeGap]                 // free time blocks
    let busyBlocks: [BusyBlock]         // busy time blocks
    let longestGap: TimeGap?            // largest free block
    let wakeTime: Date                  // Wake time for this day
    let bedTime: Date                   // Bed time for this day
}

/// Represents a free time block
struct TimeGap: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let durationMinutes: Int

    var formattedDuration: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

/// Represents a busy time block (may contain multiple overlapping events)
struct BusyBlock: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let durationMinutes: Int
    let eventTitles: [String]  // Multiple if overlapping
}

/// Main calculator for daily time analytics
class TimeAnalyticsCalculator {

    /// Main calculation method
    /// - Parameters:
    ///   - memberID: UUID of the family member
    ///   - date: The date to analyze (time component ignored, uses start of day)
    ///   - wakeTime: Tuple of (hour: Int, minute: Int) for wake time
    ///   - bedTime: Tuple of (hour: Int, minute: Int) for bed time
    ///   - events: All events for the member (will be filtered to date)
    /// - Returns: TimeAnalytics struct with all calculated metrics
    func calculate(
        for memberID: UUID,
        date: Date,
        wakeTime: (hour: Int, minute: Int),
        bedTime: (hour: Int, minute: Int),
        events: [UpcomingCalendarEvent]
    ) -> TimeAnalytics {

        let calendar = Calendar.current

        // Get start of day for date normalization
        let dayStart = calendar.startOfDay(for: date)

        // Create wake and bed Date objects for this specific day
        let wakeDate = calendar.date(bySettingHour: wakeTime.hour, minute: wakeTime.minute, second: 0, of: dayStart)!
        let bedDate = calendar.date(bySettingHour: bedTime.hour, minute: bedTime.minute, second: 0, of: dayStart)!

        // Calculate total available time in minutes
        let totalAvailableMinutes = Int(bedDate.timeIntervalSince(wakeDate) / 60)

        // Filter events to this day, excluding all-day events
        let relevantEvents = filterEvents(events, for: date)

        // Consolidate overlapping events into busy blocks
        let busyBlocks = consolidateBusyBlocks(relevantEvents, wakeTime: wakeDate, bedTime: bedDate)

        // Calculate total busy minutes
        let busyMinutes = busyBlocks.reduce(0) { $0 + $1.durationMinutes }

        // Calculate free time
        let freeMinutes = max(0, totalAvailableMinutes - busyMinutes)
        let freePercentage = totalAvailableMinutes > 0 ? (freeMinutes * 100) / totalAvailableMinutes : 0

        // Calculate gaps between busy blocks
        let gaps = calculateGaps(busyBlocks: busyBlocks, wakeTime: wakeDate, bedTime: bedDate)

        // Find longest gap
        let longestGap = gaps.max { $0.durationMinutes < $1.durationMinutes }

        return TimeAnalytics(
            date: date,
            memberID: memberID,
            totalAvailableMinutes: totalAvailableMinutes,
            busyMinutes: busyMinutes,
            freeMinutes: freeMinutes,
            freePercentage: freePercentage,
            gaps: gaps,
            busyBlocks: busyBlocks,
            longestGap: longestGap,
            wakeTime: wakeDate,
            bedTime: bedDate
        )
    }

    /// Filter events to specific date, excluding all-day events
    private func filterEvents(_ events: [UpcomingCalendarEvent], for date: Date) -> [UpcomingCalendarEvent] {
        let calendar = Calendar.current

        return events.filter { event in
            // Exclude all-day events (per requirements)
            guard !event.isAllDay else { return false }

            // Include if event starts or ends on this date
            let eventStartsToday = calendar.isDate(event.startDate, inSameDayAs: date)
            let eventEndsToday = calendar.isDate(event.endDate, inSameDayAs: date)

            return eventStartsToday || eventEndsToday
        }
    }

    /// Consolidate overlapping events into busy blocks
    /// Also clamps events to wake/bed window
    private func consolidateBusyBlocks(
        _ events: [UpcomingCalendarEvent],
        wakeTime: Date,
        bedTime: Date
    ) -> [BusyBlock] {
        guard !events.isEmpty else { return [] }

        // Sort events by start time
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        var blocks: [BusyBlock] = []
        var currentStart = sortedEvents[0].startDate
        var currentEnd = sortedEvents[0].endDate
        var currentTitles = [sortedEvents[0].title]

        // Clamp first event to wake/bed window
        currentStart = max(currentStart, wakeTime)
        currentEnd = min(currentEnd, bedTime)

        for event in sortedEvents.dropFirst() {
            let eventStart = max(event.startDate, wakeTime)
            let eventEnd = min(event.endDate, bedTime)

            // Skip events entirely outside wake/bed window
            guard eventStart < bedTime && eventEnd > wakeTime else { continue }

            // Check if this event overlaps with current block
            if eventStart <= currentEnd {
                // Overlapping - extend current block
                currentEnd = max(currentEnd, eventEnd)
                currentTitles.append(event.title)
            } else {
                // No overlap - save current block and start new one
                let duration = Int(currentEnd.timeIntervalSince(currentStart) / 60)
                if duration > 0 {
                    blocks.append(BusyBlock(
                        start: currentStart,
                        end: currentEnd,
                        durationMinutes: duration,
                        eventTitles: currentTitles
                    ))
                }

                currentStart = eventStart
                currentEnd = eventEnd
                currentTitles = [event.title]
            }
        }

        // Add final block
        let duration = Int(currentEnd.timeIntervalSince(currentStart) / 60)
        if duration > 0 {
            blocks.append(BusyBlock(
                start: currentStart,
                end: currentEnd,
                durationMinutes: duration,
                eventTitles: currentTitles
            ))
        }

        return blocks
    }

    /// Calculate free time gaps between busy blocks
    private func calculateGaps(
        busyBlocks: [BusyBlock],
        wakeTime: Date,
        bedTime: Date
    ) -> [TimeGap] {
        var gaps: [TimeGap] = []

        guard !busyBlocks.isEmpty else {
            // No events - entire day is free
            let duration = Int(bedTime.timeIntervalSince(wakeTime) / 60)
            return [TimeGap(start: wakeTime, end: bedTime, durationMinutes: duration)]
        }

        // Gap before first event
        let firstBlock = busyBlocks[0]
        if firstBlock.start > wakeTime {
            let duration = Int(firstBlock.start.timeIntervalSince(wakeTime) / 60)
            gaps.append(TimeGap(start: wakeTime, end: firstBlock.start, durationMinutes: duration))
        }

        // Gaps between events
        for i in 0..<(busyBlocks.count - 1) {
            let gap = TimeGap(
                start: busyBlocks[i].end,
                end: busyBlocks[i + 1].start,
                durationMinutes: Int(busyBlocks[i + 1].start.timeIntervalSince(busyBlocks[i].end) / 60)
            )
            gaps.append(gap)
        }

        // Gap after last event
        let lastBlock = busyBlocks[busyBlocks.count - 1]
        if lastBlock.end < bedTime {
            let duration = Int(bedTime.timeIntervalSince(lastBlock.end) / 60)
            gaps.append(TimeGap(start: lastBlock.end, end: bedTime, durationMinutes: duration))
        }

        return gaps
    }
}
