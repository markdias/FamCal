//
//  FamilyEventsWidgetView.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import SwiftUI
import WidgetKit

struct FamilyEventsWidgetView: View {
    let entry: FamilyEventsProvider.Entry
    @Environment(\.widgetFamily) var family
    private let cardCornerRadius: CGFloat = 26

    var showTime: Bool { entry.showTime }
    var showLocation: Bool { entry.showLocation }
    var showAttendees: Bool { entry.showAttendees }
    var showDrivers: Bool { entry.showDrivers }

    var body: some View {
        Group {
            if #available(iOS 17.0, *), family == .accessoryRectangular {
                accessoryRectangularContent()
            } else {
                standardContent()
            }
        }
        .widgetBackground()
    }

    private func standardContent() -> some View {
        Group {
            if !entry.events.isEmpty {
                groupedEventList()
            } else if let error = entry.errorMessage {
                errorContent(error)
            } else {
                loadingContent()
            }
        }
    }

    @available(iOS 17.0, *)
    private func accessoryRectangularContent() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = entry.errorMessage {
                errorContent(error)
            } else if entry.events.isEmpty {
                loadingContent()
            } else {
                let events = entry.events.prefix(3)
                ForEach(events, id: \.id) { event in
                    HStack(spacing: 6) {
                        // Use calendar color instead of member color
                        Circle()
                            .fill(Color(UIColor(hex: event.calendarColorHex)))
                            .frame(width: 4, height: 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)

                            // Conditional time display
                            if showTime {
                                Text("\(Self.dateFormatter.string(from: event.startDate)) · \(Self.timeFormatter.string(from: event.startDate))–\(Self.timeFormatter.string(from: event.endDate))")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text(Self.dateFormatter.string(from: event.startDate))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            // Conditional location or attendee display
                            if showLocation, let location = event.location, !location.isEmpty {
                                Text(location)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else if showAttendees {
                                Text(event.memberName)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(baseBackground)
    }

    private func groupedEventList() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(monthGroups, id: \.monthStart) { month in
                    Text(Self.monthFormatter.string(from: month.monthStart))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(month.days, id: \.date) { day in
                            ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                                let dateLabel = index == 0 ? Self.dateHeaderFormatter.string(from: day.date) : nil
                                eventRow(event, leadingDate: dateLabel)
                            }
                        }
                    }
                    .padding(.horizontal, 16) // Increased from 8
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 16) // Added top padding
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func eventRow(_ event: EventItem, leadingDate: String? = nil) -> some View {
        let calendarColor = Color(UIColor(hex: event.calendarColorHex))
        let timeStr = Self.timeFormatter.string(from: event.startDate)
        let endTimeStr = Self.timeFormatter.string(from: event.endDate)

        return HStack(spacing: 8) {
            // Date column (52pt width, only first event of day)
            if let leadingDate {
                Text(leadingDate)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 52, alignment: .leading)
            } else {
                Spacer()
                    .frame(width: 52)
            }

            // Calendar color indicator (using calendar color, not member color)
            Circle()
                .fill(calendarColor)
                .frame(width: 4, height: 4)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    // Time (conditional based on settings)
                    if showTime {
                        Text("\(timeStr)–\(endTimeStr)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                // Member name (conditional based on settings)
                if showAttendees {
                    Text(event.memberName)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Location (conditional based on settings)
                if showLocation, let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        // Removed background(baseBackground) to be transparent/clean
    }

    private var isMedium: Bool {
        family == .systemMedium
    }

    private var maxVisibleEvents: Int {
        switch family {
        case .systemMedium:
            return 2 // Restricted to 2 as requested
        default:
            return 5 // Restricted to 5 as requested
        }
    }

    private var groupedEvents: [(date: Date, events: [EventItem])] {
        let calendar = Calendar.current
        let limited = Array(entry.events.prefix(maxVisibleEvents))
        let grouped = Dictionary(grouping: limited) { event in
            calendar.startOfDay(for: event.startDate)
        }
        return grouped
            .map { (date: $0.key, events: $0.value.sorted { $0.startDate < $1.startDate }) }
            .sorted { $0.date < $1.date }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E d MMM"
        return formatter
    }()

    private static let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    private var baseBackground: Color {
        if #available(iOS 17.0, *), family == .accessoryRectangular {
            return Color(UIColor.systemBackground)
        }
        return cardBackground
    }

    private var cardBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.08, alpha: 0.92)
                : UIColor(white: 1.0, alpha: 1.0)
        })
    }

    private var cardStroke: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
                : UIColor.black.withAlphaComponent(0.05)
        })
    }

    private var shadowColor: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.35)
                : UIColor.black.withAlphaComponent(0.12)
        })
    }

    private var monthGroups: [(monthStart: Date, days: [(date: Date, events: [EventItem])])] {
        let calendar = Calendar.current

        // group days into months
        let groups = Dictionary(grouping: groupedEvents) { item -> Date in
            let comps = calendar.dateComponents([.year, .month], from: item.date)
            return calendar.date(from: comps) ?? item.date
        }

        return groups
            .map { (monthStart: $0.key,
                    days: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.monthStart < $1.monthStart }
    }

    @ViewBuilder
    private func errorContent(_ error: String) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            Text(error)
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineLimit(3)

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func loadingContent() -> some View {
        VStack(alignment: .center, spacing: 8) {
            ProgressView()
                .tint(.blue)

            Text("Loading events...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

#Preview("Family Events - Medium") {
    let event1 = EventItem(
        id: UUID().uuidString,
        title: "Team Meeting",
        startDate: Date(timeIntervalSinceNow: 3600),
        endDate: Date(timeIntervalSinceNow: 5400),
        memberName: "John Doe",
        memberColorHex: "#007AFF",
        calendarColorHex: "#FF3B30",
        location: "Conference Room A"
    )

    let event2 = EventItem(
        id: UUID().uuidString,
        title: "Lunch Break",
        startDate: Date(timeIntervalSinceNow: 7200),
        endDate: Date(timeIntervalSinceNow: 9000),
        memberName: "Sarah Smith",
        memberColorHex: "#FF2D55",
        calendarColorHex: "#34C759",
        location: "Cafeteria"
    )

    let entry = FamilyEventsEntry(date: Date(), events: [event1, event2])

    FamilyEventsWidgetView(entry: entry)
        .preferredColorScheme(.light)
}

#Preview("Family Events - Large") {
    let event1 = EventItem(
        id: UUID().uuidString,
        title: "Team Meeting",
        startDate: Date(timeIntervalSinceNow: 3600),
        endDate: Date(timeIntervalSinceNow: 5400),
        memberName: "John Doe",
        memberColorHex: "#007AFF",
        calendarColorHex: "#FF3B30",
        location: "Conference Room A"
    )

    let event2 = EventItem(
        id: UUID().uuidString,
        title: "Lunch Break",
        startDate: Date(timeIntervalSinceNow: 7200),
        endDate: Date(timeIntervalSinceNow: 9000),
        memberName: "Sarah Smith",
        memberColorHex: "#FF2D55",
        calendarColorHex: "#34C759",
        location: "Cafeteria"
    )

    let entry = FamilyEventsEntry(date: Date(), events: [event1, event2])

    FamilyEventsWidgetView(entry: entry)
        .preferredColorScheme(.light)
}
