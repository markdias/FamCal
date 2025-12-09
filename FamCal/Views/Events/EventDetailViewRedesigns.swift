//
//  EventDetailViewRedesigns.swift
//  FamCal
//
//  Created by Claude on 2025-12-09.
//  Design alternatives for EventDetailView
//

import SwiftUI
import EventKit

// MARK: - Option 1: Card-Based Compact Design
/// Consolidates information into fewer, denser cards to reduce scrolling
struct EventDetailCompactDesign: View {
    let event: UpcomingCalendarEvent

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title Card
                VStack(alignment: .leading, spacing: 12) {
                    Text(event.title)
                        .font(.system(size: 28, weight: .bold))

                    // Date & Time in one compact row
                    HStack(spacing: 20) {
                        Label {
                            Text(formatDate(event.startDate))
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                        }

                        Label {
                            Text("\(formatTime(event.startDate)) – \(formatTime(event.endDate))")
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.subheadline)

                    // Location if exists
                    if let location = event.location, !location.isEmpty {
                        Label {
                            Text(location)
                        } icon: {
                            Image(systemName: "location.fill")
                                .foregroundColor(.red)
                        }
                        .font(.subheadline)
                    }

                    // Recurring event indicator
                    if event.hasRecurrence {
                        Label {
                            Text("Repeats weekly")
                        } icon: {
                            Image(systemName: "repeat")
                                .foregroundColor(.purple)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Map preview (if location exists)
                if let location = event.location, !location.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)

                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "map.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("Map Preview")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                            .cornerRadius(12)
                    }
                }

                // Quick Actions Card (Calendar, Driver, Alert in one card)
                VStack(spacing: 0) {
                    quickActionRow(icon: "calendar.badge.clock", title: "Calendar", value: event.calendarTitle, color: Color(uiColor: event.calendarColor))
                    Divider().padding(.leading, 44)
                    quickActionRow(icon: "car.fill", title: "Driver", value: "None", color: .gray)
                    Divider().padding(.leading, 44)
                    quickActionRow(icon: "bell.fill", title: "Alert", value: "15 min before", color: .orange)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Checklist Card (if exists)
                checklistCard

                // Actions
                Button("Delete Event") {
                    // Delete action
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func quickActionRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Checklist")
                    .font(.headline)
                Spacer()
                Text("3/5")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }

            VStack(spacing: 8) {
                checklistItemRow(title: "Buy decorations", completed: false)
                checklistItemRow(title: "Send invitations", completed: true)
                checklistItemRow(title: "Book venue", completed: false)
            }

            Button(action: {}) {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func checklistItemRow(title: String, completed: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(completed ? .green : .gray)
            Text(title)
                .strikethrough(completed)
                .foregroundColor(completed ? .secondary : .primary)
            Spacer()
        }
        .font(.subheadline)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Option 2: Timeline Design
/// Vertical timeline layout with minimal padding and visual flow
struct EventDetailTimelineDesign: View {
    let event: UpcomingCalendarEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(event.title)
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                // Timeline items
                timelineItem(icon: "calendar", color: .blue, title: "When") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatFullDate(event.startDate))
                            .font(.subheadline)
                        Text("\(formatTime(event.startDate)) – \(formatTime(event.endDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let location = event.location, !location.isEmpty {
                    timelineItem(icon: "location.fill", color: .red, title: "Where") {
                        Text(location)
                            .font(.subheadline)
                    }
                }

                timelineItem(icon: "person.crop.circle", color: .purple, title: "Calendar") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(uiColor: event.calendarColor))
                            .frame(width: 12, height: 12)
                        Text(event.calendarTitle)
                            .font(.subheadline)
                    }
                }

                timelineItem(icon: "car.fill", color: .green, title: "Driver") {
                    Text("Not assigned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                timelineItem(icon: "bell.fill", color: .orange, title: "Alert") {
                    Text("15 minutes before")
                        .font(.subheadline)
                }

                timelineItem(icon: "checkmark.square", color: .indigo, title: "Checklist", isLast: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("3 of 5 completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        VStack(spacing: 6) {
                            checklistRow("Buy decorations", false)
                            checklistRow("Send invitations", true)
                            checklistRow("Book venue", false)
                        }

                        Button("+ Add Item") {
                            // Add action
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func timelineItem<Content: View>(
        icon: String,
        color: Color,
        title: String,
        isLast: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .frame(width: 10)
            .padding(.top, 6)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)

                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                content()
                    .padding(.bottom, isLast ? 0 : 20)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func checklistRow(_ title: String, _ completed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(completed ? .green : .gray)
            Text(title)
                .font(.caption)
                .strikethrough(completed)
                .foregroundColor(completed ? .secondary : .primary)
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Option 3: Grid Layout Design
/// Uses a 2-column grid for efficiency, hero image area at top
struct EventDetailGridDesign: View {
    let event: UpcomingCalendarEvent

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero section with title and key info
                VStack(alignment: .leading, spacing: 12) {
                    Text(event.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 16) {
                        Label(formatDate(event.startDate), systemImage: "calendar")
                        Label(formatTime(event.startDate), systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color(uiColor: event.calendarColor), Color(uiColor: event.calendarColor).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // Grid content
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    if let location = event.location, !location.isEmpty {
                        gridCard(icon: "location.fill", title: "Location", value: location, color: .red, fullWidth: true)
                    }

                    gridCard(icon: "calendar.badge.clock", title: "Calendar", value: event.calendarTitle, color: Color(uiColor: event.calendarColor))
                    gridCard(icon: "car.fill", title: "Driver", value: "None", color: .green)
                    gridCard(icon: "bell.fill", title: "Alert", value: "15 min", color: .orange)
                    gridCard(icon: "repeat", title: "Repeat", value: "Never", color: .purple)
                }
                .padding()

                // Checklist (full width)
                checklistSection
                    .padding(.horizontal)

                Spacer(minLength: 20)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func gridCard(icon: String, title: String, value: String, color: Color, fullWidth: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(fullWidth ? 2 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .modifier(FullWidthModifier(isFullWidth: fullWidth))
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Checklist", systemImage: "checkmark.square")
                    .font(.headline)
                Spacer()
                Text("3/5")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }

            ForEach(0..<3) { _ in
                HStack {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                    Text("Sample item")
                        .font(.subheadline)
                    Spacer()
                }
            }

            Button("+ Add Item") {}
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct FullWidthModifier: ViewModifier {
    let isFullWidth: Bool

    func body(content: Content) -> some View {
        if isFullWidth {
            content
                .gridCellColumns(2)
        } else {
            content
        }
    }
}

// MARK: - Option 4: Tabbed Interface
/// Splits information into tabs to reduce vertical scrolling
struct EventDetailTabbedDesign: View {
    let event: UpcomingCalendarEvent
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.system(size: 28, weight: .bold))

                HStack(spacing: 12) {
                    Label(formatDate(event.startDate), systemImage: "calendar")
                    Label(formatTime(event.startDate), systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Details").tag(0)
                Text("Checklist").tag(1)
                Text("Settings").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab Content
            TabView(selection: $selectedTab) {
                // Details Tab
                ScrollView {
                    VStack(spacing: 16) {
                        detailRow(icon: "location.fill", title: "Location", value: event.location ?? "No location")
                        detailRow(icon: "calendar.badge.clock", title: "Calendar", value: event.calendarTitle)
                        detailRow(icon: "car.fill", title: "Driver", value: "Not assigned")
                        detailRow(icon: "bell.fill", title: "Alert", value: "15 minutes before")
                    }
                    .padding()
                }
                .tag(0)

                // Checklist Tab
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<5) { _ in
                            HStack {
                                Image(systemName: "circle")
                                Text("Checklist item")
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                        }

                        Button("+ Add Item") {}
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                    }
                    .padding()
                }
                .tag(1)

                // Settings Tab
                ScrollView {
                    VStack(spacing: 16) {
                        Button("Edit Event") {}
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                        Button("Duplicate Event") {}
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)

                        Button("Delete Event") {}
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                    }
                    .padding()
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Previews
#Preview("Option 1: Compact") {
    EventDetailCompactDesign(
        event: UpcomingCalendarEvent(
            id: "1",
            title: "Team Lunch",
            location: "The Good Fork Restaurant",
            meetingLink: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarID: "cal1",
            calendarColor: UIColor.systemBlue,
            calendarTitle: "Work",
            hasRecurrence: false,
            recurrenceRule: nil,
            isAllDay: false
        )
    )
}

#Preview("Option 2: Timeline") {
    EventDetailTimelineDesign(
        event: UpcomingCalendarEvent(
            id: "1",
            title: "Team Lunch",
            location: "The Good Fork Restaurant",
            meetingLink: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarID: "cal1",
            calendarColor: UIColor.systemBlue,
            calendarTitle: "Work",
            hasRecurrence: false,
            recurrenceRule: nil,
            isAllDay: false
        )
    )
}

#Preview("Option 3: Grid") {
    EventDetailGridDesign(
        event: UpcomingCalendarEvent(
            id: "1",
            title: "Team Lunch",
            location: "The Good Fork Restaurant",
            meetingLink: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarID: "cal1",
            calendarColor: UIColor.systemBlue,
            calendarTitle: "Work",
            hasRecurrence: false,
            recurrenceRule: nil,
            isAllDay: false
        )
    )
}

#Preview("Option 4: Tabbed") {
    EventDetailTabbedDesign(
        event: UpcomingCalendarEvent(
            id: "1",
            title: "Team Lunch",
            location: "The Good Fork Restaurant",
            meetingLink: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarID: "cal1",
            calendarColor: UIColor.systemBlue,
            calendarTitle: "Work",
            hasRecurrence: false,
            recurrenceRule: nil,
            isAllDay: false
        )
    )
}
