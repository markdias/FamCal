//
//  CalendarCellPreview.swift
//  FamCal
//
//  Preview for new calendar cell design showing event titles and colors
//

import SwiftUI
import CoreData
import EventKit

/// Preview view for experimenting with calendar cell designs
/// This shows events with colors and titles instead of just dots
struct CalendarCellPreview: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: FamilyEvent.entity(),
        sortDescriptors: []
    )
    private var familyEvents: FetchedResults<FamilyEvent>

    @State private var currentDesign: DesignOption = .option1
    @State private var eventStore = EKEventStore()
    @State private var realEvents: [Date: [SampleEvent]] = [:]

    let weekdayHeaders = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    enum DesignOption: String, CaseIterable {
        case option1 = "Option 1: Pills with Color Bar"
        case option2 = "Option 2: Full Colored Pills"
        case option3 = "Option 3: Compact Text Only"
        case option4 = "Option 4: Dots + First Event"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Design picker
            Picker("Design", selection: $currentDesign) {
                ForEach(DesignOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding()

            ScrollView {
                VStack(spacing: 20) {
                    Text("December 2025")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    // Full month calendar view
                    VStack(spacing: 0) {
                        // Weekday headers
                        HStack(spacing: 0) {
                            ForEach(weekdayHeaders, id: \.self) { day in
                                Text(day)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.bottom, 8)

                        // Calendar grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            // First week - starts on Monday (Dec 1)
                            SampleCalendarCell(
                                dayNumber: nil,
                                events: [],
                                isPlaceholder: true,
                                designOption: currentDesign
                            )
                            ForEach(1...6, id: \.self) { day in
                                SampleCalendarCell(
                                    dayNumber: day,
                                    events: eventsForDay(day),
                                    isPlaceholder: false,
                                    designOption: currentDesign
                                )
                            }

                            // Remaining weeks
                            ForEach(7...31, id: \.self) { day in
                                SampleCalendarCell(
                                    dayNumber: day,
                                    events: eventsForDay(day),
                                    isPlaceholder: false,
                                    designOption: currentDesign
                                )
                            }

                            // Remaining days are next month placeholders
                            ForEach(1...3, id: \.self) { _ in
                                SampleCalendarCell(
                                    dayNumber: nil,
                                    events: [],
                                    isPlaceholder: true,
                                    designOption: currentDesign
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)

                    // Design description
                    designDescription
                        .padding()

                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadRealEvents()
        }
    }

    @ViewBuilder
    private var designDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Design:")
                .font(.headline)

            switch currentDesign {
            case .option1:
                Text("• Small color bar on left + event title")
                Text("• Light background tint")
                Text("• Shows 2 events max")
            case .option2:
                Text("• Full colored pill background")
                Text("• White text on colored background")
                Text("• Shows 2 events max")
            case .option3:
                Text("• Compact: just colored text")
                Text("• No background")
                Text("• Shows 3 events max (smaller)")
            case .option4:
                Text("• Keeps current dots")
                Text("• Shows first event title below")
                Text("• Best of both worlds")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadRealEvents() {
        // Load actual events from your calendar
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startOfMonth, end: endOfMonth, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)

        var eventsDict: [Date: [SampleEvent]] = [:]

        for ekEvent in ekEvents {
            let eventDate = calendar.startOfDay(for: ekEvent.startDate)
            let event = SampleEvent(
                title: ekEvent.title ?? "Untitled",
                color: Color(cgColor: ekEvent.calendar.cgColor),
                isAllDay: ekEvent.isAllDay
            )
            eventsDict[eventDate, default: []].append(event)
        }

        realEvents = eventsDict
    }

    private func eventsForDay(_ day: Int) -> [SampleEvent] {
        // Try to use real events first
        let calendar = Calendar.current
        if let date = calendar.date(from: DateComponents(year: 2025, month: 12, day: day)) {
            let startOfDay = calendar.startOfDay(for: date)
            if let events = realEvents[startOfDay], !events.isEmpty {
                return events
            }
        }

        // Fall back to sample data
        return sampleEventsForDay(day)
    }

    func sampleEventsForDay(_ day: Int) -> [SampleEvent] {
        // Generate realistic sample data throughout the month
        switch day {
        case 1: return [
            SampleEvent(title: "New Month Planning", color: .blue, isAllDay: true)
        ]
        case 3: return [
            SampleEvent(title: "Team Meeting", color: .blue, isAllDay: false)
        ]
        case 5: return [
            SampleEvent(title: "Sarah's Birthday", color: .purple, isAllDay: true),
            SampleEvent(title: "Birthday Dinner", color: .orange, isAllDay: false)
        ]
        case 8: return [
            SampleEvent(title: "Tech Conference", color: .green, isAllDay: true),
            SampleEvent(title: "Lunch Meeting", color: .pink, isAllDay: false),
            SampleEvent(title: "Gym", color: .red, isAllDay: false)
        ]
        case 10: return [
            SampleEvent(title: "Doctor Appointment", color: .teal, isAllDay: false)
        ]
        case 12: return [
            SampleEvent(title: "Dentist", color: .cyan, isAllDay: false),
            SampleEvent(title: "Grocery Shopping", color: .indigo, isAllDay: false)
        ]
        case 15: return [
            SampleEvent(title: "Project Deadline", color: .red, isAllDay: true),
            SampleEvent(title: "Client Call", color: .blue, isAllDay: false),
            SampleEvent(title: "Team Standup", color: .green, isAllDay: false),
            SampleEvent(title: "Code Review", color: .purple, isAllDay: false)
        ]
        case 18: return [
            SampleEvent(title: "Company Holiday Party", color: .orange, isAllDay: false)
        ]
        case 20: return [
            SampleEvent(title: "Soccer Practice", color: .green, isAllDay: false)
        ]
        case 22: return [
            SampleEvent(title: "Winter Begins", color: .blue, isAllDay: true)
        ]
        case 24: return [
            SampleEvent(title: "Christmas Eve", color: .red, isAllDay: true),
            SampleEvent(title: "Family Dinner", color: .orange, isAllDay: false)
        ]
        case 25: return [
            SampleEvent(title: "Christmas Day", color: .red, isAllDay: true)
        ]
        case 28: return [
            SampleEvent(title: "Weekend Getaway", color: .purple, isAllDay: true),
            SampleEvent(title: "Travel Day", color: .blue, isAllDay: false)
        ]
        case 31: return [
            SampleEvent(title: "New Year's Eve", color: .purple, isAllDay: true),
            SampleEvent(title: "NYE Party", color: .orange, isAllDay: false)
        ]
        default: return []
        }
    }
}

/// Sample calendar cell showing new design with event titles and colors
struct SampleCalendarCell: View {
    let dayNumber: Int?
    let events: [SampleEvent]
    let isPlaceholder: Bool
    let designOption: CalendarCellPreview.DesignOption

    var body: some View {
        if isPlaceholder {
            Spacer()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 80)
                .background(Color(.systemGroupedBackground))
        } else if let dayNumber = dayNumber {
            switch designOption {
            case .option1:
                Option1Cell(dayNumber: dayNumber, events: events)
            case .option2:
                Option2Cell(dayNumber: dayNumber, events: events)
            case .option3:
                Option3Cell(dayNumber: dayNumber, events: events)
            case .option4:
                Option4Cell(dayNumber: dayNumber, events: events)
            }
        }
    }
}

// MARK: - Design Option 1: Pills with Color Bar
struct Option1Cell: View {
    let dayNumber: Int
    let events: [SampleEvent]
    let maxVisibleEvents = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(events.prefix(maxVisibleEvents).enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.color)
                            .frame(width: 3)
                        Text(event.title)
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 14)
                    .padding(.horizontal, 2)
                    .background(event.color.opacity(0.12))
                    .cornerRadius(3)
                }

                if events.count > maxVisibleEvents {
                    Text("+\(events.count - maxVisibleEvents)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 80)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Design Option 2: Full Colored Pills
struct Option2Cell: View {
    let dayNumber: Int
    let events: [SampleEvent]
    let maxVisibleEvents = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(events.prefix(maxVisibleEvents).enumerated()), id: \.offset) { _, event in
                    Text(event.title)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(event.color)
                        .cornerRadius(4)
                }

                if events.count > maxVisibleEvents {
                    Text("+\(events.count - maxVisibleEvents)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 80)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Design Option 3: Compact Text Only
struct Option3Cell: View {
    let dayNumber: Int
    let events: [SampleEvent]
    let maxVisibleEvents = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(events.prefix(maxVisibleEvents).enumerated()), id: \.offset) { _, event in
                    Text(event.title)
                        .font(.system(size: 8))
                        .lineLimit(1)
                        .foregroundColor(event.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 3)
                }

                if events.count > maxVisibleEvents {
                    Text("+\(events.count - maxVisibleEvents)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 3)
                }
            }
            .padding(.bottom, 2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 80)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Design Option 4: Dots + First Event
struct Option4Cell: View {
    let dayNumber: Int
    let events: [SampleEvent]

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .padding(.top, 2)

            // Dots (like current design)
            if !events.isEmpty {
                HStack(spacing: 2) {
                    ForEach(0..<min(3, events.count), id: \.self) { index in
                        Circle()
                            .fill(events[index].color)
                            .frame(width: 5, height: 5)
                    }
                }
            }

            // First event title
            if let firstEvent = events.first {
                Text(firstEvent.title)
                    .font(.system(size: 8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 80)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

/// Visual representation of an event as a colored pill with text
struct EventPill: View {
    let event: SampleEvent

    var body: some View {
        HStack(spacing: 2) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 3)

            // Event title
            Text(event.title)
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer(minLength: 0)
        }
        .frame(height: 16)
        .padding(.horizontal, 2)
        .background(event.color.opacity(0.15))
        .cornerRadius(4)
    }
}

/// Sample event data for preview
struct SampleEvent: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let isAllDay: Bool
}

// MARK: - Preview Provider
struct CalendarCellPreview_Previews: PreviewProvider {
    static var previews: some View {
        CalendarCellPreview()
    }
}
