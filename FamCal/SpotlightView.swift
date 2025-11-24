//
//  SpotlightView.swift
//  FamCal
//
//  Created by Mark Dias on 18/11/2025.
//

import SwiftUI
import CoreData
import EventKit

struct SpotlightView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @AppStorage("spotlightShowGapsBetweenEvents") private var spotlightShowGapsBetweenEvents: Bool = true

    let member: FamilyMember

    private var spotlightEventsPerPerson: Int { appSettingsManager.spotlightEventsPerPerson }
    private var autoRefreshInterval: Int { appSettingsManager.autoRefreshInterval }
    private var defaultMapsApp: String { appSettingsManager.defaultMapsApp }

    @FetchRequest(
        entity: FamilyMemberCalendar.entity(),
        sortDescriptors: []
    )
    private var memberCalendarLinks: FetchedResults<FamilyMemberCalendar>

    @FetchRequest(
        entity: SavedAddress.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedAddress.name, ascending: true)]
    )
    private var savedAddresses: FetchedResults<SavedAddress>

    @State private var isLoadingEvents = false
    @State private var events: [GroupedEvent] = []
    @State private var selectedEvent: UpcomingCalendarEvent? = nil
    @State private var showingEventDetail = false
    @State private var eventStore = EKEventStore()
    @State private var refreshTimer: Timer? = nil

    private let calendar = Calendar.current

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack(spacing: 12) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                            }

                            Text(member.name ?? "Unknown")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // Events list
                        if isLoadingEvents {
                            loadingView
                        } else if events.isEmpty {
                            emptyStateView
                        } else {
                            let isLandscape = verticalSizeClass == .compact
                            let columns = isLandscape
                                ? [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
                                : [GridItem(.flexible())]

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                    if spotlightShowGapsBetweenEvents,
                                       index > 0,
                                       let gapText = gapText(between: events[index - 1], and: event) {
                                        // In grid, gap label might need to span full width or be handled differently
                                        // For simplicity in grid, we might hide it or show it in a full-width item
                                        // But LazyVGrid doesn't support full-width items easily mixed in without Section
                                        // Let's just show it if not landscape, or try to handle it.
                                        // For now, let's only show gaps in portrait (list) mode to avoid grid layout issues
                                        if !isLandscape {
                                            gapLabel(gapText)
                                        }
                                    }

                                    Button(action: {
                                        selectedEvent = UpcomingCalendarEvent(
                                            id: event.eventIdentifier,
                                            title: event.title,
                                            location: event.location,
                                            startDate: event.startDate,
                                            endDate: event.endDate,
                                            calendarID: event.calendarID,
                                            calendarColor: event.memberColor,
                                            calendarTitle: event.calendarTitle,
                                            hasRecurrence: event.hasRecurrence,
                                            recurrenceRule: nil,
                                            isAllDay: event.isAllDay
                                        )
                                        showingEventDetail = true
                                    }) {
                                        eventCard(event)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.bottom, 120)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEventDetail) {
                if let event = selectedEvent {
                    EventDetailView(event: event)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: setupView)
        .onChange(of: appSettingsManager.autoRefreshInterval) { _, _ in startRefreshTimer() }
        .onChange(of: appSettingsManager.spotlightEventsPerPerson) { _, _ in loadEvents() }
        .onDisappear(perform: cleanupView)
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color(red: 0.33, green: 0.33, blue: 0.33))

            Text("Loading events...")
                .font(.system(size: 15))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No events scheduled")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text("No upcoming events for \(member.name ?? "this member")")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func eventCard(_ event: GroupedEvent) -> some View {
        let dateBoxWidth: CGFloat = 64
        let cardCornerRadius: CGFloat = 16

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color(uiColor: .systemBackground))

            Group {
                if event.memberColors.count > 1 {
                    LinearGradient(
                        gradient: Gradient(colors: event.memberColors.map { Color(uiColor: $0) }),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(uiColor: event.memberColor)
                }
            }
            .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))
            .frame(width: dateBoxWidth)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(Self.dayOfWeekFormatter.string(from: event.startDate))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    Text(Self.dayFormatter.string(from: event.startDate))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(Self.monthFormatter.string(from: event.startDate))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(width: dateBoxWidth)
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if !event.isAllDay, let timeRange = event.timeRange {
                            let startTime = timeRange.split(separator: "–").first.map(String.init).map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                            Text(startTime)
                                .font(.system(size: 14, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    if let location = event.location {
                        let firstLine = location.split(separator: "\n").first.map(String.init) ?? location
                        let savedAddress = getSavedAddress(for: firstLine)
                        let displayText = savedAddress?.name ?? firstLine
                        let mapAddress = savedAddress?.address ?? firstLine
                        
                        Button(action: { MapsUtility.openLocation(mapAddress, in: defaultMapsApp) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text(displayText)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                if !event.isAllDay, let timeRange = event.timeRange {
                                    let endTime = timeRange.split(separator: "–").last.map(String.init).map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                                    Text(endTime)
                                        .font(.system(size: 14, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } else if !event.isAllDay, let timeRange = event.timeRange {
                        let endTime = timeRange.split(separator: "–").last.map(String.init).map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                        HStack(spacing: 0) {
                            Spacer()
                            Text(endTime)
                                .font(.system(size: 14, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    if let driverName = event.driverName {
                        HStack(spacing: 8) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text(driverName)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: dateBoxWidth, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func gapLabel(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 24, height: 1)

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Private Methods
    
    private func getSavedAddress(for location: String) -> SavedAddress? {
        // Try to find a saved address that matches this location
        return savedAddresses.first { savedAddr in
            guard let address = savedAddr.address else { return false }
            // Match if the event location contains the saved address or vice versa
            return location.lowercased().contains(address.lowercased()) ||
                   address.lowercased().contains(location.lowercased())
        }
    }

    private func fetchDriverForEvent(_ eventIdentifier: String) -> String? {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", eventIdentifier)

        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first?.driver?.name
        } catch {
            return nil
        }
    }

    private func loadEvents() {
        isLoadingEvents = true

        let now = Date()

        // Get all calendar IDs for this member
        var calendarIDs = Set<String>()

        // Personal calendars
        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
            for cal in memberCals {
                if let calID = cal.calendarID {
                    calendarIDs.insert(calID)
                }
            }
        }

        // Shared calendars
        if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
            for cal in sharedCals {
                if let calID = cal.calendarID {
                    calendarIDs.insert(calID)
                }
            }
        }

        guard !calendarIDs.isEmpty else {
            events = []
            isLoadingEvents = false
            return
        }

        // Fetch events for this member
        let upcomingEvents = CalendarManager.shared.fetchNextEvents(
            for: Array(calendarIDs),
            limit: 0,
            pastDays: appSettingsManager.eventsPastDays,
            futureDays: appSettingsManager.eventsFutureDays
        )

        var eventItems: [EventItem] = []
        for event in upcomingEvents {
            let timeRange: String? = {
                guard event.startDate != event.endDate else { return nil }
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
            }()

            let displayID = "\(event.id)|\(event.startDate.timeIntervalSince1970)"
            let driverName = fetchDriverForEvent(event.id)
            eventItems.append(EventItem(
                id: displayID,
                eventIdentifier: event.id,
                title: event.title,
                location: event.location,
                startDate: event.startDate,
                endDate: event.endDate,
                timeRange: timeRange,
                memberName: member.name ?? "Unknown",
                memberColor: event.calendarColor,
                calendarTitle: event.calendarTitle,
                calendarID: event.calendarID,
                hasRecurrence: event.hasRecurrence,
                recurrenceRule: nil,
                isAllDay: event.isAllDay,
                driverName: driverName
            ))
        }

        // Sort by start date
        eventItems.sort { $0.startDate < $1.startDate }

        // Filter to future events
        let futureEvents = eventItems.filter { $0.endDate > now }

        // Group events
        let grouped = groupEventsByDetails(futureEvents)
        let sorted = grouped.sorted { $0.startDate < $1.startDate }

        events = Array(sorted.prefix(spotlightEventsPerPerson))
        isLoadingEvents = false
    }

    private func gapText(between first: GroupedEvent, and second: GroupedEvent) -> String? {
        guard !first.isAllDay, !second.isAllDay else { return nil }
        guard calendar.isDate(first.startDate, inSameDayAs: second.startDate) else { return nil }

        if second.startDate <= first.endDate {
            return "Back to Back"
        }

        let interval = second.startDate.timeIntervalSince(first.endDate)
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours)h")
        }
        if minutes > 0 {
            parts.append("\(minutes) mins")
        }

        guard !parts.isEmpty else { return "Back to Back" }
        let gap = parts.joined(separator: " ")
        return "\(gap) inbetween"
    }

    private func groupEventsByDetails(_ events: [EventItem]) -> [GroupedEvent] {
        var grouped: [String: GroupedEvent] = [:]

        for event in events {
            let startKey = String(event.startDate.timeIntervalSinceReferenceDate)
            let key = "\(event.title)|\(startKey)|\(event.timeRange ?? "all-day")|\(event.location ?? "")"

            if let existing = grouped[key] {
                var updatedNames = existing.memberNames
                updatedNames.append(event.memberName)

                grouped[key] = GroupedEvent(
                    id: existing.id,
                    eventIdentifier: existing.eventIdentifier,
                    title: existing.title,
                    timeRange: existing.timeRange,
                    location: existing.location,
                    startDate: existing.startDate,
                    endDate: existing.endDate,
                    memberNames: updatedNames,
                    memberColor: existing.memberColor,
                    calendarTitle: existing.calendarTitle,
                    calendarID: existing.calendarID,
                    memberColors: existing.memberColors,
                    hasRecurrence: existing.hasRecurrence || event.hasRecurrence,
                    isAllDay: existing.isAllDay,
                    driverName: existing.driverName ?? event.driverName
                )
            } else {
                grouped[key] = GroupedEvent(
                    id: event.id,
                    eventIdentifier: event.eventIdentifier,
                    title: event.title,
                    timeRange: event.timeRange,
                    location: event.location,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    memberNames: [event.memberName],
                    memberColor: event.memberColor,
                    calendarTitle: event.calendarTitle,
                    calendarID: event.calendarID,
                    memberColors: [event.memberColor],
                    hasRecurrence: event.hasRecurrence,
                    isAllDay: event.isAllDay,
                    driverName: event.driverName
                )
            }
        }

        return grouped.values.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - View Lifecycle

    private func setupView() {
        loadEvents()
        startRefreshTimer()
    }

    private func cleanupView() {
        stopRefreshTimer()
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(autoRefreshInterval * 60), repeats: true) { _ in
            loadEvents()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Data Models

private struct EventItem: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let timeRange: String?
    let memberName: String
    let memberColor: UIColor
    let calendarTitle: String
    let calendarID: String
    let hasRecurrence: Bool
    let recurrenceRule: Any?
    let isAllDay: Bool
    let driverName: String?
}

private struct GroupedEvent: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
    let timeRange: String?
    let location: String?
    let startDate: Date
    let endDate: Date
    var memberNames: [String]
    let memberColor: UIColor
    let calendarTitle: String
    let calendarID: String
    let memberColors: [UIColor]
    let hasRecurrence: Bool
    let isAllDay: Bool
    let driverName: String?
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let member = FamilyMember(context: context)
    member.id = UUID()
    member.name = "John Doe"
    member.colorHex = "#555555"
    member.avatarInitials = "JD"

    return SpotlightView(member: member)
        .environment(\.managedObjectContext, context)
}
