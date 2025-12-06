//
//  SpotlightView.swift
//  FamCal
//
//  Created by Mark Dias on 18/11/2025.
//

import SwiftUI
import CoreData
import EventKit
import UIKit

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
        entity: PersonalCalendar.entity(),
        sortDescriptors: []
    )
    private var personalCalendars: FetchedResults<PersonalCalendar>

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
    @State private var availableCalendars: [EKCalendar] = []
    @State private var pendingDeleteEvent: UpcomingCalendarEvent?
    @State private var pendingDeleteSpan: EKSpan = .thisEvent
    @State private var showingLinkedDeleteDialog = false
    @State private var linkedDeleteScope: DeleteScope = .singleCalendar
    @State private var selectedEventIdsForDeletion: Set<String> = []
    @State private var showingBatchDeleteDialog = false
    @State private var lastTapTime: Date = .distantPast
    @State private var lastTappedEventId: String = ""
    @State private var tapDelayTimer: Timer?

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
                        if events.isEmpty && !isLoadingEvents {
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

                                    eventCard(event)
                                        .onTapGesture {
                                            handleEventTap(event: event)
                                        }
                                    .contextMenu {
                                        let upcomingEvent = UpcomingCalendarEvent(
                                            id: event.eventIdentifier,
                                            title: event.title,
                                            location: event.location,
                                            meetingLink: event.meetingLink,
                                            startDate: event.startDate,
                                            endDate: event.endDate,
                                            calendarID: event.calendarID,
                                            calendarColor: event.memberColor,
                                            calendarTitle: event.calendarTitle,
                                            hasRecurrence: event.hasRecurrence,
                                            recurrenceRule: nil,
                                            isAllDay: event.isAllDay
                                        )

                                        Button(action: { duplicateEvent(upcomingEvent) }) {
                                            Label("Duplicate", systemImage: "doc.on.doc")
                                        }

                                        // Move to calendar
                                        Menu {
                                            ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                                Button(action: {
                                                    moveEventToCalendar(upcomingEvent, calendarID: calendar.calendarIdentifier)
                                                }) {
                                                    HStack {
                                                        Text(calendar.title)
                                                        if calendar.calendarIdentifier == upcomingEvent.calendarID {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label("Move to Calendar", systemImage: "calendar.badge.plus")
                                        }

                                        Divider()

                                        // Delete action
                                        if upcomingEvent.hasRecurrence {
                                            Menu {
                                                Button(action: { confirmDelete(upcomingEvent, span: .thisEvent) }) {
                                                    Label("Delete This Event", systemImage: "trash")
                                                }
                                                Button(role: .destructive, action: { confirmDelete(upcomingEvent, span: .futureEvents) }) {
                                                    Label("Delete This & Future Events", systemImage: "trash")
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        } else {
                                            Button(role: .destructive, action: { confirmDelete(upcomingEvent, span: .thisEvent) }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .opacity(isLoadingEvents ? 0.6 : 1.0)
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
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            print("🔔 SpotlightView: Received EKEventStoreChanged")
            loadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("📱 SpotlightView: Received didBecomeActive")
            // Only restart timer on active; data reload is handled by EKEventStoreChanged
            startRefreshTimer()
        }
        .onAppear(perform: setupView)
        .onChange(of: appSettingsManager.autoRefreshInterval) { _, _ in startRefreshTimer() }
        .onChange(of: appSettingsManager.spotlightEventsPerPerson) { _, _ in loadEvents() }
        .onDisappear(perform: cleanupView)
        .onAppear {
            loadAvailableCalendars()
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            loadAvailableCalendars()
        }
        .sheet(isPresented: $showingLinkedDeleteDialog) {
            linkedDeleteDialog
        }
        .confirmationDialog(
            "Delete Selected Events",
            isPresented: $showingBatchDeleteDialog,
            titleVisibility: .visible
        ) {
            if selectedEventIdsForDeletion.isEmpty {
                Button("Cancel", role: .cancel) { }
            } else {
                Button("Delete", role: .destructive) {
                    batchDeleteSelectedEvents()
                }
                Button("Cancel", role: .cancel) { }
            }
        } message: {
            let count = selectedEventIdsForDeletion.count
            Text("Delete \(count) selected event\(count == 1 ? "" : "s")?")
        }
    }

    // MARK: - Delete Dialog

    private var linkedDeleteDialog: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                // Check if event has linked copies
                if let event = pendingDeleteEvent, linkedFamilyEvents(for: event.id).count > 1 {
                    Text("Delete from Multiple Calendars?")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Text("This event exists in multiple calendars. How would you like to delete it?")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                } else if let event = pendingDeleteEvent {
                    Text("Delete Event")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Are you sure you want to delete '\(event.title)'?")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 12)

            VStack(spacing: 12) {
                if let event = pendingDeleteEvent, linkedFamilyEvents(for: event.id).count > 1 {
                    Button(action: {
                        if let event = pendingDeleteEvent {
                            deleteEvent(event, span: pendingDeleteSpan, scope: .singleCalendar)
                        }
                        showingLinkedDeleteDialog = false
                    }) {
                        Label("Delete from This Calendar Only", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.primary)

                    Button(role: .destructive, action: {
                        if let event = pendingDeleteEvent {
                            deleteEvent(event, span: pendingDeleteSpan, scope: .allLinked)
                        }
                        showingLinkedDeleteDialog = false
                    }) {
                        Label("Delete from All Calendars", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                } else {
                    // Single event - just show delete button
                    Button(role: .destructive, action: {
                        if let event = pendingDeleteEvent {
                            deleteEvent(event, span: pendingDeleteSpan, scope: .singleCalendar)
                        }
                        showingLinkedDeleteDialog = false
                    }) {
                        Label("Delete Event", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: {
                    showingLinkedDeleteDialog = false
                }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.primary)
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .padding(20)
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.fraction(0.4)])
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
        let isSelected = selectedEventIdsForDeletion.contains(event.eventIdentifier)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(isSelected ? Color(event.memberColor).opacity(0.25) : Color(uiColor: .systemBackground))

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
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
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
                                        .font(.system(size: 11, weight: .semibold))
                                        .monospacedDigit()
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
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    if let meetingLink = event.meetingLink,
                       let destination = MeetingLinkHelper.normalizedURL(from: meetingLink) {
                        Link(destination: destination) {
                            HStack(spacing: 6) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text(MeetingLinkHelper.displayLabel(for: meetingLink))
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .buttonStyle(.plain)
                    }

                    if let driverName = event.driverName {
                        let driverPhone = fetchDriverPhoneForEvent(event.id)
                        if let phone = driverPhone, !phone.isEmpty {
                            Link(destination: URL(string: "tel:\(phone)")!) {
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
                        } else {
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
        .overlay(
            // Selection indicator
            isSelected ? AnyView(
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color(event.memberColor)))
            ) : AnyView(EmptyView()),
            alignment: .topTrailing
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

    private func handleEventTap(event: GroupedEvent) {
        // Cancel any pending single tap timer
        tapDelayTimer?.invalidate()

        // Check if this is a double tap
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

        if lastTappedEventId == event.eventIdentifier && timeSinceLastTap < 0.3 {
            // Double tap detected - toggle selection
            if selectedEventIdsForDeletion.contains(event.eventIdentifier) {
                selectedEventIdsForDeletion.remove(event.eventIdentifier)
            } else {
                selectedEventIdsForDeletion.insert(event.eventIdentifier)
            }
            lastTapTime = .distantPast
            tapDelayTimer?.invalidate()
            tapDelayTimer = nil
        } else {
            // Possible start of double tap or single tap
            lastTapTime = now
            lastTappedEventId = event.eventIdentifier

            // Delay action to see if another tap comes
            tapDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                // Single tap - show event details
                selectedEvent = UpcomingCalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title,
                    location: event.location,
                    meetingLink: event.meetingLink,
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
                tapDelayTimer = nil
            }
        }
    }

    private func batchDeleteSelectedEvents() {
        let selectedIds = selectedEventIdsForDeletion

        Task {
            var deletedCount = 0

            for eventId in selectedIds {
                if let event = events.first(where: { $0.eventIdentifier == eventId }) {
                    let upcomingEvent = UpcomingCalendarEvent(
                        id: event.eventIdentifier,
                        title: event.title,
                        location: event.location,
                        meetingLink: event.meetingLink,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        calendarID: event.calendarID,
                        calendarColor: event.memberColor,
                        calendarTitle: event.calendarTitle,
                        hasRecurrence: event.hasRecurrence,
                        recurrenceRule: nil,
                        isAllDay: event.isAllDay
                    )

                    let success = CalendarManager.shared.deleteEvent(
                        withIdentifier: upcomingEvent.id,
                        occurrenceStartDate: upcomingEvent.startDate,
                        from: upcomingEvent.calendarID,
                        span: .thisEvent
                    )

                    if success {
                        deletedCount += 1
                        await NotificationManager.shared.cancelEventNotifications(for: upcomingEvent.id)

                        let fetchRequest = FamilyEvent.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)
                        if let familyEvent = try? viewContext.fetch(fetchRequest).first {
                            viewContext.delete(familyEvent)
                        }
                    }
                }
            }

            if deletedCount > 0 {
                try? viewContext.save()
                print("✅ Batch deleted \(deletedCount) event(s)")
                await MainActor.run {
                    selectedEventIdsForDeletion.removeAll()
                    loadEvents()
                }
            }
        }
    }

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

    private func fetchDriverPhoneForEvent(_ eventIdentifier: String) -> String? {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", eventIdentifier)

        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first?.driver?.phone
        } catch {
            return nil
        }
    }

    private func loadEvents() {
        print("🔦 SpotlightView: loadEvents() started")
        isLoadingEvents = true

        let now = Date()

        // Fetch all local calendars for resolution
        let localCalendars = eventStore.calendars(for: .event)
        let calendarById = Dictionary(uniqueKeysWithValues: localCalendars.map { ($0.calendarIdentifier, $0) })
        let calendarByTitle = Dictionary(grouping: localCalendars, by: { $0.title }).mapValues { $0.first! }

        // Get all calendar IDs for this member
        var calendarIDs = Set<String>()

        // Personal calendars
        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
            for cal in memberCals {
                if let storedID = cal.calendarID {
                    var resolvedID = storedID
                    if calendarById[storedID] == nil, let name = cal.calendarName, let localCal = calendarByTitle[name] {
                        print("⚠️ Spotlight: Calendar ID mismatch for '\(name)'. Resolved by name: \(storedID) -> \(localCal.calendarIdentifier)")
                        resolvedID = localCal.calendarIdentifier
                    }
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        // Shared calendars
        if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
            for cal in sharedCals {
                if let storedID = cal.calendarID {
                    var resolvedID = storedID
                    if calendarById[storedID] == nil, let name = cal.calendarName, let localCal = calendarByTitle[name] {
                        print("⚠️ Spotlight: Shared Calendar ID mismatch for '\(name)'. Resolved by name: \(storedID) -> \(localCal.calendarIdentifier)")
                        resolvedID = localCal.calendarIdentifier
                    }
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        // Personal calendars - only include if this member is the logged-in user
        if let linkedMemberId = appSettingsManager.linkedFamilyMemberId,
           member.id?.uuidString.lowercased() == linkedMemberId.lowercased() {
            print("🔦 SpotlightView: This is the logged-in user, checking personal calendars...")
            for personalCal in personalCalendars {
                // Only include if toggled for spotlight view
                let shouldInclude = personalCal.showInSpotlight
                print("🔦 SpotlightView: Personal Calendar '\(personalCal.calendarName ?? "nil")' showInSpotlight: \(shouldInclude)")
                guard shouldInclude else { continue }

                var resolvedID: String?
                if let storedID = personalCal.calendarID {
                    resolvedID = storedID
                    if calendarById[storedID] == nil, let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                        print("⚠️ Spotlight: Personal Calendar ID mismatch for '\(name)'. Resolved by name: \(storedID) -> \(localCal.calendarIdentifier)")
                        resolvedID = localCal.calendarIdentifier
                    }
                } else if let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                    print("ℹ️ Spotlight: Personal Calendar missing ID, resolved by name: \(name) -> \(localCal.calendarIdentifier)")
                    resolvedID = localCal.calendarIdentifier
                }

                if let resolvedID {
                    print("✅ Spotlight: Adding personal calendar '\(personalCal.calendarName ?? "nil")' with ID: \(resolvedID)")
                    calendarIDs.insert(resolvedID)
                } else {
                    print("❌ Spotlight: Failed to resolve ID for personal calendar '\(personalCal.calendarName ?? "nil")'")
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
                    meetingLink: event.meetingLink,
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
            let key = "\(event.title)|\(startKey)|\(event.timeRange ?? "all-day")|\(event.location ?? "")|\(event.meetingLink ?? "")"

            if let existing = grouped[key] {
                var updatedNames = existing.memberNames
                updatedNames.append(event.memberName)

                    grouped[key] = GroupedEvent(
                        id: existing.id,
                        eventIdentifier: existing.eventIdentifier,
                        title: existing.title,
                        timeRange: existing.timeRange,
                        location: existing.location,
                        meetingLink: existing.meetingLink,
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
                    meetingLink: event.meetingLink,
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

        // Set up notification observer for personal calendar visibility changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("PersonalCalendarVisibilityChanged"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔦 SpotlightView: Personal calendar visibility changed, reloading events...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadEvents()
            }
        }
    }

    private func cleanupView() {
        stopRefreshTimer()
        NotificationCenter.default.removeObserver(self, name: Notification.Name("PersonalCalendarVisibilityChanged"), object: nil)
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

    // MARK: - Context Menu Actions

    private func loadAvailableCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
    }

    private func moveEventToCalendar(_ event: UpcomingCalendarEvent, calendarID: String) {
        // Skip if moving to the same calendar
        if calendarID == event.calendarID {
            return
        }

        if let ekEvent = eventStore.event(withIdentifier: event.id) {
            if let targetCalendar = eventStore.calendar(withIdentifier: calendarID) {
                do {
                    ekEvent.calendar = targetCalendar
                    try eventStore.save(ekEvent, span: .thisEvent, commit: true)

                    // Update CoreData record
                    let fetchRequest = FamilyEvent.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)
                    if let familyEvent = try viewContext.fetch(fetchRequest).first {
                        familyEvent.calendarId = calendarID
                        try viewContext.save()
                    }

                    print("✅ Event moved to calendar: \(targetCalendar.title)")
                    loadEvents()
                } catch {
                    print("❌ Failed to move event: \(error.localizedDescription)")
                }
            }
        }
    }

    private func duplicateEvent(_ event: UpcomingCalendarEvent) {
        let newTitle = "\(event.title) (copy)"
        let duration = event.endDate.timeIntervalSince(event.startDate)

        // Create event 1 hour after the original
        let newStartDate = event.startDate.addingTimeInterval(3600)
        let newEndDate = newStartDate.addingTimeInterval(duration)

        let newEventId = CalendarManager.shared.createEvent(
            title: newTitle,
            startDate: newStartDate,
            endDate: newEndDate,
            location: event.location,
            notes: nil,
            meetingLink: event.meetingLink,
            in: event.calendarID
        )

        if let newEventId = newEventId {
            // Create FamilyEvent record if needed
            let familyEvent = FamilyEvent(context: viewContext)
            familyEvent.id = UUID()
            familyEvent.eventGroupId = UUID()
            familyEvent.eventIdentifier = newEventId
            familyEvent.calendarId = event.calendarID
            familyEvent.createdAt = Date()
            familyEvent.isSharedCalendarEvent = false

            do {
                try viewContext.save()
                print("✅ Event duplicated: \(newTitle)")
                loadEvents()
            } catch {
                print("❌ Failed to save duplicated event: \(error.localizedDescription)")
            }
        }
    }

    private func confirmDelete(_ event: UpcomingCalendarEvent, span: EKSpan) {
        pendingDeleteEvent = event
        pendingDeleteSpan = span
        // Always show delete confirmation
        showingLinkedDeleteDialog = true
    }

    private func deleteEvent(_ event: UpcomingCalendarEvent, span: EKSpan = .thisEvent, scope: DeleteScope = .singleCalendar) {
        Task {
            await deleteEventAndLinked(event: event, span: span, scope: scope)
            pendingDeleteEvent = nil
        }
    }

    private func deleteEventAndLinked(event: UpcomingCalendarEvent, span: EKSpan, scope: DeleteScope) async {
        let linked = linkedFamilyEvents(for: event.id)
        let includeLinked = scope == .allLinked && !linked.isEmpty

        var targets: [UpcomingCalendarEvent] = [event]

        if includeLinked {
            let extras = linked.compactMap { familyEvent -> UpcomingCalendarEvent? in
                guard let identifier = familyEvent.eventIdentifier,
                      let calendarId = familyEvent.calendarId else { return nil }
                let startDate = CalendarManager.shared.fetchEventDetails(withIdentifier: identifier)?.startDate ?? event.startDate
                return UpcomingCalendarEvent(
                    id: identifier,
                    title: event.title,
                    location: event.location,
                    meetingLink: event.meetingLink,
                    startDate: startDate,
                    endDate: event.endDate,
                    calendarID: calendarId,
                    calendarColor: event.calendarColor,
                    calendarTitle: event.calendarTitle,
                    hasRecurrence: event.hasRecurrence,
                    recurrenceRule: event.recurrenceRule,
                    isAllDay: event.isAllDay
                )
            }
            targets.append(contentsOf: extras)
        }

        var anyDeleted = false

        for target in targets {
            let success = CalendarManager.shared.deleteEvent(
                withIdentifier: target.id,
                occurrenceStartDate: target.startDate,
                from: target.calendarID,
                span: span
            )

            if success {
                anyDeleted = true

                // Remove from CoreData
                let fetchRequest = FamilyEvent.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", target.id)
                do {
                    let results = try viewContext.fetch(fetchRequest)
                    for result in results {
                        viewContext.delete(result)
                    }
                    try viewContext.save()
                } catch {
                    print("❌ Failed to remove event from CoreData: \(error.localizedDescription)")
                }
            }
        }

        if anyDeleted {
            print("✅ Event deleted successfully")
            await MainActor.run {
                loadEvents()
            }
        }
    }

    private func linkedFamilyEvents(for eventIdentifier: String) -> [FamilyEvent] {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", eventIdentifier)

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("❌ Failed to fetch linked events: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Data Models

private struct EventItem: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
    let location: String?
    let meetingLink: String?
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
    let meetingLink: String?
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
