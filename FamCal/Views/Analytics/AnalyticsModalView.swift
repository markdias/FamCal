//
//  AnalyticsModalView.swift
//  FamCal
//
//  Prototype D: Modal/Sheet analytics view
//  Accessible via long-press on member in FamilyView or quick action
//  Quick view without full navigation
//

import SwiftUI
import CoreData
import EventKit

struct AnalyticsModalView: View {
    let member: FamilyMember
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: PersonalCalendar.entity(),
        sortDescriptors: []
    )
    private var personalCalendars: FetchedResults<PersonalCalendar>

    @State private var selectedDate: Date = Date()
    @State private var analytics: TimeAnalytics?
    @State private var isCalculating = false
    @State private var eventStore = EKEventStore()
    @State private var selectedEventBlock: BusyBlock?

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if isCalculating {
                    loadingView
                } else if let analytics = analytics {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Quick date picker
                            quickDateSelector

                            // Timeline
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Timeline")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)

                                TimelineVisualizationView(
                                    analytics: analytics,
                                    memberColor: UIColorFromHex(member.colorHex ?? "#007AFF"),
                                    selectedBlock: $selectedEventBlock
                                )
                            }

                            // Key metrics summary
                            HStack(spacing: 12) {
                                metricPill(
                                    label: "Free",
                                    value: formatMinutes(analytics.freeMinutes),
                                    color: .green
                                )

                                metricPill(
                                    label: "Busy",
                                    value: formatMinutes(analytics.busyMinutes),
                                    color: .orange
                                )

                                metricPill(
                                    label: "Gaps",
                                    value: "\(analytics.gaps.count)",
                                    color: .blue
                                )
                            }

                            // Quick event summary
                            if !analytics.busyBlocks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Events")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    VStack(spacing: 4) {
                                        ForEach(analytics.busyBlocks.prefix(3)) { block in
                                            quickEventRow(block)
                                        }

                                        if analytics.busyBlocks.count > 3 {
                                            Text("+ \(analytics.busyBlocks.count - 3) more")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }

                            // Insights
                            insightBanner(analytics: analytics)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("\(member.name ?? "Member")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            calculateAnalytics()
        }
        .onChange(of: selectedDate) { _, _ in
            calculateAnalytics()
        }
    }

    // MARK: - Components

    private var quickDateSelector: some View {
        HStack(spacing: 8) {
            quickDateButton("Today", date: Date())
            quickDateButton(
                "Tomorrow",
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            )

            Spacer()

            Menu {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                    Text("Custom")
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(6)
            }
        }
    }

    private func quickDateButton(_ label: String, date: Date) -> some View {
        Button(action: { selectedDate = date }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Calendar.current.isDate(selectedDate, inSameDayAs: date) ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Calendar.current.isDate(selectedDate, inSameDayAs: date)
                        ? Color.blue
                        : Color(.tertiarySystemBackground)
                )
                .cornerRadius(6)
        }
    }

    private func metricPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func quickEventRow(_ block: BusyBlock) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.eventTitles.first ?? "Event")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(formatTime(block.start) + " – " + formatTime(block.end))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formatDuration(block.durationMinutes))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }

    private func insightBanner(analytics: TimeAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(insightTitle(analytics: analytics))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            Text(insightMessage(analytics: analytics))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(insightBackgroundColor(analytics: analytics))
        )
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func calculateAnalytics() {
        isCalculating = true

        let calculator = TimeAnalyticsCalculator()

        // Get wake/bed times
        let wakeHour = member.useCustomSchedule ? Int(member.wakeTimeHour) : 7
        let wakeMinute = member.useCustomSchedule ? Int(member.wakeTimeMinute) : 0
        let bedHour = member.useCustomSchedule ? Int(member.bedTimeHour) : 22
        let bedMinute = member.useCustomSchedule ? Int(member.bedTimeMinute) : 0

        // Fetch all events from shared and personal calendars
        let events = fetchAllEventsForMember(member)

        analytics = calculator.calculate(
            for: member.id ?? UUID(),
            date: selectedDate,
            wakeTime: (hour: wakeHour, minute: wakeMinute),
            bedTime: (hour: bedHour, minute: bedMinute),
            events: events
        )

        isCalculating = false
    }

    /// Fetches all events from shared and personal calendars for the given member
    private func fetchAllEventsForMember(_ member: FamilyMember) -> [UpcomingCalendarEvent] {
        let localCalendars = eventStore.calendars(for: .event)
        let calendarById = Dictionary(uniqueKeysWithValues: localCalendars.map { ($0.calendarIdentifier, $0) })
        let calendarByTitle = Dictionary(grouping: localCalendars, by: { $0.title }).mapValues { $0.first! }

        var calendarIDs = Set<String>()

        // Personal calendars (linked to this member's family member record)
        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
            for cal in memberCals {
                if let storedID = cal.calendarID {
                    var resolvedID = storedID
                    if calendarById[storedID] == nil, let name = cal.calendarName, let localCal = calendarByTitle[name] {
                        resolvedID = localCal.calendarIdentifier
                    }
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        // Shared calendars (family calendars shared with this member)
        if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
            for cal in sharedCals {
                if let storedID = cal.calendarID {
                    var resolvedID = storedID
                    if calendarById[storedID] == nil, let name = cal.calendarName, let localCal = calendarByTitle[name] {
                        resolvedID = localCal.calendarIdentifier
                    }
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        // Personal calendars - only include if this member is the logged-in user
        if let linkedMemberId = appSettingsManager.linkedFamilyMemberId,
           member.id?.uuidString.lowercased() == linkedMemberId.lowercased() {
            for personalCal in personalCalendars {
                // Only include if toggled for family view
                let shouldInclude = personalCal.showInSpotlight
                guard shouldInclude else { continue }

                var resolvedID: String?
                if let storedID = personalCal.calendarID {
                    resolvedID = storedID
                    if calendarById[storedID] == nil, let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                        resolvedID = localCal.calendarIdentifier
                    }
                } else if let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                    resolvedID = localCal.calendarIdentifier
                }

                if let resolvedID {
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        guard !calendarIDs.isEmpty else { return [] }

        // Fetch all events
        let upcomingEvents = CalendarManager.shared.fetchNextEvents(
            for: Array(calendarIDs),
            limit: 0,
            pastDays: appSettingsManager.eventsPastDays,
            futureDays: appSettingsManager.eventsFutureDays
        )

        return upcomingEvents.map { event in
            UpcomingCalendarEvent(
                id: event.id,
                title: event.title,
                location: event.location,
                meetingLink: event.meetingLink,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarID: event.calendarID,
                calendarColor: event.calendarColor,
                calendarTitle: event.calendarTitle,
                hasRecurrence: event.hasRecurrence,
                recurrenceRule: nil,
                isAllDay: event.isAllDay
            )
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(hours)h"
        }
    }

    private func insightTitle(analytics: TimeAnalytics) -> String {
        if analytics.freePercentage >= 80 {
            return "✓ Lots of Free Time"
        } else if analytics.freePercentage >= 50 {
            return "~ Moderate Schedule"
        } else if analytics.freePercentage >= 25 {
            return "⚠ Busy Day"
        } else {
            return "⚠ Very Busy"
        }
    }

    private func insightMessage(analytics: TimeAnalytics) -> String {
        if analytics.freePercentage >= 80 {
            return "Room for additional events."
        } else if analytics.freePercentage >= 50 {
            return "Some availability for new events."
        } else if analytics.freePercentage >= 25 {
            return "Limited availability for new events."
        } else {
            return "Minimal free time available."
        }
    }

    private func insightBackgroundColor(analytics: TimeAnalytics) -> Color {
        if analytics.freePercentage >= 80 {
            return Color.green.opacity(0.1)
        } else if analytics.freePercentage >= 50 {
            return Color.blue.opacity(0.1)
        } else {
            return Color.orange.opacity(0.1)
        }
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    let appSettings = AppSettingsManager()

    let member = FamilyMember(context: context)
    member.id = UUID()
    member.name = "Alex"
    member.colorHex = "#FF6B6B"
    member.wakeTimeHour = 7
    member.bedTimeHour = 22
    member.useCustomSchedule = false

    return AnalyticsModalView(member: member)
        .environment(\.managedObjectContext, context)
        .environmentObject(appSettings)
}
