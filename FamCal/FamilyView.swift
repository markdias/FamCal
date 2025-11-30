//
//  FamilyView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit
import Combine

struct FamilyView: View {
    var onSearchRequested: (() -> Void)? = nil
    var onAddEventRequested: (() -> Void)? = nil
    var onChangeViewRequested: (() -> Void)? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var eventsPerPerson: Int { appSettingsManager.eventsPerPerson }
    private var spotlightEventsPerPerson: Int { appSettingsManager.spotlightEventsPerPerson }
    private var nextEventColumns: Int { appSettingsManager.nextEventColumns }
    private var autoRefreshInterval: Int { appSettingsManager.autoRefreshInterval }
    private var defaultMapsApp: String { appSettingsManager.defaultMapsApp }

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FamilyMember.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)
        ]
    )
    private var familyMembers: FetchedResults<FamilyMember>

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

    @FetchRequest(
        entity: FamilyEvent.entity(),
        sortDescriptors: []
    )
    private var familyEvents: FetchedResults<FamilyEvent>

    private enum DeleteScope {
        case single
        case allLinked
    }

    @State private var isLoadingEvents = false
    @State private var memberEvents: [MemberEventGroup] = {
        // Try to load cached events synchronously for instant display
        if let cachedEvents = UserDefaults.standard.data(forKey: "famcal_member_events_cache") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let dtos = try decoder.decode([MemberEventGroupDTO].self, from: cachedEvents)
                print("📦 Pre-loaded \(dtos.count) cached events")

                return dtos.map { dto in
                    let memberColor = Color.fromHex(dto.memberColorHex)
                    let nextEvent = dto.nextEvent.map { eventDTO -> GroupedEvent in
                        GroupedEvent(
                            id: eventDTO.id,
                            eventIdentifier: eventDTO.eventIdentifier,
                            title: eventDTO.title,
                            timeRange: eventDTO.timeRange,
                            location: eventDTO.location,
                            startDate: eventDTO.startDate,
                            endDate: eventDTO.endDate,
                            memberNames: eventDTO.memberNames,
                            memberColor: UIColorFromHex(eventDTO.memberColorHex),
                            calendarColor: UIColorFromHex(eventDTO.calendarColorHex),
                            calendarTitle: eventDTO.calendarTitle,
                            calendarID: eventDTO.calendarID,
                            memberColors: eventDTO.memberColorsHex.map { UIColorFromHex($0) },
                            hasRecurrence: eventDTO.hasRecurrence,
                            isAllDay: eventDTO.isAllDay,
                            driverName: eventDTO.driverName,
                            isImportant: eventDTO.isImportant
                        )
                    }

                    let upcomingEvents = dto.upcomingEvents.map { eventDTO -> GroupedEvent in
                        GroupedEvent(
                            id: eventDTO.id,
                            eventIdentifier: eventDTO.eventIdentifier,
                            title: eventDTO.title,
                            timeRange: eventDTO.timeRange,
                            location: eventDTO.location,
                            startDate: eventDTO.startDate,
                            endDate: eventDTO.endDate,
                            memberNames: eventDTO.memberNames,
                            memberColor: UIColorFromHex(eventDTO.memberColorHex),
                            calendarColor: UIColorFromHex(eventDTO.calendarColorHex),
                            calendarTitle: eventDTO.calendarTitle,
                            calendarID: eventDTO.calendarID,
                            memberColors: eventDTO.memberColorsHex.map { UIColorFromHex($0) },
                            hasRecurrence: eventDTO.hasRecurrence,
                            isAllDay: eventDTO.isAllDay,
                            driverName: eventDTO.driverName,
                            isImportant: eventDTO.isImportant
                        )
                    }

                    return MemberEventGroup(
                        id: NSManagedObjectID(),
                        memberName: dto.memberName,
                        sortOrder: dto.sortOrder,
                        memberColor: memberColor,
                        nextEvent: nextEvent,
                        upcomingEvents: upcomingEvents
                    )
                }
            } catch {
                print("⚠️ Failed to pre-load cached events: \(error)")
                return []
            }
        }
        return []
    }()
    @State private var eventsTask: Task<Void, Never>? = nil
    @State private var selectedEvent: UpcomingCalendarEvent? = nil
    @State private var spotlightMemberName: String? = nil
    @State private var eventStore = EKEventStore()
    @State private var refreshTimer: Timer? = nil
    @State private var currentTime = Date()
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var showingAddEvent = false
    @State private var availableCalendars: [EKCalendar] = []
    @State private var showingLinkedDeleteDialog = false
    @State private var pendingDeleteEvent: UpcomingCalendarEvent? = nil
    @State private var pendingDeleteSpan: EKSpan = .thisEvent
    @State private var draggedMemberName: String? = nil
    @State private var draggedMemberID: NSManagedObjectID? = nil
    @State private var targetMemberName: String? = nil
    @State private var reorderedEvents: [MemberEventGroup] = []
    @State private var resetDragTimer: Timer? = nil

    private let calendar = Calendar.current
    private var theme: AppTheme { themeManager.selectedTheme }
    private var secondaryTextColor: Color { theme.mutedTagColor }

    // Use reorderedEvents during drag, otherwise use memberEvents
    private var displayedEvents: [MemberEventGroup] {
        draggedMemberName != nil && !reorderedEvents.isEmpty ? reorderedEvents : memberEvents
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

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

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                theme.backgroundLayer()
                    .ignoresSafeArea()

                mainScrollView
                    .navigationBarHidden(true)

                floatingControls
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .navigationViewStyle(.stack)
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .onChange(of: selectedEvent) { oldValue, newValue in
            // When EventDetailView sheet closes (newValue becomes nil), reload events
            if oldValue != nil && newValue == nil {
                loadNextEvents()
            }
        }
        .sheet(isPresented: Binding(
            get: { spotlightMemberName != nil },
            set: { if !$0 { spotlightMemberName = nil } }
        )) {
            if let memberName = spotlightMemberName,
               let member = familyMembers.first(where: { $0.name == memberName }) {
                NavigationView {
                    SpotlightView(member: member)
                        .environment(\.managedObjectContext, viewContext)
                        .onAppear {
                            UserDefaults.standard.set(spotlightEventsPerPerson, forKey: "spotlightEventsPerPerson")
                        }
                }
                .navigationViewStyle(.stack)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSearch) {
            EventSearchView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(initialDate: nil)
                .environment(\.managedObjectContext, viewContext)
        }
        .confirmationDialog(
            "Delete Linked Copies?",
            isPresented: $showingLinkedDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Delete only this calendar", role: .destructive) {
                if let event = pendingDeleteEvent {
                    deleteEvent(event, span: pendingDeleteSpan, scope: .single)
                }
            }
            Button("Delete in all linked calendars", role: .destructive) {
                if let event = pendingDeleteEvent {
                    deleteEvent(event, span: pendingDeleteSpan, scope: .allLinked)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteEvent = nil
            }
        } message: {
            Text("This event is linked to other calendars. Delete only here or everywhere?")
        }
    }

    // MARK: - Child Views

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                contentView

                // AdMob Banner - only show for free users
                if !appSettingsManager.isProUser {
                    AdBannerContainer(
                        adUnitID: "ca-app-pub-3940256099942544/6300978111", // Test ad unit (for development)
                        isProUser: appSettingsManager.isProUser,
                        theme: theme
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .background(Color.clear)
        .refreshable {
            await refreshAllData()
        }
        .onAppear(perform: setupView)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Delay to allow EventKit to repopulate cache after resetStore() in FamCalApp
                // This prevents events from disappearing when returning from background
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    // Refresh silently if we already have cached events (no loading flash)
                    loadNextEvents(showLoadingState: memberEvents.isEmpty)
                    loadAvailableCalendars()
                }
            }
        }
        .onChange(of: familyMembers.count) { _, _ in loadNextEvents() }
        .onChange(of: memberCalendarLinks.count) { _, _ in loadNextEvents() }
        .onChange(of: personalCalendars.count) { _, _ in loadNextEvents() }
        .onChange(of: familyEvents.count) { _, _ in loadNextEvents() }
        .onChange(of: appSettingsManager.eventsPerPerson) { _, _ in loadNextEvents() }
        .onChange(of: appSettingsManager.autoRefreshInterval) { _, _ in startRefreshTimer() }
        .onChange(of: currentTime) { _, _ in /* Trigger re-render for status updates */ }
        .onChange(of: appSettingsManager.familyMemberOrder) { _, newOrder in
            applyOrderFromSettings(newOrder)
        }
        .onDisappear(perform: cleanupView)
    }

    private var floatingControls: some View {
        HStack(alignment: .center) {
            controlStack

            Spacer()

            addEventButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var controlStack: some View {
        HStack(spacing: 12) {
            ControlCircleButton(imageName: "gearshape.fill", action: {
                showingSettings = true
            }, theme: theme)
            .accessibilityLabel("Open settings")

            ControlCircleButton(imageName: "magnifyingglass", action: {
                if let action = onSearchRequested {
                    action()
                } else {
                    showingSearch = true
                }
            }, theme: theme)
            .accessibilityLabel("Search events")

            ControlCircleButton(imageName: "calendar", action: {
                onChangeViewRequested?()
            }, theme: theme)
            .accessibilityLabel("Switch view")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.floatingControlsBackground)
        .overlay(
            Capsule()
                .stroke(theme.floatingControlsBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }

    private var addEventButton: some View {
        Button(action: {
            if let action = onAddEventRequested {
                action()
            } else {
                showingAddEvent = true
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(theme.accentFillStyle())
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        }
        .accessibilityLabel("Add event")
    }

    private struct ControlCircleButton: View {
        let imageName: String
        let action: () -> Void
        let theme: AppTheme

        var body: some View {
            Button(action: action) {
                Image(systemName: imageName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.floatingControlForeground)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(theme.chromeOverlay)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoadingEvents {
            loadingView
        } else if memberEvents.isEmpty {
            emptyStateView
        } else {
            eventsListView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(theme.accentColor)

            Text("Fetching upcoming events...")
                .font(.system(size: 15))
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(secondaryTextColor)

            Text("No upcoming events")
                .font(.system(size: 16, weight: .semibold))

            Text("Link family calendars in Settings to see everyone's next plans.")
                .font(.system(size: 14))
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var eventsListView: some View {
        let isLandscape = verticalSizeClass == .compact
        
        return VStack(alignment: .leading, spacing: 24) {
            // MARK: Next Events Section
            VStack(alignment: .leading, spacing: 16) {
                let spacing: CGFloat = nextEventColumns <= 2 ? 24 : 12
                let columns = isLandscape
                    ? Array(repeating: GridItem(.flexible(), spacing: spacing), count: nextEventColumns + 2)
                    : Array(repeating: GridItem(.flexible(), spacing: spacing), count: nextEventColumns)

                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(displayedEvents) { memberGroup in
                        if let nextEvent = memberGroup.nextEvent,
                           !isEffectivelyAllDay(nextEvent),
                           nextEvent.endDate > Date() {
                            Button(action: {
                                spotlightMemberName = memberGroup.memberName
                            }) {
                                nextEventCard(for: memberGroup, event: nextEvent)
                            }
                            .buttonStyle(.plain)
                            .opacity(draggedMemberName == memberGroup.memberName ? 0.5 : 1.0)
                            .scaleEffect(draggedMemberName == memberGroup.memberName ? 0.95 : 1.0)
                            .background(
                                targetMemberName == memberGroup.memberName ?
                                Color.blue.opacity(0.1) : Color.clear
                            )
                            .cornerRadius(12)
                            .onDrag {
                                resetDragState()
                                draggedMemberName = memberGroup.memberName
                                draggedMemberID = memberGroup.id
                                reorderedEvents = memberEvents
                                scheduleDragResetFallback()
                                return NSItemProvider(object: memberGroup.id.uriRepresentation().absoluteString as NSString)
                            }
                            .dropDestination(for: String.self) { droppedItems, _ in
                                if let sourceIDString = droppedItems.first,
                                   let sourceID = objectID(from: sourceIDString) {
                                    performDragDrop(from: sourceID, to: memberGroup.id)
                                    if !reorderedEvents.isEmpty {
                                        memberEvents = reorderedEvents
                                    }
                                    loadNextEvents()
                                }
                                resetDragState()
                                return true
                            } isTargeted: { isTargeted in
                                if isTargeted {
                                    targetMemberName = memberGroup.memberName
                                    // Reorder while dragging over
                                    if let draggedID = draggedMemberID {
                                        reorderWhileDragging(from: draggedID, to: memberGroup.id)
                                    }
                                } else {
                                    targetMemberName = nil
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, nextEventColumns > 2 ? 16 : 32)
            }

            // MARK: Important Events Section
            let allImportantEvents = memberEvents
                .flatMap { $0.upcomingEvents }
                .filter { $0.isImportant }
                .reduce(into: [GroupedEvent]()) { result, event in
                    if !result.contains(where: { $0.eventIdentifier == event.eventIdentifier }) {
                        result.append(event)
                    }
                }
                .sorted { $0.startDate < $1.startDate }

            if !allImportantEvents.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Important Events")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 16)

                    if isLandscape {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 12) {
                            ForEach(allImportantEvents, id: \.id) { event in
                                eventButton(for: event)
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(allImportantEvents, id: \.id) { event in
                                eventButton(for: event)
                            }
                        }
                    }
                }
            }

            // MARK: Upcoming Events Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Upcoming Events")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 16)

                if isLandscape {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 20, alignment: .top), GridItem(.flexible(), spacing: 20, alignment: .top)], spacing: 20) {
                        ForEach(displayedEvents) { memberGroup in
                            if !memberGroup.upcomingEvents.isEmpty {
                                memberUpcomingEventsColumn(memberGroup: memberGroup)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(displayedEvents) { memberGroup in
                            if !memberGroup.upcomingEvents.isEmpty {
                                memberUpcomingEventsColumn(memberGroup: memberGroup)
                            }
                        }
                    }
                }
            }
        }
    }

    private func memberUpcomingEventsColumn(memberGroup: MemberEventGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Member name header
            Text(memberGroup.memberName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(secondaryTextColor)
                .padding(.horizontal, verticalSizeClass == .compact ? 0 : 16)

            // Events for this member (limited by eventsPerPerson, only future events)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(memberGroup.upcomingEvents, id: \.id) { groupedEvent in
                    eventButton(for: groupedEvent)
                }
            }
        }
    }

    private func eventButton(for groupedEvent: GroupedEvent) -> some View {
        Button(action: {
            selectedEvent = UpcomingCalendarEvent(
                id: groupedEvent.eventIdentifier,
                title: groupedEvent.title,
                location: groupedEvent.location,
                startDate: groupedEvent.startDate,
                endDate: groupedEvent.endDate,
                calendarID: groupedEvent.calendarID,
                calendarColor: groupedEvent.memberColor,
                calendarTitle: groupedEvent.calendarTitle,
                hasRecurrence: groupedEvent.hasRecurrence,
                recurrenceRule: nil,
                isAllDay: groupedEvent.isAllDay
            )
            // showingEventDetail = true // No longer needed, setting selectedEvent triggers sheet
        }) {
            eventCard(groupedEvent)
        }
        .buttonStyle(.plain)
        .contextMenu {
            let event = UpcomingCalendarEvent(
                id: groupedEvent.eventIdentifier,
                title: groupedEvent.title,
                location: groupedEvent.location,
                startDate: groupedEvent.startDate,
                endDate: groupedEvent.endDate,
                calendarID: groupedEvent.calendarID,
                calendarColor: groupedEvent.memberColor,
                calendarTitle: groupedEvent.calendarTitle,
                hasRecurrence: groupedEvent.hasRecurrence,
                recurrenceRule: nil,
                isAllDay: groupedEvent.isAllDay
            )

            Button(action: { duplicateEvent(event) }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            // Mark/Unmark as Important
            if groupedEvent.isImportant {
                Button(action: { toggleImportance(for: event, isImportant: false) }) {
                    Label("Unmark Important", systemImage: "star.slash")
                }
            } else {
                Button(action: { toggleImportance(for: event, isImportant: true) }) {
                    Label("Mark as Important", systemImage: "star")
                }
            }

            // Move to calendar
            Menu {
                ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                    Button(action: {
                        moveEventToCalendar(event, calendarID: calendar.calendarIdentifier)
                    }) {
                        HStack {
                            Text(calendar.title)
                            if calendar.calendarIdentifier == event.calendarID {
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
            if groupedEvent.hasRecurrence {
                Menu {
                    Button(action: { confirmDelete(event, span: .thisEvent) }) {
                        Label("Delete This Event", systemImage: "trash")
                    }
                    Button(role: .destructive, action: { confirmDelete(event, span: .futureEvents) }) {
                        Label("Delete This & Future Events", systemImage: "trash")
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button(role: .destructive, action: { confirmDelete(event, span: .thisEvent) }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func nextEventCard(for memberGroup: MemberEventGroup, event: GroupedEvent) -> some View {
        let (statusText, statusColor) = getEventStatus(event)
        let barColor = Color(uiColor: event.calendarColor)
        let barWidth: CGFloat = 6
        
        // Dynamic font sizing based on columns
        let titleSize: CGFloat = nextEventColumns >= 4 ? 11 : (nextEventColumns == 3 ? 12 : 14)
        let detailSize: CGFloat = nextEventColumns >= 4 ? 9 : (nextEventColumns == 3 ? 10 : 11)
        
        // Format date with relative labels
        let dateText = formatRelativeDate(event.startDate)

        return ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackground)

            // Card content without the bar
            VStack(alignment: .leading, spacing: 6) {
                // Member name
                Text(memberGroup.memberName)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Event title
                Text(event.title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                // Day name and date (with relative formatting)
                Text(dateText)
                    .font(.system(size: detailSize, weight: .semibold))
                    .foregroundColor(secondaryTextColor)

                // Time on its own line to avoid truncation
                if let timeRange = event.timeRange {
                    Text(timeRange)
                        .font(.system(size: detailSize, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(secondaryTextColor)
                }
                
                // Location (only in 2-column view)
                if nextEventColumns <= 2, let location = event.location {
                    let firstLine = location.split(separator: "\n").first.map(String.init) ?? location
                    let savedAddress = getSavedAddress(for: firstLine)
                    let displayText = savedAddress?.name ?? firstLine
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: detailSize - 1, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        Text(displayText)
                            .font(.system(size: detailSize, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                // Status on separate line with color
                Text(statusText)
                    .font(.system(size: detailSize, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .padding(12)
        }

        .aspectRatio(1, contentMode: .fill)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .overlay(
            // Left side bar - positioned outside the card, full height with rounded corners
            Rectangle()
                .fill(barColor)
                .frame(width: barWidth)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 12
                ))
                .frame(maxHeight: .infinity, alignment: .center),
            alignment: .leading
        )
        .overlay(alignment: .bottomTrailing) {
            if nextEventColumns <= 2, let bubble = timeBubble(for: event) {
                Text(bubble.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(bubble.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bubble.background)
                    .clipShape(Capsule())
                    .padding(10)
            }
        }
    }

    private func getTimeUntilEvent(_ eventDate: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: eventDate)

        if let days = components.day, days > 0 {
            return days == 1 ? "Tomorrow" : "In \(days) days"
        } else if let hours = components.hour, hours > 0 {
            return "In \(hours) hrs"
        } else if let minutes = components.minute, minutes > 0 {
            return "In \(minutes) mins"
        } else {
            return "In Progress"
        }
    }

    private func eventCard(_ groupedEvent: GroupedEvent) -> some View {
        let dateBoxWidth: CGFloat = 64
        let cardCornerRadius: CGFloat = 16
        let now = Date()
        let isInProgress = groupedEvent.startDate <= now && now < groupedEvent.endDate

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    groupedEvent.isImportant ? Color.orange.opacity(0.15) :
                    isInProgress ? Color.green.opacity(0.12) :
                    theme.cardBackground
                )

            // Colored date panel that fills the card height with rounded left edge
            Group {
                if groupedEvent.memberColors.count > 1 {
                    LinearGradient(
                        gradient: Gradient(colors: groupedEvent.memberColors.map { Color(uiColor: $0) }),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(uiColor: groupedEvent.memberColor)
                }
            }
            .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))
            .frame(width: dateBoxWidth)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(Self.dayOfWeekFormatter.string(from: groupedEvent.startDate))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    Text(Self.dayFormatter.string(from: groupedEvent.startDate))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(Self.monthFormatter.string(from: groupedEvent.startDate))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(width: dateBoxWidth)
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 4) {
                    // Title with start time on the right
                    HStack(alignment: .top, spacing: 8) {
                        Text(groupedEvent.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if !groupedEvent.isAllDay, let timeRange = groupedEvent.timeRange {
                            let startTime = timeRange.split(separator: "–").first.map(String.init).map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                            Text(startTime)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    // Location with end time
                    if let location = groupedEvent.location {
                        let firstLine = location.split(separator: "\n").first.map(String.init) ?? location
                        let savedAddress = getSavedAddress(for: firstLine)
                        let displayText = savedAddress?.name ?? firstLine
                        let mapAddress = savedAddress?.address ?? firstLine
                        
                        Button(action: { MapsUtility.openLocation(mapAddress, in: defaultMapsApp) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryTextColor)
                            Text(displayText)
                                .font(.system(size: 11.5))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)

                                Spacer(minLength: 0)

                                if !groupedEvent.isAllDay, let timeRange = groupedEvent.timeRange {
                                    let endTime = timeRange.split(separator: "–").last.map(String.init).map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                                    Text(endTime)
                                        .font(.system(size: 11, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundColor(secondaryTextColor)
                                        .lineLimit(1)
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } else if !groupedEvent.isAllDay, let timeRange = groupedEvent.timeRange {
                        // Show time if no location
                        let endTime = timeRange.split(separator: "–").last.map(String.init).map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                        HStack(spacing: 0) {
                            Spacer()
                            Text(endTime)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    // Driver (if available)
                    if let driverName = groupedEvent.driverName {
                        let driverPhone = fetchDriverPhoneForEvent(groupedEvent.eventIdentifier)
                        if let phone = driverPhone, !phone.isEmpty {
                            Link(destination: URL(string: "tel:\(phone)")!) {
                                HStack(spacing: 8) {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(secondaryTextColor)
                                    Text(driverName)
                                        .font(.system(size: 12))
                                        .foregroundColor(secondaryTextColor)
                                        .lineLimit(1)
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryTextColor)
                                Text(driverName)
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryTextColor)
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
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .overlay(
            Group {
                if groupedEvent.isImportant {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(8)
                }
            },
            alignment: .bottomTrailing
        )
    }

    // MARK: - View Lifecycle

    private func setupView() {
        loadAvailableCalendars()

        // Apply initial order from settings if available
        if !appSettingsManager.familyMemberOrder.isEmpty {
            applyOrderFromSettings(appSettingsManager.familyMemberOrder)
        }

        // Load fresh events in background (cached events already displayed)
        // Use a small delay to ensure view is fully initialized
        let hasCachedEvents = !memberEvents.isEmpty
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Only show loading state if we have no cached data to display
            loadNextEvents(showLoadingState: !hasCachedEvents)
        }

        // Set up notification observer for calendar changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { _ in
            // Refresh silently when calendars change
            loadNextEvents(showLoadingState: false)
            loadAvailableCalendars()
        }

        // Set up notification observer for personal calendar visibility changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("PersonalCalendarVisibilityChanged"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔔 Personal calendar visibility changed, reloading events...")
            // Small delay to ensure CoreData has propagated the change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Refresh silently for visibility changes
                loadNextEvents(showLoadingState: false)
            }
        }

        // Set up auto-refresh timer
        startRefreshTimer()
    }

    private func cleanupView() {
        eventsTask?.cancel()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.EKEventStoreChanged, object: eventStore)
        stopRefreshTimer()
    }

    @MainActor
    private func startRefreshTimer() {
        stopRefreshTimer()
        // Refresh data on interval and keep current time updated for status indicators
        let interval = TimeInterval(max(autoRefreshInterval, 1) * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                currentTime = Date()
                await dataManager.fetchUserData()
                // Refresh silently in background (no loading state flash)
                loadNextEvents(showLoadingState: false)
            }
        }
        currentTime = Date()
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Data Loading

    /// Populate missing calendarID values in FamilyMemberCalendar entries by matching calendar names
    /// This is needed because calendar_id is not synced from Supabase (device-specific), so we match locally
    private func populateMissingCalendarIDs() {
        print("🔍 DEBUG populateMissingCalendarIDs: Starting...")
        let availableCalendars = CalendarManager.shared.fetchAvailableCalendars()
        print("🔍 DEBUG populateMissingCalendarIDs: Found \(availableCalendars.count) available calendars")

        for link in memberCalendarLinks {
            // Skip if already has calendarID
            if link.calendarID != nil && !link.calendarID!.isEmpty {
                continue
            }

            // Try to find matching calendar by name
            guard let calendarName = link.calendarName else { continue }
            if let matchingCalendar = availableCalendars.first(where: { $0.title == calendarName }) {
                link.calendarID = matchingCalendar.id
                print("✅ DEBUG populateMissingCalendarIDs: Populated member calendar '\(calendarName)': \(matchingCalendar.id)")
            }
        }

        // Also populate for shared calendars
        for member in familyMembers {
            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for sharedCal in sharedCals {
                    if sharedCal.calendarID == nil || sharedCal.calendarID!.isEmpty {
                        guard let calendarName = sharedCal.calendarName else { continue }
                        if let matchingCalendar = availableCalendars.first(where: { $0.title == calendarName }) {
                            sharedCal.calendarID = matchingCalendar.id
                            print("✅ DEBUG populateMissingCalendarIDs: Populated shared calendar '\(calendarName)': \(matchingCalendar.id)")
                        }
                    }
                }
            }
        }

        // Also populate for personal calendars
        print("🔍 DEBUG populateMissingCalendarIDs: Processing \(personalCalendars.count) personal calendars")
        for personalCal in personalCalendars {
            print("🔍 DEBUG populateMissingCalendarIDs: Personal calendar '\(personalCal.calendarName ?? "nil")' has ID: '\(personalCal.calendarID ?? "nil")'")
            if personalCal.calendarID == nil || personalCal.calendarID!.isEmpty {
                guard let calendarName = personalCal.calendarName else {
                    print("❌ DEBUG populateMissingCalendarIDs: Personal calendar has no name")
                    continue
                }
                if let matchingCalendar = availableCalendars.first(where: { $0.title == calendarName }) {
                    personalCal.calendarID = matchingCalendar.id
                    print("✅ DEBUG populateMissingCalendarIDs: Populated personal calendar '\(calendarName)': \(matchingCalendar.id)")
                } else {
                    print("❌ DEBUG populateMissingCalendarIDs: No matching calendar found for '\(calendarName)'")
                    print("🔍 DEBUG populateMissingCalendarIDs: Available calendar names: \(availableCalendars.map { $0.title }.joined(separator: ", "))")
                }
            }
        }

        // Save changes
        do {
            try viewContext.save()
            print("✅ DEBUG populateMissingCalendarIDs: Saved changes to CoreData")
        } catch {
            print("❌ DEBUG populateMissingCalendarIDs: Failed to save: \(error)")
        }
    }

    private func loadNextEvents(showLoadingState: Bool = true) {
        eventsTask?.cancel()
        eventsTask = Task { @MainActor in
            if showLoadingState {
                isLoadingEvents = true
            }
            defer { isLoadingEvents = false }
            resetDragState()

            // Populate missing calendar IDs by matching calendar names
            populateMissingCalendarIDs()

            // Clean up stale FamilyEvent records BEFORE loading to prevent rogue events
            await cleanupStaleEvents()

            guard !familyMembers.isEmpty else {
                memberEvents = []
                return
            }

            let now = Date()

            // Fetch important events
            let importantRequest = FamilyEvent.fetchRequest()
            importantRequest.predicate = NSPredicate(format: "isImportant == YES")
            let importantEvents = try? viewContext.fetch(importantRequest)
            let importantEventIDs = Set(importantEvents?.compactMap { $0.eventIdentifier } ?? [])

            // Map calendars by id/name for resolving personal calendars
            let calendarById: [String: EKCalendar] = Dictionary(uniqueKeysWithValues: availableCalendars.map { ($0.calendarIdentifier, $0) })
            var calendarByTitle: [String: EKCalendar] = [:]
            for cal in availableCalendars {
                calendarByTitle[cal.title] = cal
            }

            // Build map of member → their calendar IDs (from memberCalendarLinks and shared calendars)
            var memberCalendarMap: [NSManagedObjectID: (member: FamilyMember, calendars: Set<String>)] = [:]

            for link in memberCalendarLinks {
                guard let member = link.familyMember,
                      let calendarID = link.calendarID else { continue }
                var entry = memberCalendarMap[member.objectID] ?? (member, [])
                entry.calendars.insert(calendarID)
                memberCalendarMap[member.objectID] = entry
            }

        // Add personal calendars for the current user
        print("🔍 DEBUG: Total personal calendars in CoreData: \(personalCalendars.count)")
        for pc in personalCalendars {
            print("🔍 DEBUG: Personal Calendar: \(pc.calendarName ?? "nil") | ID: \(pc.calendarID ?? "nil") | Next: \(pc.showInNext) | Spotlight: \(pc.showInSpotlight) | Upcoming: \(pc.showInUpcoming)")
        }

        print("🔍 DEBUG: Available family members:")
        for fm in familyMembers {
            print("   - \(fm.name ?? "nil") (ID: \(fm.id?.uuidString ?? "nil"))")
        }

        if let linkedMemberId = appSettingsManager.linkedFamilyMemberId,
           let linkedMember = familyMembers.first(where: { $0.id?.uuidString.lowercased() == linkedMemberId.lowercased() }) {
            print("🔍 DEBUG: Linked member found: \(linkedMember.name ?? "nil") (ID: \(linkedMemberId))")
            var entry = memberCalendarMap[linkedMember.objectID] ?? (linkedMember, [])
            for personalCal in personalCalendars {
                // Only include if toggled into at least one main view surface
                let shouldInclude = personalCal.showInNext
                    || personalCal.showInSpotlight
                    || personalCal.showInUpcoming
                print("🔍 DEBUG: Personal Calendar '\(personalCal.calendarName ?? "nil")' shouldInclude: \(shouldInclude)")
                guard shouldInclude else {
                    print("⚠️ DEBUG: Skipping personal calendar '\(personalCal.calendarName ?? "nil")' - not enabled for any view")
                    continue
                }

                var resolvedID: String?
                if let storedID = personalCal.calendarID {
                    resolvedID = storedID
                    print("🔍 DEBUG: Personal Calendar '\(personalCal.calendarName ?? "nil")' has stored ID: \(storedID)")
                    // If ID not found locally, try to find by name
                    if calendarById[storedID] == nil, let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                        print("⚠️ Personal Calendar ID mismatch for '\(name)'. Resolved by name: \(storedID) -> \(localCal.calendarIdentifier)")
                        resolvedID = localCal.calendarIdentifier
                    }
                } else if let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                    print("ℹ️ Personal Calendar missing ID, resolved by name: \(name) -> \(localCal.calendarIdentifier)")
                    resolvedID = localCal.calendarIdentifier
                }

                if let resolvedID {
                    print("✅ DEBUG: Adding personal calendar '\(personalCal.calendarName ?? "nil")' with ID: \(resolvedID) to member '\(linkedMember.name ?? "nil")'")
                    entry.calendars.insert(resolvedID)
                } else {
                    print("❌ DEBUG: Failed to resolve ID for personal calendar '\(personalCal.calendarName ?? "nil")'")
                }
            }
            print("🔍 DEBUG: Total calendar IDs for linked member '\(linkedMember.name ?? "nil")': \(entry.calendars.count)")
            memberCalendarMap[linkedMember.objectID] = entry
        } else {
            print("⚠️ DEBUG: No linked member found! linkedFamilyMemberId: \(appSettingsManager.linkedFamilyMemberId ?? "nil")")
        }

            // Process events per member
            var memberEventGroups: [MemberEventGroup] = []

            for member in familyMembers {
                var calendarIDs = memberCalendarMap[member.objectID]?.calendars ?? []

                // Add shared calendars
                if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                    for sharedCal in sharedCals {
                        if let calendarID = sharedCal.calendarID {
                            calendarIDs.insert(calendarID)
                        }
                    }
                }

                guard !calendarIDs.isEmpty else { continue }

                print("🔍 DEBUG: Fetching events for member '\(member.name ?? "nil")' from \(calendarIDs.count) calendars: \(calendarIDs)")

                // Fetch events for this member
                let upcomingEvents = await CalendarManager.shared.fetchNextEventsAsync(
                    for: Array(calendarIDs),
                    limit: 0, // Unlimited so we don't miss future events
                    pastDays: appSettingsManager.eventsPastDays,
                    futureDays: appSettingsManager.eventsFutureDays
                )

                print("✅ DEBUG: Found \(upcomingEvents.count) events for member '\(member.name ?? "nil")'")

                // Convert to EventItem and expand recurring events
                var memberEventItems: [EventItem] = []
                for event in upcomingEvents {
                    // Each EKEvent occurrence from EventKit already respects cancelled/edited instances,
                    // so use it directly instead of manually expanding recurrence rules.
                    let timeRange = formatTimeRange(event.startDate, event.endDate)
                    let displayID = "\(event.id)|\(event.startDate.timeIntervalSince1970)"
                    let driverName = fetchDriverForEvent(event.id)
                    memberEventItems.append(EventItem(
                        id: displayID,
                        eventIdentifier: event.id,
                        title: event.title,
                        location: event.location,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        timeRange: timeRange,
                        memberName: member.name ?? "Unknown",
                        memberColor: event.calendarColor,
                        calendarColor: event.calendarColor,
                        calendarTitle: event.calendarTitle,
                        calendarID: event.calendarID,
                        hasRecurrence: event.hasRecurrence,
                        recurrenceRule: event.recurrenceRule,
                        isAllDay: event.isAllDay,
                        driverName: driverName,
                        isImportant: importantEventIDs.contains(event.id)
                    ))
                }

                // Sort member's events by start date
                memberEventItems.sort { $0.startDate < $1.startDate }

                // Filter to only future or in-progress events
                let futureEventItems = memberEventItems.filter { $0.endDate > now }

                // Group this member's events by details (no longer needed to handle recurring specially)
                let groupedMemberEvents = groupEventsByDetails(futureEventItems)

                // Sort grouped events by start date (ensure chronological order)
                let sortedGroupedEvents = groupedMemberEvents.sorted { $0.startDate < $1.startDate }
                print("🔍 DEBUG: Member '\(member.name ?? "nil")' - sortedGroupedEvents count: \(sortedGroupedEvents.count)")
                print("🔍 DEBUG: eventsPerPerson limit: \(eventsPerPerson)")

                // Filter out all-day events for upcoming events display
                let nonAllDayEvents = sortedGroupedEvents.filter { !isEffectivelyAllDay($0) }
                let limitedEvents = Array(nonAllDayEvents.prefix(eventsPerPerson))
                print("🔍 DEBUG: Member '\(member.name ?? "nil")' - limitedEvents count: \(limitedEvents.count)")

                // Create member event group
                let memberColor = Color.fromHex(member.colorHex ?? "#555555")
                // Get next non-all-day event for spotlight
                let nextNonAllDayEvent = sortedGroupedEvents.first { !isEffectivelyAllDay($0) }
                let memberGroup = MemberEventGroup(
                    id: member.objectID,
                    memberName: member.name ?? "Unknown",
                    sortOrder: member.sortOrder,
                    memberColor: memberColor,
                    nextEvent: nextNonAllDayEvent,
                    upcomingEvents: limitedEvents
                )

                print("🔍 DEBUG: Created memberGroup for '\(member.name ?? "nil")' - upcomingEvents: \(memberGroup.upcomingEvents.count), nextEvent: \(nextNonAllDayEvent?.title ?? "nil")")
                memberEventGroups.append(memberGroup)
            }

            // Keep member order consistent with stored sortOrder (fallback to name to break ties)
            memberEventGroups.sort {
                if $0.sortOrder == $1.sortOrder {
                    return $0.memberName.localizedCaseInsensitiveCompare($1.memberName) == .orderedAscending
                }
                return $0.sortOrder < $1.sortOrder
            }

            print("🔍 DEBUG: Final memberEventGroups count: \(memberEventGroups.count)")
            for group in memberEventGroups {
                print("   - \(group.memberName): \(group.upcomingEvents.count) events, nextEvent: \(group.nextEvent?.title ?? "nil")")
            }

            memberEvents = memberEventGroups

            // Cache the events for instant display on next app launch
            await cacheLoadedEvents(memberEventGroups)
        }
    }

    /// Convert loaded member event groups to cacheable DTOs and save
    private func cacheLoadedEvents(_ memberEventGroups: [MemberEventGroup]) async {
        let dtos = memberEventGroups.map { group -> MemberEventGroupDTO in
            let nextEventDTO = group.nextEvent.map { event -> GroupedEventDTO in
                GroupedEventDTO(
                    id: event.id,
                    eventIdentifier: event.eventIdentifier,
                    title: event.title,
                    timeRange: event.timeRange,
                    location: event.location,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    memberNames: event.memberNames,
                    memberColorHex: event.memberColor.hex(),
                    calendarColorHex: event.calendarColor.hex(),
                    calendarTitle: event.calendarTitle,
                    calendarID: event.calendarID,
                    memberColorsHex: event.memberColors.map { $0.hex() },
                    hasRecurrence: event.hasRecurrence,
                    isAllDay: event.isAllDay,
                    driverName: event.driverName,
                    isImportant: event.isImportant
                )
            }

            let upcomingEventDTOs = group.upcomingEvents.map { event -> GroupedEventDTO in
                GroupedEventDTO(
                    id: event.id,
                    eventIdentifier: event.eventIdentifier,
                    title: event.title,
                    timeRange: event.timeRange,
                    location: event.location,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    memberNames: event.memberNames,
                    memberColorHex: event.memberColor.hex(),
                    calendarColorHex: event.calendarColor.hex(),
                    calendarTitle: event.calendarTitle,
                    calendarID: event.calendarID,
                    memberColorsHex: event.memberColors.map { $0.hex() },
                    hasRecurrence: event.hasRecurrence,
                    isAllDay: event.isAllDay,
                    driverName: event.driverName,
                    isImportant: event.isImportant
                )
            }

            return MemberEventGroupDTO(
                memberName: group.memberName,
                sortOrder: group.sortOrder,
                memberColorHex: group.memberColor.toHex(),
                nextEvent: nextEventDTO,
                upcomingEvents: upcomingEventDTOs
            )
        }

        await EventCache.shared.save(dtos)
    }

    private func cleanupStaleEvents() async {
        let allFamilyEvents = familyEvents
        var eventIdentifiersToDelete: [String] = []

        // Check each FamilyEvent to see if its corresponding iOS calendar event still exists
        for familyEvent in allFamilyEvents {
            guard let eventIdentifier = familyEvent.eventIdentifier else { continue }

            // Try to find the event in iOS calendar
            if CalendarManager.shared.getEvent(withIdentifier: eventIdentifier) == nil &&
               CalendarManager.shared.fetchEventDetails(withIdentifier: eventIdentifier) == nil {
                // Event doesn't exist in iOS calendar anymore - mark for deletion
                eventIdentifiersToDelete.append(eventIdentifier)
            }
        }

        // Delete stale records in batch
        if !eventIdentifiersToDelete.isEmpty {
            let fetchRequest = FamilyEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventIdentifier IN %@", eventIdentifiersToDelete)

            do {
                let staleEvents = try viewContext.fetch(fetchRequest)
                for staleEvent in staleEvents {
                    viewContext.delete(staleEvent)
                    print("🗑️ Deleted stale FamilyEvent record for: \(staleEvent.eventIdentifier ?? "unknown")")
                }

                if !staleEvents.isEmpty {
                    try viewContext.save()
                    print("✅ Cleaned up \(staleEvents.count) stale event record(s)")
                }
            } catch {
                print("⚠️ Error cleaning up stale events: \(error.localizedDescription)")
            }
        }
    }

    private func fetchDriverForEvent(_ eventIdentifier: String) -> String? {
        // Use FetchedResults for reactive updates instead of synchronous fetch
        if let familyEvent = familyEvents.first(where: { $0.eventIdentifier == eventIdentifier }) {
            return familyEvent.driver?.name
        }
        return nil
    }

    private func fetchDriverPhoneForEvent(_ eventIdentifier: String) -> String? {
        // Use FetchedResults for reactive updates instead of synchronous fetch
        if let familyEvent = familyEvents.first(where: { $0.eventIdentifier == eventIdentifier }) {
            return familyEvent.driver?.phone
        }
        return nil
    }

    private func groupEventsByDetails(_ events: [EventItem]) -> [GroupedEvent] {
        var grouped: [String: GroupedEvent] = [:]

        for event in events {
            // Create a unique key based on event details and start time
            let startKey = String(event.startDate.timeIntervalSinceReferenceDate)
            let key = "\(event.title)|\(startKey)|\(event.timeRange ?? "all-day")|\(event.location ?? "")"

            if let existing = grouped[key] {
                // Build updated member names list
                var updatedNames = existing.memberNames
                if !updatedNames.contains(event.memberName) {
                    updatedNames.append(event.memberName)
                }

                // Build updated colors list
                var updatedColors = existing.memberColors
                if !updatedColors.contains(where: { $0.cgColor == event.memberColor.cgColor }) {
                    updatedColors.append(event.memberColor)
                }

                // Create new merged event
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
                    calendarColor: existing.calendarColor,
                    calendarTitle: existing.calendarTitle,
                    calendarID: existing.calendarID,
                    memberColors: updatedColors,
                    hasRecurrence: existing.hasRecurrence || event.hasRecurrence,
                    isAllDay: existing.isAllDay,
                    driverName: existing.driverName ?? event.driverName,
                    isImportant: existing.isImportant || event.isImportant
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
                    calendarColor: event.calendarColor,
                    calendarTitle: event.calendarTitle,
                    calendarID: event.calendarID,
                    memberColors: [event.memberColor],
                    hasRecurrence: event.hasRecurrence,
                    isAllDay: event.isAllDay,
                    driverName: event.driverName,
                    isImportant: event.isImportant
                )
            }
        }

        return grouped.values.sorted { $0.startDate < $1.startDate }
    }

    /// Check if an event is effectively all-day (either marked as all-day or spans 00:00-23:59)
    private func isEffectivelyAllDay(_ event: GroupedEvent) -> Bool {
        // Check EventKit isAllDay flag
        if event.isAllDay {
            return true
        }

        // Check if it's a 00:00-23:59 event (all-day event formatted as timed)
        if event.timeRange == "00:00 – 23:59" {
            return true
        }

        return false
    }

    private func formatTimeRange(_ startDate: Date, _ endDate: Date) -> String? {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)

        // Check if it's an all-day event (00:00:00 to 00:00:00)
        if startComponents.hour == 0 && startComponents.minute == 0 && startComponents.second == 0 &&
           endComponents.hour == 0 && endComponents.minute == 0 && endComponents.second == 0 {
            return nil
        }

        let startTime = Self.timeFormatter.string(from: startDate)
        let endTime = Self.timeFormatter.string(from: endDate)
        return "\(startTime) – \(endTime)"
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
    
    private func reloadEvents() async {
        loadNextEvents()
        // Wait for the task to complete with a brief delay to show refresh indicator
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    private func refreshAllData() async {
        await dataManager.fetchUserData()
        loadNextEvents()
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            // Use the standard format for dates beyond tomorrow
            return "\(Self.dayOfWeekFormatter.string(from: date)), \(Self.dateFormatter.string(from: date))"
        }
    }

    private func getEventStatus(_ event: GroupedEvent) -> (status: String, color: Color) {
        let now = currentTime

        // Check if event is in progress
        if event.startDate <= now && now < event.endDate {
            return ("In Progress", .orange)
        }

        // Check if event is upcoming soon (within 1 hour)
        let oneHourFromNow = now.addingTimeInterval(3600)
        if event.startDate > now && event.startDate <= oneHourFromNow {
            return ("Starting Soon", Color(red: 0.33, green: 0.33, blue: 0.33))
        }

        // Default to upcoming
        return ("Upcoming", .gray)
    }

    private func timeBubble(for event: GroupedEvent) -> (text: String, background: Color, foreground: Color)? {
        let now = currentTime
        let calendar = Calendar.current

        if now < event.startDate {
            let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: event.startDate)
            guard let text = bubbleText(from: components) else { return nil }
            let color = Color.blue
            return (text, color.opacity(0.16), color)
        } else if now < event.endDate {
            let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: event.endDate)
            guard let text = bubbleText(from: components) else { return nil }
            let color = Color.green
            return (text, color.opacity(0.16), color)
        }

        return nil
    }

    private func bubbleText(from components: DateComponents) -> String? {
        if let days = components.day, days > 0 {
            if let hours = components.hour, hours > 0 {
                return "\(days)d \(hours)h"
            }
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            if let minutes = components.minute, minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    // MARK: - Context Menu Actions

    private func loadAvailableCalendars() {
        let calendars = eventStore.calendars(for: .event)
        self.availableCalendars = calendars
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
                    loadNextEvents()
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
                loadNextEvents()
            } catch {
                print("❌ Failed to save duplicated event: \(error.localizedDescription)")
            }
        }
    }

    private func toggleImportance(for event: UpcomingCalendarEvent, isImportant: Bool) {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            let familyEvent: FamilyEvent

            if let existing = results.first {
                familyEvent = existing
            } else {
                familyEvent = FamilyEvent(context: viewContext)
                familyEvent.id = UUID()
                familyEvent.eventGroupId = UUID()
                familyEvent.eventIdentifier = event.id
                familyEvent.calendarId = event.calendarID
                familyEvent.createdAt = Date()
            }

            familyEvent.isImportant = isImportant
            try viewContext.save()
            print("✅ Toggled importance for event \(event.title): \(isImportant)")
            loadNextEvents()
        } catch {
            print("❌ Failed to toggle importance: \(error.localizedDescription)")
        }
    }

    private func confirmDelete(_ event: UpcomingCalendarEvent, span: EKSpan) {
        pendingDeleteEvent = event
        pendingDeleteSpan = span

        let linked = linkedFamilyEvents(for: event.id)
        if linked.count > 1 {
            showingLinkedDeleteDialog = true
        } else {
            deleteEvent(event, span: span, scope: .single)
        }
    }

    private func deleteEvent(_ event: UpcomingCalendarEvent, span: EKSpan = .thisEvent, scope: DeleteScope = .single) {
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

            // Always try to clean up CoreData records, even if EventKit delete fails
            // (event might already be deleted from iOS calendar)
            await NotificationManager.shared.cancelEventNotifications(for: target.id)

            let fetchRequest = FamilyEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", target.id)
            if let familyEvent = try? viewContext.fetch(fetchRequest).first {
                viewContext.delete(familyEvent)
                anyDeleted = true
            }

            if success {
                print("✅ Successfully deleted event \(target.id) from calendar")
            } else {
                print("⚠️ Event \(target.id) may have been already deleted from iOS calendar, cleaned up CoreData record")
            }
        }

        if anyDeleted {
            try? viewContext.save()
            print("✅ Cleaned up \(targets.count) event record(s)")
            await MainActor.run {
                loadNextEvents()
            }
        }
    }

    private func linkedFamilyEvents(for eventId: String) -> [FamilyEvent] {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", eventId)

        do {
            guard let current = try viewContext.fetch(fetchRequest).first else { return [] }

            var results: [FamilyEvent] = [current]
            if let groupId = current.eventGroupId {
                let groupFetch = FamilyEvent.fetchRequest()
                groupFetch.predicate = NSPredicate(format: "eventGroupId == %@", groupId as CVarArg)
                let groupResults = try viewContext.fetch(groupFetch)
                results.append(contentsOf: groupResults)
            }

            let keyed = results.compactMap { familyEvent -> (String, FamilyEvent)? in
                guard let identifier = familyEvent.eventIdentifier else { return nil }
                return (identifier, familyEvent)
            }
            let grouped = Dictionary(grouping: keyed, by: { $0.0 })
            return grouped.compactMap { _, value in value.first?.1 }
        } catch {
            print("⚠️ Failed to load linked events: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Drag and Drop

    private func reorderWhileDragging(from sourceID: NSManagedObjectID, to destID: NSManagedObjectID) {
        guard sourceID != destID else { return }
        guard let sourceIndex = reorderedEvents.firstIndex(where: { $0.id == sourceID }),
              let destIndex = reorderedEvents.firstIndex(where: { $0.id == destID }) else {
            return
        }

        // Only reorder if needed
        guard sourceIndex != destIndex else { return }

        var newEvents = reorderedEvents
        let sourceEvent = newEvents[sourceIndex]
        newEvents.remove(at: sourceIndex)
        newEvents.insert(sourceEvent, at: destIndex)

        reorderedEvents = newEvents
    }

    private func performDragDrop(from sourceID: NSManagedObjectID, to destID: NSManagedObjectID) {
        // Work with the latest drag order (fall back to the current display order)
        var finalOrder = reorderedEvents
        if finalOrder.isEmpty {
            finalOrder = memberEvents
            if let sourceIndex = finalOrder.firstIndex(where: { $0.id == sourceID }),
               let destIndex = finalOrder.firstIndex(where: { $0.id == destID }) {
                let moved = finalOrder.remove(at: sourceIndex)
                finalOrder.insert(moved, at: destIndex)
            } else {
                return
            }
        }

        // Persist the new order by assigning sequential sortOrder values
        for (index, group) in finalOrder.enumerated() {
            if let member = familyMembers.first(where: { $0.objectID == group.id }) {
                member.sortOrder = Int16(index)
            }
        }

        do {
            try viewContext.save()
            memberEvents = finalOrder
            if let sourceName = memberEvents.first(where: { $0.id == sourceID })?.memberName,
               let destName = memberEvents.first(where: { $0.id == destID })?.memberName {
                print("✅ Reordered: \(sourceName) moved to position of \(destName)")
            } else {
                print("✅ Reordered members and saved new order")
            }
            draggedMemberName = nil
            draggedMemberID = nil
            targetMemberName = nil
            reorderedEvents = []
        } catch {
            draggedMemberName = nil
            draggedMemberID = nil
            targetMemberName = nil
            reorderedEvents = []
            print("❌ Failed to save member order: \(error.localizedDescription)")
        }
        
        // Sync to AppSettings
        let orderedIDs = finalOrder.compactMap { group -> String? in
            if let member = familyMembers.first(where: { $0.objectID == group.id }) {
                return member.id?.uuidString
            }
            return nil
        }
        
        Task { @MainActor in
            appSettingsManager.familyMemberOrder = orderedIDs
            await appSettingsManager.saveSettings()
        }
    }

    private func objectID(from uriString: String) -> NSManagedObjectID? {
        guard let url = URL(string: uriString) else { return nil }
        return viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
    }

    private func resetDragState() {
        draggedMemberName = nil
        draggedMemberID = nil
        targetMemberName = nil
        reorderedEvents = []
        resetDragTimer?.invalidate()
        resetDragTimer = nil
    }

    // Fallback reset to avoid stale drag UI if the system fails to end the drag properly.
    private func scheduleDragResetFallback() {
        resetDragTimer?.invalidate()
        resetDragTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            resetDragState()
        }
    }

    private func applyOrderFromSettings(_ order: [String]) {
        guard !order.isEmpty else { return }
        
        var hasChanges = false
        
        for (index, idString) in order.enumerated() {
            if let member = familyMembers.first(where: { $0.id?.uuidString == idString }) {
                if member.sortOrder != Int16(index) {
                    member.sortOrder = Int16(index)
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            do {
                try viewContext.save()
                print("✅ Applied family member order from settings")
                loadNextEvents() // Reload to reflect new order
            } catch {
                print("❌ Failed to apply order from settings: \(error)")
            }
        }
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
    let calendarColor: UIColor
    let calendarTitle: String
    let calendarID: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
    let isAllDay: Bool
    let driverName: String?
    let isImportant: Bool
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
    let calendarColor: UIColor
    let calendarTitle: String
    let calendarID: String
    var memberColors: [UIColor] = []
    let hasRecurrence: Bool
    let isAllDay: Bool
    let driverName: String?
    let isImportant: Bool
}

private struct MemberEventGroup: Identifiable, Equatable {
    let id: NSManagedObjectID
    let memberName: String
    let sortOrder: Int16
    let memberColor: Color
    let nextEvent: GroupedEvent?
    let upcomingEvents: [GroupedEvent]

    static func == (lhs: MemberEventGroup, rhs: MemberEventGroup) -> Bool {
        lhs.memberName == rhs.memberName && lhs.id == rhs.id
    }
}

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    FamilyView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
