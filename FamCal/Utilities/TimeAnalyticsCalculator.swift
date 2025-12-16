//
//  TimeAnalyticsCalculator.swift
//  FamCal
//
//  Calculates daily time analytics for family members
//

import Foundation
import UIKit

/// Represents analytics for a single member's day
struct TimeAnalytics {
    let date: Date                      // Which day these analytics are for
    let memberID: UUID                  // Which member
    let totalAvailableMinutes: Int      // wake to bed (e.g., 15 hours = 900 mins)
    let busyMinutes: Int                // time in events (non-overlapping)
    let travelMinutes: Int              // time in travel (non-overlapping, clamped to day)
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
    let travelDurationMinutes: Int
    let eventTitles: [String]  // Multiple if overlapping
    let calendarColors: [UIColor]  // Color from each event's calendar
    let isFree: Bool
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

        // Create busy blocks from events (don't merge overlapping - show all events)
        let busyBlocks = createBusyBlocks(from: relevantEvents, wakeTime: wakeDate, bedTime: bedDate)
        let busyOnlyBlocks = busyBlocks.filter { !$0.isFree }

        // Calculate travel minutes (merged so overlapping travel isn't double-counted)
        let travelMinutes = calculateTravelMinutes(relevantEvents, wakeTime: wakeDate, bedTime: bedDate)

        // Calculate total busy minutes (count overlapping time only once)
        let busyMinutes = calculateBusyMinutes(busyBlocks)

        // Calculate free time
        let freeMinutes = max(0, totalAvailableMinutes - busyMinutes)
        let freePercentage = totalAvailableMinutes > 0 ? (freeMinutes * 100) / totalAvailableMinutes : 0

        // Consolidate blocks for gap calculation (to count gaps correctly with overlaps)
        let mergedForGaps = consolidateBusyBlocksForGaps(busyOnlyBlocks)

        // Calculate gaps between busy blocks
        let gaps = calculateGaps(busyBlocks: mergedForGaps, wakeTime: wakeDate, bedTime: bedDate)

        // Find longest gap
        let longestGap = gaps.max { $0.durationMinutes < $1.durationMinutes }

        return TimeAnalytics(
            date: date,
            memberID: memberID,
            totalAvailableMinutes: totalAvailableMinutes,
            busyMinutes: busyMinutes,
            travelMinutes: travelMinutes,
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

    /// Create a BusyBlock for each event (don't merge overlapping)
    /// Includes travel time as busy time, clamped to wake/bed window
    private func createBusyBlocks(
        from events: [UpcomingCalendarEvent],
        wakeTime: Date,
        bedTime: Date
    ) -> [BusyBlock] {
        struct ClampedEvent {
            let id: String
            let start: Date
            let end: Date
            let title: String
            let color: UIColor
            let travelDurationMinutes: Int
            let isFree: Bool
        }

        let clampedEvents: [ClampedEvent] = events
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event in
                let isFree = event.showAs == .free
                let travelMinutes = max(0, event.travelTimeMinutes ?? 0)
                let travelStart = event.startDate.addingTimeInterval(TimeInterval(-travelMinutes * 60))
                let clampedStart = max(travelStart, wakeTime)
                let clampedEnd = min(event.endDate, bedTime)

                // Skip events entirely outside wake/bed window
                guard clampedStart < bedTime && clampedEnd > wakeTime else { return nil }

                let duration = Int(clampedEnd.timeIntervalSince(clampedStart) / 60)
                guard duration > 0 else { return nil }

                let travelPortionEnd = min(event.startDate, clampedEnd)
                let travelIncludedMinutes = max(0, Int(travelPortionEnd.timeIntervalSince(clampedStart) / 60))

                return ClampedEvent(
                    id: event.id,
                    start: clampedStart,
                    end: clampedEnd,
                    title: event.title,
                    color: event.calendarColor,
                    travelDurationMinutes: isFree ? 0 : min(duration, travelIncludedMinutes),
                    isFree: isFree
                )
            }

        return clampedEvents.map { clamped in
            // Collect colors for all overlapping events so timeline can render gradients
            let overlappingColors = clampedEvents
                .filter { $0.id != clamped.id && $0.start < clamped.end && $0.end > clamped.start }
                .map { $0.color }

            let orderedColors = uniqueColorsPreservingOrder([clamped.color] + overlappingColors)
            let duration = Int(clamped.end.timeIntervalSince(clamped.start) / 60)

            return BusyBlock(
                start: clamped.start,
                end: clamped.end,
                durationMinutes: duration,
                travelDurationMinutes: clamped.travelDurationMinutes,
                eventTitles: [clamped.title],
                calendarColors: orderedColors,
                isFree: clamped.isFree
            )
        }
    }

    private func uniqueColorsPreservingOrder(_ colors: [UIColor]) -> [UIColor] {
        var seen: [UIColor] = []
        for color in colors {
            if !seen.contains(where: { $0.isEqual(color) }) {
                seen.append(color)
            }
        }
        return seen
    }

    /// Calculate total travel minutes (merged to avoid double-counting overlaps)
    private func calculateTravelMinutes(
        _ events: [UpcomingCalendarEvent],
        wakeTime: Date,
        bedTime: Date
    ) -> Int {
        let travelIntervals: [(Date, Date)] = events.compactMap { event in
            guard event.showAs != .free else { return nil }
            guard let travelMinutes = event.travelTimeMinutes, travelMinutes > 0 else { return nil }
            let rawStart = event.startDate.addingTimeInterval(TimeInterval(-travelMinutes * 60))
            let start = max(rawStart, wakeTime)
            let end = min(event.startDate, bedTime)
            guard start < end else { return nil }
            return (start, end)
        }

        let mergedIntervals = mergeIntervals(travelIntervals)
        return mergedIntervals.reduce(0) { partialResult, interval in
            partialResult + Int(interval.1.timeIntervalSince(interval.0) / 60)
        }
    }

    private func mergeIntervals(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        guard !intervals.isEmpty else { return [] }

        let sorted = intervals.sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = []

        var currentStart = sorted[0].0
        var currentEnd = sorted[0].1

        for interval in sorted.dropFirst() {
            if interval.0 <= currentEnd {
                currentEnd = max(currentEnd, interval.1)
            } else {
                merged.append((currentStart, currentEnd))
                currentStart = interval.0
                currentEnd = interval.1
            }
        }

        merged.append((currentStart, currentEnd))
        return merged
    }

    /// Consolidate busy blocks (merge overlapping) for gap calculation
    /// This gives accurate gaps even when events overlap
    private func consolidateBusyBlocksForGaps(_ blocks: [BusyBlock]) -> [BusyBlock] {
        guard !blocks.isEmpty else { return [] }

        let sorted = blocks.sorted { $0.start < $1.start }
        var consolidated: [BusyBlock] = []
        var currentStart = sorted[0].start
        var currentEnd = sorted[0].end
        var currentTitles = sorted[0].eventTitles
        var currentColors = sorted[0].calendarColors
        var currentTravel = sorted[0].travelDurationMinutes

        for block in sorted.dropFirst() {
            if block.start <= currentEnd {
                // Overlapping - extend
                currentEnd = max(currentEnd, block.end)
                currentTitles.append(contentsOf: block.eventTitles)
                currentColors.append(contentsOf: block.calendarColors)
                currentTravel += block.travelDurationMinutes
            } else {
                // No overlap - save and start new
                let duration = Int(currentEnd.timeIntervalSince(currentStart) / 60)
                if duration > 0 {
                    consolidated.append(BusyBlock(
                        start: currentStart,
                        end: currentEnd,
                        durationMinutes: duration,
                        travelDurationMinutes: min(duration, currentTravel),
                        eventTitles: currentTitles,
                        calendarColors: currentColors,
                        isFree: false
                    ))
                }
                currentStart = block.start
                currentEnd = block.end
                currentTitles = block.eventTitles
                currentColors = block.calendarColors
                currentTravel = block.travelDurationMinutes
            }
        }

        // Add final block
        let duration = Int(currentEnd.timeIntervalSince(currentStart) / 60)
        if duration > 0 {
            consolidated.append(BusyBlock(
                start: currentStart,
                end: currentEnd,
                durationMinutes: duration,
                travelDurationMinutes: min(duration, currentTravel),
                eventTitles: currentTitles,
                calendarColors: currentColors,
                isFree: false
            ))
        }

        return consolidated
    }

    /// Calculate total busy minutes accounting for overlaps
    /// Counts overlapping time only once
    private func calculateBusyMinutes(_ blocks: [BusyBlock]) -> Int {
        let busyBlocks = blocks.filter { !$0.isFree }
        guard !busyBlocks.isEmpty else { return 0 }
        let mergedBlocks = consolidateBusyBlocksForGaps(busyBlocks)
        return mergedBlocks.reduce(0) { $0 + $1.durationMinutes }
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
