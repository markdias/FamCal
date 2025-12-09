//
//  CalendarView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit
import Combine
import MapKit
import UIKit

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var autoRefreshInterval: Int { appSettingsManager.autoRefreshInterval }
    private var defaultMapsApp: String { appSettingsManager.defaultMapsApp }

    var onAddEventRequested: ((Date) -> Void)? = nil
    @Binding var selectedDateBinding: Date

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
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

    @State private var currentMonth: Date = Date()
    @State private var dayEvents: [String: [DayEventItem]] = [:]
    @State private var isLoadingEvents = false
    @State private var selectedEvent: UpcomingCalendarEvent? = nil
    @State private var eventStore = EKEventStore()
    @State private var refreshTimer: Timer? = nil
    @State private var showingCalendarPicker = false
    @State private var contextMenuEvent: UpcomingCalendarEvent? = nil
    @State private var showingDeleteOptions = false
    @State private var showingLinkedDeleteDialog = false
    @State private var pendingDeleteEvent: UpcomingCalendarEvent? = nil
    @State private var pendingDeleteSpan: EKSpan = .thisEvent
    @State private var availableCalendars: [EKCalendar] = []
    @State private var memberColors: [NSManagedObjectID: UIColor] = [:]
    @Namespace private var animationNamespace
    @State private var calendarDisplayMode: CalendarDisplayMode
    @State private var selectedEventIdsForDeletion: Set<String> = []
    @State private var showingBatchDeleteDialog = false
    @State private var batchDeleteInProgress = false
    @State private var monthViewSelectionMode = false
    @State private var lastTapTimeMonth: Date = .distantPast
    @State private var lastTappedEventIdMonth: String = ""
    @State private var tapDelayTimerMonth: Timer?
    @State private var dataChangeDebounceTimer: Timer?
    private var externalDisplayMode: Binding<CalendarDisplayMode>?
    private var todayTrigger: Binding<UUID>?

    enum CalendarDisplayMode: String, CaseIterable {
        case month = "Month"
        case day = "Day"
    }

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday as first day
        return calendar
    }()
    private var theme: AppTheme { themeManager.selectedTheme }
    private var secondaryTextColor: Color { theme.mutedTagColor }
    private var selectedDate: Date {
        get { selectedDateBinding }
        nonmutating set { selectedDateBinding = newValue }
    }
    private var isCompactHeight: Bool { verticalSizeClass == .compact }
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let monthOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
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

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    init(startInDayMode: Bool = false, selectedDateBinding: Binding<Date>, displayMode: Binding<CalendarDisplayMode>? = nil, todayTrigger: Binding<UUID>? = nil, onAddEventRequested: ((Date) -> Void)? = nil) {
        _calendarDisplayMode = State(initialValue: displayMode?.wrappedValue ?? (startInDayMode ? .day : .month))
        self.externalDisplayMode = displayMode
        self.todayTrigger = todayTrigger
        self._selectedDateBinding = selectedDateBinding
        self.onAddEventRequested = onAddEventRequested
    }

    var body: some View {
        mainView
            .onAppear(perform: setupView)
            .onChange(of: currentMonth) { _, _ in loadEvents() }
            .onChange(of: selectedDate) { _, _ in
                if calendarDisplayMode == .day {
                    loadEvents()
                }
            }
            .onChange(of: familyMembers.count) { _, _ in triggerDebouncedReload() }
            .onChange(of: memberCalendarLinks.count) { _, _ in triggerDebouncedReload() }
            .onChange(of: personalCalendars.count) { _, _ in triggerDebouncedReload() }
            .onChange(of: autoRefreshInterval) { _, _ in startRefreshTimer() }
            .onChange(of: verticalSizeClass) { _, newValue in
                if newValue == .compact {
                    calendarDisplayMode = .day
                }
            }
            .onChange(of: todayTrigger?.wrappedValue) { _, _ in
                currentMonth = Date()
                selectedDate = Date()
            }
            .onDisappear(perform: cleanupView)
    }

    private var mainView: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                theme.backgroundLayer()
                    .ignoresSafeArea()

                if calendarDisplayMode == .month {
                    ScrollView {
                        content
                    }
                    .refreshable {
                        await reloadEvents()
                    }
                } else {
                    content
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            print("🔔 CalendarView: Received EKEventStoreChanged")
            loadEvents()
            loadAvailableCalendars()
        }
        .onChange(of: calendarDisplayMode) { _, newValue in
            externalDisplayMode?.wrappedValue = newValue
        }
        .onChange(of: externalDisplayMode?.wrappedValue ?? calendarDisplayMode) { _, newValue in
            calendarDisplayMode = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("📱 CalendarView: Received didBecomeActive")
            // Only restart timer on active; data reload is handled by EKEventStoreChanged (triggered by App resetStore)
            startRefreshTimer()
        }
        .onAppear {
            if isCompactHeight {
                calendarDisplayMode = .day
            }
        }
        .confirmationDialog(
            "Delete Event",
            isPresented: $showingLinkedDeleteDialog,
            titleVisibility: .visible
        ) {
            // Check if this is a recurring event in batch delete mode
            if let event = pendingDeleteEvent, event.hasRecurrence && batchDeleteInProgress {
                Button("Delete This Event", role: .destructive) {
                    if let event = pendingDeleteEvent {
                        showingLinkedDeleteDialog = false
                        // Delete this occurrence only
                        deleteEvent(event, span: .thisEvent, scope: .singleCalendar)
                        // Continue with remaining batch deletes
                        continueWithBatchDelete()
                    }
                }
                Button("Delete This & Future Events", role: .destructive) {
                    if let event = pendingDeleteEvent {
                        showingLinkedDeleteDialog = false
                        // Delete this and future occurrences
                        deleteEvent(event, span: .futureEvents, scope: .singleCalendar)
                        // Continue with remaining batch deletes
                        continueWithBatchDelete()
                    }
                }
            }
            // Check if event has linked copies (non-recurring or regular delete)
            else if let event = pendingDeleteEvent, linkedFamilyEvents(for: event.id).count > 1 {
                Button("Delete only this calendar", role: .destructive) {
                    if let event = pendingDeleteEvent {
                        showingLinkedDeleteDialog = false
                        deleteEvent(event, span: pendingDeleteSpan, scope: .singleCalendar)
                    }
                }
                Button("Delete in all linked calendars", role: .destructive) {
                    if let event = pendingDeleteEvent {
                        showingLinkedDeleteDialog = false
                        deleteEvent(event, span: pendingDeleteSpan, scope: .allLinked)
                    }
                }
            } else {
                // Single event - just delete
                Button("Delete", role: .destructive) {
                    if let event = pendingDeleteEvent {
                        showingLinkedDeleteDialog = false
                        deleteEvent(event, span: pendingDeleteSpan, scope: .singleCalendar)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteEvent = nil
                batchDeleteInProgress = false
            }
        } message: {
            if let event = pendingDeleteEvent, event.hasRecurrence && batchDeleteInProgress {
                return Text("'\(event.title)' is a recurring event. Delete this event only or this and all future events?")
            } else if let event = pendingDeleteEvent, linkedFamilyEvents(for: event.id).count > 1 {
                return Text("'\(event.title)' is linked to other calendars. Delete only here or everywhere?")
            } else if let event = pendingDeleteEvent {
                return Text("Are you sure you want to delete '\(event.title)'?")
            } else {
                return Text("Are you sure?")
            }
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
            Text("Delete \(count) selected event\(count == 1 ? "" : "s")? For recurring events, you'll be asked which occurrences to delete.")
        }
    }

    @ViewBuilder
    private var content: some View {
        let isDayMode = calendarDisplayMode == .day
        let fullScreenDay = isCompactHeight && isDayMode

        VStack(alignment: .leading, spacing: isDayMode ? 16 : 24) {
            if !fullScreenDay {
                // Header with centered month/year
                HStack {
                    // Calendar layout mode picker (left side)
                    if calendarDisplayMode == .month {
                        Menu {
                            Button(action: { appSettingsManager.calendarCellLayoutMode = "dots" }) {
                                Label("Dots Only", systemImage: appSettingsManager.calendarCellLayoutMode == "dots" ? "checkmark" : "")
                            }
                            Button(action: { appSettingsManager.calendarCellLayoutMode = "option1" }) {
                                Label("Pills with Bar", systemImage: appSettingsManager.calendarCellLayoutMode == "option1" ? "checkmark" : "")
                            }
                            Button(action: { appSettingsManager.calendarCellLayoutMode = "option2" }) {
                                Label("Colored Pills", systemImage: appSettingsManager.calendarCellLayoutMode == "option2" ? "checkmark" : "")
                            }
                        } label: {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.accentColor)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(theme.chromeOverlay))
                        }
                    } else {
                        Spacer().frame(width: 32)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(Self.monthOnlyFormatter.string(from: currentMonth))
                            .font(.system(size: 22, weight: .bold))
                        Text(Self.yearFormatter.string(from: currentMonth))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                    }

                    Spacer()

                    // Balance the layout with empty space on right
                    Spacer().frame(width: 32)
                }
                .padding(.vertical, 12)
            }

            // Calendar grid
            if calendarDisplayMode == .month {
                monthView
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            } else {
                dailyView
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            }

            // AdMob Banner - only show for free users in month view
            if calendarDisplayMode == .month && !appSettingsManager.isProUser {
                AdBannerContainer(
                    adUnitID: "ca-app-pub-3940256099942544/6300978111", // Test ad unit (for development)
                    isProUser: appSettingsManager.isProUser,
                    theme: theme
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 0)
        .padding(.top, fullScreenDay ? 0 : 16)
        .padding(.bottom, fullScreenDay ? 0 : 120)
        .frame(maxWidth: .infinity, maxHeight: isDayMode ? .infinity : nil, alignment: .top)
        .modifier(FullScreenDayModifier(enabled: fullScreenDay))
    }

    private var monthView: some View {
        VStack {
            VStack(spacing: 8) {
                // Day headers (Mon ... Sun)
                HStack(spacing: 0) {
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 4)

                // Calendar days
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(getDaysInMonth(), id: \.self) { date in
                        calendarDayCell(for: date)
                    }
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 50 {
                            previousMonth()
                        } else if value.translation.width < -50 {
                            nextMonth()
                        }
                    }
            )

            // Selected day details
            if let events = dayEvents[formatDateKey(selectedDate)], !events.isEmpty {
                dayDetailsView(for: events)
                    .padding(.horizontal, 16)
            } else {
                noEventsView
                    .padding(.horizontal, 16)
            }
        }
    }

    private var noEventsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.fullDateFormatter.string(from: selectedDate))
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 2)

            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 16))
                    .foregroundColor(secondaryTextColor)

                Text("No events scheduled")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
        }
    }

    private var dailyView: some View {
        let eventsForSelectedDate = dayEvents[formatDateKey(selectedDate)] ?? []
        return DailyEventsView(
            events: eventsForSelectedDate,
            selectedDate: selectedDate,
            selectedDateString: Self.fullDateFormatter.string(from: selectedDate),
            familyMembers: Array(familyMembers),
            memberColors: memberColors,
            selectedEventIds: $selectedEventIdsForDeletion,
            onDeleteSelected: { showingBatchDeleteDialog = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 50 {
                        previousDay()
                    } else if value.translation.width < -50 {
                        nextDay()
                    }
                }
        )
    }

    @ViewBuilder
    private func dayEventButton(for groupedEvent: GroupedDayEvent, isCompact: Bool) -> some View {
        let upcomingEvent = makeUpcomingEvent(from: groupedEvent)
        let isPast = Date() > groupedEvent.endDate
        let now = Date()
        let isInProgress = groupedEvent.startDate <= now && now < groupedEvent.endDate
        let isSelected = selectedEventIdsForDeletion.contains(groupedEvent.eventIdentifier)
        let isCompactMode = appSettingsManager.calendarEventsDensityMode == "compact"

        Button(action: {
            handleMonthViewEventTap(groupedEvent: groupedEvent, upcomingEvent: upcomingEvent)
        }) {
            let timeBoxWidth: CGFloat = isCompactMode ? 60 : 76
            let spacerWidth: CGFloat = 2
            let cardCornerRadius: CGFloat = isCompactMode ? 12 : 16
            let memberLabel = groupedEvent.memberNames.count > 1 ? "All" : (groupedEvent.memberNames.first ?? "")
            let timeLabel = groupedEvent.isAllDay ? "All day" : (groupedEvent.startTime ?? "")

            if isCompactMode {
                // Compact mode: simplified layout
                compactEventCard(
                    groupedEvent: groupedEvent,
                    timeLabel: timeLabel,
                    memberLabel: memberLabel,
                    isPast: isPast,
                    isSelected: isSelected,
                    isInProgress: isInProgress,
                    timeBoxWidth: timeBoxWidth,
                    spacerWidth: spacerWidth,
                    cardCornerRadius: cardCornerRadius
                )
            } else {
                // Detailed mode: original layout
                detailedEventCard(
                    groupedEvent: groupedEvent,
                    timeLabel: timeLabel,
                    memberLabel: memberLabel,
                    isPast: isPast,
                    isSelected: isSelected,
                    isInProgress: isInProgress,
                    timeBoxWidth: timeBoxWidth,
                    spacerWidth: spacerWidth,
                    cardCornerRadius: cardCornerRadius
                )
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            dayEventContextMenu(for: upcomingEvent)
        }
    }

    @ViewBuilder
    private func compactEventCard(
        groupedEvent: GroupedDayEvent,
        timeLabel: String,
        memberLabel: String,
        isPast: Bool,
        isSelected: Bool,
        isInProgress: Bool,
        timeBoxWidth: CGFloat,
        spacerWidth: CGFloat,
        cardCornerRadius: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(isInProgress ? Color.green.opacity(0.12) : theme.cardBackground)

            if !isSelected {
                memberColorBackground(for: groupedEvent)
                    .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))
                    .frame(width: timeBoxWidth)
                    .opacity(isPast ? 0.6 : 1.0)
            } else {
                Color(groupedEvent.color).opacity(0.2)
                    .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))
                    .frame(width: timeBoxWidth)
            }

            HStack(spacing: 0) {
                // Compact time block
                ZStack {
                    if !isSelected {
                        memberColorBackground(for: groupedEvent)
                    } else {
                        Color(groupedEvent.color).opacity(0.2)
                    }

                    Text(timeLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(isSelected ? .primary : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(width: timeBoxWidth, height: 36)
                .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))

                Color.white
                    .frame(width: spacerWidth)
                    .frame(height: 36)

                // Compact title only
                Text(groupedEvent.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .opacity(isPast ? 0.5 : 1.0)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .padding(.trailing, 12)
                }
            }
            .frame(height: 36)
        }
        .frame(height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(isInProgress ? Color.green : theme.cardStroke, lineWidth: isInProgress ? 2 : 1)
        )
    }

    @ViewBuilder
    private func detailedEventCard(
        groupedEvent: GroupedDayEvent,
        timeLabel: String,
        memberLabel: String,
        isPast: Bool,
        isSelected: Bool,
        isInProgress: Bool,
        timeBoxWidth: CGFloat,
        spacerWidth: CGFloat,
        cardCornerRadius: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(isInProgress ? Color.green.opacity(0.12) : theme.cardBackground)

                // Only show left color bar when not selected
                if !isSelected {
                    memberColorBackground(for: groupedEvent)
                        .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))
                        .frame(width: timeBoxWidth)
                        .opacity(isPast ? 0.6 : 1.0)
                } else {
                    // When selected, show a subtle highlight instead
                    Color(groupedEvent.color).opacity(0.2)
                        .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))
                        .frame(width: timeBoxWidth)
                }

                HStack(spacing: 0) {
                    // Time block
                    ZStack {
                        // Only show color when not selected
                        if !isSelected {
                            memberColorBackground(for: groupedEvent)
                        } else {
                            Color(groupedEvent.color).opacity(0.2)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(timeLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(isSelected ? .primary : .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .allowsTightening(true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Spacer(minLength: 0)

                            if !memberLabel.isEmpty {
                                Text(memberLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isSelected ? .secondary : .white.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .allowsTightening(true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                    }
                    .frame(width: timeBoxWidth)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedCorner(radius: cardCornerRadius, corners: [.topLeft, .bottomLeft]))

                    // Thin white spacer
                    Color.white
                        .frame(width: spacerWidth)
                        .frame(maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        // Title
                        Text(groupedEvent.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .opacity(isPast ? 0.5 : 1.0)

                        // Family members (if more than 1)
                        if groupedEvent.memberNames.count > 1 {
                            Text(groupedEvent.memberNames.joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(2)
                                .opacity(isPast ? 0.5 : 1.0)
                        }

                        // Time
                        let timeText = groupedEvent.isAllDay ? "all day" : (groupedEvent.timeRange ?? "-")
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(secondaryTextColor)
                            Text(timeText)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(secondaryTextColor)
                        }
                        .opacity(isPast ? 0.5 : 1.0)

                        // Location (first line only) - tappable to open maps
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
                                }
                            }
                            .opacity(isPast ? 0.5 : 1.0)
                        }

                        if let meetingLink = groupedEvent.meetingLink,
                           let destination = MeetingLinkHelper.normalizedURL(from: meetingLink) {
                            Link(destination: destination) {
                                HStack(spacing: 6) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(secondaryTextColor)
                                    Text(MeetingLinkHelper.displayLabel(for: meetingLink))
                                        .font(.system(size: 11.5))
                                        .foregroundColor(secondaryTextColor)
                                        .lineLimit(1)
                                }
                            }
                            .opacity(isPast ? 0.5 : 1.0)
                        }

                        // Driver (if available)
                        if let driverName = groupedEvent.driverName {
                            let driverPhone = fetchDriverPhoneForEvent(groupedEvent.eventIdentifier)
                            Group {
                                if let phone = driverPhone, !phone.isEmpty {
                                    Link(destination: URL(string: "tel:\(phone)")!) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "car.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(secondaryTextColor)
                                            Text(driverName)
                                                .font(.system(size: 13))
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
                                            .font(.system(size: 13))
                                            .foregroundColor(secondaryTextColor)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .opacity(isPast ? 0.5 : 1.0)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
            .overlay(
                // Selection indicator
                isSelected ? AnyView(
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Circle().fill(Color(groupedEvent.color)))
                        }
                        Spacer()
                    }
                ) : AnyView(EmptyView())
            )
        }

    @ViewBuilder
    private func memberColorBackground(for groupedEvent: GroupedDayEvent) -> some View {
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

    private func makeUpcomingEvent(from groupedEvent: GroupedDayEvent) -> UpcomingCalendarEvent {
        UpcomingCalendarEvent(
            id: groupedEvent.eventIdentifier,
            title: groupedEvent.title,
            location: groupedEvent.location,
            meetingLink: groupedEvent.meetingLink,
            startDate: groupedEvent.startDate,
            endDate: groupedEvent.endDate,
            calendarID: groupedEvent.calendarID,
            calendarColor: groupedEvent.calendarColor,
            calendarTitle: groupedEvent.calendarTitle,
            hasRecurrence: groupedEvent.hasRecurrence,
            recurrenceRule: nil,
            isAllDay: groupedEvent.isAllDay
        )
    }

    @ViewBuilder
    private func dayEventContextMenu(for event: UpcomingCalendarEvent) -> some View {
        Button(action: { duplicateEvent(event) }) {
            Label("Duplicate", systemImage: "doc.on.doc")
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
        if event.hasRecurrence {
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

    @ViewBuilder
    private func dayDetailsView(for events: [DayEventItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Self.fullDateFormatter.string(from: selectedDate))
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 2)

                Spacer()

                // Density toggle button
                if selectedEventIdsForDeletion.isEmpty {
                    Button(action: {
                        appSettingsManager.calendarEventsDensityMode =
                            appSettingsManager.calendarEventsDensityMode == "detailed" ? "compact" : "detailed"
                    }) {
                        Image(systemName: appSettingsManager.calendarEventsDensityMode == "detailed" ? "list.bullet" : "list.bullet.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.accentColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(theme.chromeOverlay)
                            )
                    }
                }

                // Show selection count and delete button in month view
                if !selectedEventIdsForDeletion.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(selectedEventIdsForDeletion.count) selected")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Button(action: {
                            showingBatchDeleteDialog = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Delete")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(6)
                        }
                    }
                }
            }

            // Group events by title, time, and location
            let groupedEvents = groupEventsByDetails(events)
            let allDayEvents = groupedEvents.filter { $0.isAllDay }
            let timedEvents = groupedEvents.filter { !$0.isAllDay }

            VStack(spacing: 4) {
                ForEach(allDayEvents) { groupedEvent in
                    dayEventButton(for: groupedEvent, isCompact: true)
                }
                ForEach(timedEvents) { groupedEvent in
                    dayEventButton(for: groupedEvent, isCompact: false)
                }
            }
        }
    }

    private func groupEventsByDetails(_ events: [DayEventItem]) -> [GroupedDayEvent] {
        var grouped: [String: GroupedDayEvent] = [:]

        for event in events {
            let key = "\(event.title)|\(event.timeRange ?? "all-day")|\(event.location ?? "")|\(event.meetingLink ?? "")"

            if var existing = grouped[key] {
                existing.memberNames.append(contentsOf: event.memberNames)
                // Add color if it's not already in the list
                if !existing.memberColors.contains(where: { $0.cgColor == event.memberColor.cgColor }) {
                    existing.memberColors.append(event.memberColor)
                }
                grouped[key] = existing
            } else {
                grouped[key] = GroupedDayEvent(
                    id: UUID(),
                    title: event.title,
                    timeRange: event.timeRange,
                    location: event.location,
                    meetingLink: event.meetingLink,
                    memberNames: event.memberNames,
                    memberInitials: event.memberInitials,
                    memberColor: event.memberColor,
                    color: event.color,
                    memberColors: [event.memberColor],
                    eventIdentifier: event.eventIdentifier,
                    calendarID: event.calendarID,
                    calendarColor: event.calendarColor,
                    calendarTitle: event.calendarTitle,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    hasRecurrence: event.hasRecurrence,
                    isAllDay: event.isAllDay,
                    driverName: event.driverName
                )
            }
        }

        return grouped.values.sorted { e1, e2 in
            e1.timeRange ?? "" < e2.timeRange ?? ""
        }
    }

    // MARK: - Helper Functions
    
    private func getSavedAddress(for location: String) -> SavedAddress? {
        // Try to find a saved address that matches this location
        return savedAddresses.first { savedAddr in
            guard let address = savedAddr.address else { return false }
            // Match if the event location contains the saved address or vice versa
            return location.lowercased().contains(address.lowercased()) ||
                   address.lowercased().contains(location.lowercased())
        }
    }

    private func calendarDayCell(for date: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let events = dayEvents[formatDateKey(date)] ?? []
        let eventCount = events.count
        let now = Date()

        // Filter to show only all-day events or events that haven't happened yet
        let relevantEvents = events.filter { event in
            event.isAllDay || event.startDate > now
        }

        let layoutMode = appSettingsManager.calendarCellLayoutMode

        return Group {
            if layoutMode == "dots" {
                // Original dots-only layout
                dotsOnlyCell(date: date, isCurrentMonth: isCurrentMonth, isToday: isToday, isSelected: isSelected, events: events, eventCount: eventCount)
            } else {
                // New layouts with event titles
                eventsWithTitlesCell(date: date, isCurrentMonth: isCurrentMonth, isToday: isToday, isSelected: isSelected, events: relevantEvents, layoutMode: layoutMode)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCurrentMonth {
                withAnimation(.spring()) {
                    selectedDate = date
                }
            }
        }
        .opacity(isCurrentMonth ? 1 : 0.5)
    }

    @ViewBuilder
    private func dotsOnlyCell(date: Date, isCurrentMonth: Bool, isToday: Bool, isSelected: Bool, events: [DayEventItem], eventCount: Int) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(Self.dayFormatter.string(from: date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(
                    isSelected ? .white
                    : !isCurrentMonth ? secondaryTextColor.opacity(0.5)
                    : isToday ? theme.accentColor
                    : .primary
                )
                .frame(width: 24, height: 24)
                .background(
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(theme.accentFillStyle())
                                .matchedGeometryEffect(id: "selectedDate", in: animationNamespace)
                        }
                        if isToday && !isSelected {
                            Circle()
                                .stroke(theme.accentColor, lineWidth: 2)
                        }
                    }
                )

            // Event indicators (dots)
            if !events.isEmpty {
                HStack(spacing: 2) {
                    ForEach(0..<min(3, eventCount), id: \.self) { index in
                        let event = events[index]
                        let isPastEvent = Date() > event.endDate
                        Circle()
                            .fill(Color(uiColor: event.color))
                            .frame(width: 5, height: 5)
                            .opacity(isPastEvent ? 0.6 : 1.0)
                    }
                }
            } else {
                Spacer().frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isToday && !isSelected ? theme.accentColor.opacity(0.1) : Color.clear
                )
        )
    }

    @ViewBuilder
    private func eventsWithTitlesCell(date: Date, isCurrentMonth: Bool, isToday: Bool, isSelected: Bool, events: [DayEventItem], layoutMode: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number with selection indicator
            HStack {
                Spacer()
                Text(Self.dayFormatter.string(from: date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(
                        isSelected ? .white
                        : !isCurrentMonth ? secondaryTextColor.opacity(0.5)
                        : isToday ? theme.accentColor
                        : .primary
                    )
                    .frame(width: 24, height: 24)
                    .background(
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(theme.accentFillStyle())
                                    .matchedGeometryEffect(id: "selectedDate", in: animationNamespace)
                            }
                            if isToday && !isSelected {
                                Circle()
                                    .stroke(theme.accentColor, lineWidth: 2)
                            }
                        }
                    )
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            // Events based on layout mode
            if layoutMode == "option1" {
                option1EventList(events: events)
            } else if layoutMode == "option2" {
                option2EventList(events: events)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isToday && !isSelected ? theme.accentColor.opacity(0.1) : Color.clear
                )
        )
    }

    @ViewBuilder
    private func option1EventList(events: [DayEventItem]) -> some View {
        let maxEvents = 2
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(events.prefix(maxEvents).enumerated()), id: \.offset) { _, event in
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(uiColor: event.color))
                        .frame(width: 2)
                    Text(event.title)
                        .font(.system(size: 8))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    Spacer(minLength: 0)
                }
                .frame(height: 10)
                .padding(.horizontal, 1)
                .background(Color(uiColor: event.color).opacity(0.12))
                .cornerRadius(2)
            }
            if events.count > maxEvents {
                Text("+\(events.count - maxEvents)")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func option2EventList(events: [DayEventItem]) -> some View {
        let maxEvents = 2
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(events.prefix(maxEvents).enumerated()), id: \.offset) { _, event in
                Text(event.title)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(Color(uiColor: event.color))
                    .cornerRadius(2)
            }
            if events.count > maxEvents {
                Text("+\(events.count - maxEvents)")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 2)
    }

    private func getDaysInMonth() -> [Date] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let numDays = range.count

        // Get the first day of the month
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: currentMonth)
        components.day = 1
        let firstOfMonth = calendar.date(from: components)!

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let firstWeekday = (weekday + 5) % 7 // shift so Monday = 0

        var days: [Date] = []

        // Add empty dates from previous month
        if firstWeekday > 0 {
            for i in 0..<firstWeekday {
                let date = calendar.date(byAdding: .day, value: -(firstWeekday - i), to: firstOfMonth)!
                days.append(date)
            }
        }

        // Add days of current month
        for day in 1...numDays {
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            days.append(date)
        }

        // Add empty dates from next month
        let remainingDays = 42 - days.count // 6 rows x 7 days
        let lastDayOfMonth = calendar.date(byAdding: .day, value: numDays - 1, to: firstOfMonth)!
        for day in 1...remainingDays {
            let date = calendar.date(byAdding: .day, value: day, to: lastDayOfMonth)!
            days.append(date)
        }

        return days
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func previousMonth() {
        withAnimation {
            if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                currentMonth = newMonth
                updateSelectedDateForMonth(newMonth)
            }
        }
    }

    private func nextMonth() {
        withAnimation {
            if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                currentMonth = newMonth
                updateSelectedDateForMonth(newMonth)
            }
        }
    }

    private func previousDay() {
        withAnimation {
            if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }

    private func nextDay() {
        withAnimation {
            if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }

    private func updateSelectedDateForMonth(_ month: Date) {
        let today = Date()
        if calendar.isDate(month, equalTo: today, toGranularity: .month) {
            // Current month: select today
            selectedDate = today
        } else {
            // Other months: select the 1st
            var components = calendar.dateComponents([.year, .month], from: month)
            components.day = 1
            if let firstOfMonth = calendar.date(from: components) {
                selectedDate = firstOfMonth
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
        if let familyEvent = familyEvents.first(where: { $0.eventIdentifier == eventIdentifier }) {
            return familyEvent.driver?.phone
        }
        return nil
    }

    private func loadEvents() {
        print("📅 CalendarView: loadEvents() started")
        isLoadingEvents = true

        var tempEventsDict: [String: [DayEventItem]] = [:]
        var memberColors: [NSManagedObjectID: UIColor] = [:]

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .month, value: 1, to: startOfMonth)!)!

        // Fetch all local calendars for resolution
        let localCalendars = eventStore.calendars(for: .event)
        let calendarById = Dictionary(uniqueKeysWithValues: localCalendars.map { ($0.calendarIdentifier, $0) })
        let calendarByTitle = Dictionary(grouping: localCalendars, by: { $0.title }).mapValues { $0.first! }

        // Build map of member → their calendar IDs
        var memberCalendarMap: [NSManagedObjectID: (Set<String>, FamilyMember)] = [:]

        for link in memberCalendarLinks {
            guard let member = link.familyMember,
                  let storedID = link.calendarID else { continue }
            
            var resolvedID = storedID
            // If ID not found locally, try to find by name
            if calendarById[storedID] == nil, let name = link.calendarName, let localCal = calendarByTitle[name] {
                print("⚠️ Calendar ID mismatch for '\(name)'. Resolved by name: \(storedID) -> \(localCal.calendarIdentifier)")
                resolvedID = localCal.calendarIdentifier
            }

            var entry = memberCalendarMap[member.objectID] ?? ([], member)
            entry.0.insert(resolvedID)
            memberCalendarMap[member.objectID] = entry
            
            if memberColors[member.objectID] == nil, let calendar = calendarById[resolvedID] {
                memberColors[member.objectID] = UIColor(cgColor: calendar.cgColor)
            }
        }

        // Add shared calendars
        for member in familyMembers {
            var entry = memberCalendarMap[member.objectID] ?? ([], member)
            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for sharedCal in sharedCals {
                    if let storedID = sharedCal.calendarID {
                        var resolvedID = storedID
                        // If ID not found locally, try to find by name
                        if calendarById[storedID] == nil, let name = sharedCal.calendarName, let localCal = calendarByTitle[name] {
                            print("⚠️ Shared Calendar ID mismatch for '\(name)'. Resolved by name: \(storedID) -> \(localCal.calendarIdentifier)")
                            resolvedID = localCal.calendarIdentifier
                        }
                        entry.0.insert(resolvedID)
                    }
                }
            }
            if !entry.0.isEmpty {
                memberCalendarMap[member.objectID] = entry
            }
        }

        // Add personal calendars for the current user
        if let linkedMemberId = appSettingsManager.linkedFamilyMemberId,
           let linkedMember = familyMembers.first(where: { $0.id?.uuidString.lowercased() == linkedMemberId.lowercased() }) {
            var entry = memberCalendarMap[linkedMember.objectID] ?? ([], linkedMember)
            for personalCal in personalCalendars {
                // Check if calendar view is enabled (either month OR day)
                let calendarViewEnabled = personalCal.showInMonth || personalCal.showInDay
                guard calendarViewEnabled else { continue }

                var resolvedID: String?
                if let storedID = personalCal.calendarID {
                    resolvedID = storedID
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
                    entry.0.insert(resolvedID)
                }
            }
            if !entry.0.isEmpty {
                memberCalendarMap[linkedMember.objectID] = entry
            }
        }
        
        for member in familyMembers {
            if memberColors[member.objectID] == nil {
                if let firstCalID = memberCalendarMap[member.objectID]?.0.first,
                   let calendar = eventStore.calendar(withIdentifier: firstCalID) {
                    memberColors[member.objectID] = UIColor(cgColor: calendar.cgColor)
                } else {
                    memberColors[member.objectID] = .gray
                }
            }
        }
        self.memberColors = memberColors

        // Fetch events for each member
        for (_, (calendarIDs, member)) in memberCalendarMap {
            let events = CalendarManager.shared.fetchNextEvents(
                for: Array(calendarIDs),
                limit: 0,
                pastDays: appSettingsManager.eventsPastDays,
                futureDays: appSettingsManager.eventsFutureDays
            )

            let initials = member.avatarInitials ?? initials(for: member.name)

            for event in events {
                let eventDate = calendar.startOfDay(for: event.startDate)
                let monthDate = calendar.startOfDay(for: endOfMonth)

                if eventDate >= startOfMonth && eventDate <= monthDate {
                    let dateKey = formatDateKey(eventDate)

                    let timeRange = event.startDate == event.endDate ? nil : {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
                    }()

                    let driverName = fetchDriverForEvent(event.id)
                    let driverPhone = fetchDriverPhoneForEvent(event.id)
                    let dayEvent = DayEventItem(
                        id: UUID(),
                        title: event.title,
                        timeRange: timeRange,
                        location: event.location,
                        meetingLink: event.meetingLink,
                        memberNames: [member.name ?? "Unknown"],
                        memberIDs: [member.objectID],
                        memberInitials: initials,
                        memberColor: event.calendarColor,
                        color: event.calendarColor,
                        eventIdentifier: event.id,
                        calendarID: event.calendarID,
                        calendarColor: event.calendarColor,
                        calendarTitle: event.calendarTitle,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        hasRecurrence: event.hasRecurrence,
                        isAllDay: event.isAllDay,
                        driverName: driverName,
                        driverPhone: driverPhone
                    )

                    if tempEventsDict[dateKey] == nil {
                        tempEventsDict[dateKey] = []
                    }
                    tempEventsDict[dateKey]?.append(dayEvent)
                }
            }
        }

        // De-duplicate events
        var finalEventsDict: [String: [DayEventItem]] = [:]
        for (dateKey, dayEventItems) in tempEventsDict {
            var uniqueEvents: [String: DayEventItem] = [:]
            for event in dayEventItems {
                if var existingEvent = uniqueEvents[event.eventIdentifier] {
                    existingEvent.memberNames.append(contentsOf: event.memberNames)
                    existingEvent.memberIDs.append(contentsOf: event.memberIDs)
                    uniqueEvents[event.eventIdentifier] = existingEvent
                } else {
                    uniqueEvents[event.eventIdentifier] = event
                }
            }
            finalEventsDict[dateKey] = Array(uniqueEvents.values)
        }

        dayEvents = finalEventsDict
        isLoadingEvents = false
    }

    private func initials(for name: String?) -> String {
        guard let name = name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (first + second)
        if combined.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return combined.uppercased()
    }

    // MARK: - View Lifecycle

    private func reloadEvents() async {
        // Force refresh data when user manually pulls down (bypass change detection)
        await dataManager.fetchUserDataIfNeeded(force: true)
        loadEvents()
    }

    private func setupView() {
        loadEvents()
        loadAvailableCalendars()
        startRefreshTimer()

        // Set up notification observer for personal calendar visibility changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("PersonalCalendarVisibilityChanged"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔔 Personal calendar visibility changed, reloading calendar events...")
            // Small delay to ensure CoreData has propagated the change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadEvents()
            }
        }
    }

    private func loadAvailableCalendars() {
        let calendars = eventStore.calendars(for: .event)
        self.availableCalendars = calendars
    }

    private func cleanupView() {
        stopRefreshTimer()
        dataChangeDebounceTimer?.invalidate()
    }

    private func triggerDebouncedReload() {
        // Debounce data changes to prevent cascading reloads
        dataChangeDebounceTimer?.invalidate()
        dataChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            loadEvents()
        }
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

    private func moveEventToCalendar(_ event: UpcomingCalendarEvent, calendarID: String) {
        // Skip if moving to the same calendar
        if calendarID == event.calendarID {
            return
        }

        // Get the EKEvent and calendar
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

    private func handleMonthViewEventTap(groupedEvent: GroupedDayEvent, upcomingEvent: UpcomingCalendarEvent) {
        // Cancel any pending single tap timer
        tapDelayTimerMonth?.invalidate()

        // Check if this is a double tap
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTimeMonth)

        if lastTappedEventIdMonth == groupedEvent.eventIdentifier && timeSinceLastTap < 0.3 {
            // Double tap detected - toggle selection
            if selectedEventIdsForDeletion.contains(groupedEvent.eventIdentifier) {
                selectedEventIdsForDeletion.remove(groupedEvent.eventIdentifier)
            } else {
                selectedEventIdsForDeletion.insert(groupedEvent.eventIdentifier)
            }
            lastTapTimeMonth = .distantPast
            tapDelayTimerMonth?.invalidate()
            tapDelayTimerMonth = nil
        } else {
            // Possible start of double tap or single tap
            lastTapTimeMonth = now
            lastTappedEventIdMonth = groupedEvent.eventIdentifier

            // Delay action to see if another tap comes
            tapDelayTimerMonth = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                // Single tap - show event details
                selectedEvent = upcomingEvent
                tapDelayTimerMonth = nil
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

                await NotificationManager.shared.cancelEventNotifications(for: target.id)

                let fetchRequest = FamilyEvent.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", target.id)
                if let familyEvent = try? viewContext.fetch(fetchRequest).first {
                    viewContext.delete(familyEvent)
                }
            } else {
                print("⚠️ Failed to delete event \(target.id) in calendar \(target.calendarID)")
            }
        }

        if anyDeleted {
            try? viewContext.save()
            print("✅ Deleted \(targets.count) linked event(s)")
            await MainActor.run {
                loadEvents()
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

    private func batchDeleteSelectedEvents() {
        batchDeleteInProgress = true
        let eventsForSelectedDate = dayEvents[formatDateKey(selectedDate)] ?? []

        // First, check if any selected events are recurring
        let selectedEvents = eventsForSelectedDate.filter { selectedEventIdsForDeletion.contains($0.eventIdentifier) }
        let recurringEvents = selectedEvents.filter { $0.hasRecurrence }

        if !recurringEvents.isEmpty {
            // If there are recurring events, we need to ask for scope for each one
            // Start with the first recurring event
            if let firstRecurring = recurringEvents.first {
                let upcomingEvent = UpcomingCalendarEvent(
                    id: firstRecurring.eventIdentifier,
                    title: firstRecurring.title,
                    location: firstRecurring.location,
                    meetingLink: firstRecurring.meetingLink,
                    startDate: firstRecurring.startDate,
                    endDate: firstRecurring.endDate,
                    calendarID: firstRecurring.calendarID,
                    calendarColor: firstRecurring.calendarColor,
                    calendarTitle: firstRecurring.calendarTitle,
                    hasRecurrence: firstRecurring.hasRecurrence,
                    recurrenceRule: nil,
                    isAllDay: firstRecurring.isAllDay
                )
                pendingDeleteEvent = upcomingEvent
                pendingDeleteSpan = .thisEvent
                showingLinkedDeleteDialog = true
                return
            }
        }

        // If no recurring events, proceed with batch delete
        Task {
            await performBatchDelete(events: selectedEvents)
        }
    }

    private func continueWithBatchDelete() {
        let eventsForSelectedDate = dayEvents[formatDateKey(selectedDate)] ?? []
        let selectedEvents = eventsForSelectedDate.filter { selectedEventIdsForDeletion.contains($0.eventIdentifier) }

        // Remove the just-deleted event from selection
        if let pendingEvent = pendingDeleteEvent {
            selectedEventIdsForDeletion.remove(pendingEvent.id)
        }

        // Check if there are more recurring events
        let recurringEvents = selectedEvents.filter { $0.hasRecurrence && selectedEventIdsForDeletion.contains($0.eventIdentifier) }

        if !recurringEvents.isEmpty {
            // Ask for scope of the next recurring event
            if let nextRecurring = recurringEvents.first {
                let upcomingEvent = UpcomingCalendarEvent(
                    id: nextRecurring.eventIdentifier,
                    title: nextRecurring.title,
                    location: nextRecurring.location,
                    meetingLink: nextRecurring.meetingLink,
                    startDate: nextRecurring.startDate,
                    endDate: nextRecurring.endDate,
                    calendarID: nextRecurring.calendarID,
                    calendarColor: nextRecurring.calendarColor,
                    calendarTitle: nextRecurring.calendarTitle,
                    hasRecurrence: nextRecurring.hasRecurrence,
                    recurrenceRule: nil,
                    isAllDay: nextRecurring.isAllDay
                )
                pendingDeleteEvent = upcomingEvent
                pendingDeleteSpan = .thisEvent
                showingLinkedDeleteDialog = true
            }
        } else {
            // No more recurring events, proceed with batch delete
            Task {
                let remainingEvents = selectedEvents.filter { selectedEventIdsForDeletion.contains($0.eventIdentifier) }
                await performBatchDelete(events: remainingEvents)
            }
        }
    }

    private func performBatchDelete(events: [DayEventItem]) async {
        var deletedCount = 0

        for event in events {
            let upcomingEvent = UpcomingCalendarEvent(
                id: event.eventIdentifier,
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

            let span: EKSpan = .thisEvent

            let success = CalendarManager.shared.deleteEvent(
                withIdentifier: upcomingEvent.id,
                occurrenceStartDate: upcomingEvent.startDate,
                from: upcomingEvent.calendarID,
                span: span
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

        if deletedCount > 0 {
            try? viewContext.save()
            print("✅ Batch deleted \(deletedCount) event(s)")
            await MainActor.run {
                selectedEventIdsForDeletion.removeAll()
                loadEvents()
                batchDeleteInProgress = false
            }
        } else {
            await MainActor.run {
                batchDeleteInProgress = false
            }
        }
    }
}

private struct FullScreenDayModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .ignoresSafeArea(.all)
        } else {
            content
        }
    }
}

// MARK: - Data Models

struct DayEventItem: Identifiable {
    let id: UUID
    let title: String
    let timeRange: String?
    let location: String?
    let meetingLink: String?
    var memberNames: [String]
    var memberIDs: [NSManagedObjectID]
    let memberInitials: String
    let memberColor: UIColor
    let color: UIColor
    let eventIdentifier: String
    let calendarID: String
    let calendarColor: UIColor
    let calendarTitle: String
    let startDate: Date
    let endDate: Date
    let hasRecurrence: Bool
    let isAllDay: Bool
    let driverName: String?
    let driverPhone: String?

    var startTime: String? {
        guard let timeRange = timeRange else { return nil }
        return timeRange.split(separator: "–").first?.trimmingCharacters(in: .whitespaces)
    }
}

struct GroupedDayEvent: Identifiable {
    let id: UUID
    let title: String
    let timeRange: String?
    let location: String?
    let meetingLink: String?
    var memberNames: [String]
    let memberInitials: String
    let memberColor: UIColor
    let color: UIColor
    var memberColors: [UIColor] = []  // Store all colors for gradient
    let eventIdentifier: String
    let calendarID: String
    let calendarColor: UIColor
    let calendarTitle: String
    let startDate: Date
    let endDate: Date
    let hasRecurrence: Bool
    let isAllDay: Bool
    let driverName: String?

    var startTime: String? {
        guard let timeRange = timeRange else { return nil }
        return timeRange.split(separator: "–").first?.trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    CalendarView(selectedDateBinding: $selectedDate)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
