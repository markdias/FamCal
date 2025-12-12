//
//  MainTabView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit

struct MainTabView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ScaledMetric(relativeTo: .headline) private var todayButtonBaseFontSize: CGFloat = 12

    private enum ActiveView: String {
        case events
        case calendar

        var title: String {
            switch self {
            case .events:
                return "Events"
            case .calendar:
                return "Calendar"
            }
        }
    }

    @State private var activeView: ActiveView = .events
    @State private var startCalendarInDayMode: Bool = false
    @State private var showingSettings = false
    @State private var showingAddEvent = false
    @State private var showingSearch = false
    @State private var showingChecklists = false
    @State private var addEventInitialDate: Date? = nil
    @State private var calendarSelectedDate: Date = Date()
    @State private var calendarDisplayMode: CalendarView.CalendarDisplayMode = .month
    @State private var calendarTodayTrigger = UUID()
    @State private var showingEventDetail = false
    @State private var eventToShow: UpcomingCalendarEvent?
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: AppTheme {
        themeManager.selectedTheme
    }

    private var isUltraCompactWidth: Bool { UIScreen.main.bounds.width < 330 }

    private var todayButtonFont: Font {
        .system(size: todayButtonFontSize, weight: .semibold)
    }

    private var todayButtonFontSize: CGFloat {
        let width = UIScreen.main.bounds.width
        switch width {
        case ..<330:
            return todayButtonBaseFontSize * 0.72
        case ..<360:
            return todayButtonBaseFontSize * 0.82
        case ..<400:
            return todayButtonBaseFontSize * 0.9
        default:
            return todayButtonBaseFontSize
        }
    }

    private var todayButtonHorizontalPadding: CGFloat {
        let width = UIScreen.main.bounds.width
        if width < 330 { return 7 }
        if width < 360 { return 9 }
        if width < 400 { return 10 }
        return 12
    }

    private var todayButtonScaleFactor: CGFloat {
        UIScreen.main.bounds.width < 360 ? 0.5 : 0.75
    }

    private var todayButtonLabel: String {
        isUltraCompactWidth ? "Now" : "Today"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch activeView {
                case .events:
                    FamilyView(
                        onSearchRequested: { showingSearch = true },
                        onAddEventRequested: { showingAddEvent = true },
                        onChangeViewRequested: { switchToView(.calendar) }
                    )
                case .calendar:
                    CalendarView(startInDayMode: startCalendarInDayMode, selectedDateBinding: $calendarSelectedDate, displayMode: $calendarDisplayMode, todayTrigger: $calendarTodayTrigger, onAddEventRequested: { date in
                        addEventInitialDate = date
                        showingAddEvent = true
                    })
                        .id(startCalendarInDayMode ? "calendar-day" : "calendar-month")
                }
            }

            // Floating action buttons
            if activeView == .calendar && verticalSizeClass != .compact {
                VStack {
                    Spacer()
                    HStack(alignment: .center) {
                        leftControlCluster

                        if activeView == .calendar {
                            Spacer().frame(width: 16)
                            middleControlCluster
                        }

                        Spacer()

                        primaryActionButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
        .sheet(isPresented: $showingChecklists) {
            ChecklistsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(initialDate: addEventInitialDate)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = eventToShow {
                EventDetailView(event: event)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("openEventDetail"))) { notification in
            handleOpenEventDetail(notification)
        }
        .onChange(of: appSettingsManager.defaultHomeScreenRawValue) { _, newValue in
            let screen = DefaultHomeScreen(rawValue: newValue) ?? .family
            startCalendarInDayMode = screen == .calendarDay
            let targetView = MainTabView.activeView(for: screen)
            if activeView != targetView {
                activeView = targetView
            }
            if targetView == .calendar {
                calendarDisplayMode = startCalendarInDayMode ? .day : .month
            }
        }
    }

    private var leftControlCluster: some View {
        HStack(spacing: 12) {
            SettingsControlButton(imageName: "gearshape.fill", action: {
                showingSettings = true
            }, theme: theme)
            .accessibilityLabel("Open settings")

            SettingsControlButton(imageName: "magnifyingglass", action: {
                showingSearch = true
            }, theme: theme)
            .accessibilityLabel("Search events")

            SettingsControlButton(imageName: "checkmark.circle.fill", action: {
                showingChecklists = true
            }, theme: theme)
            .accessibilityLabel("View all checklists")
            .accessibilityHint("Open the checklists view to see all items")

            SettingsControlButton(imageName: activeView == .events ? "calendar" : "list.bullet.rectangle", action: {
                toggleActiveView()
            }, theme: theme)
            .accessibilityLabel(activeView == .events ? "Open calendar view" : "Return to event list")
            .accessibilityHint(activeView == .events ? "Switch to calendar grid" : "Switch to events list")
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

    private var middleControlCluster: some View {
        HStack(spacing: 12) {
            SettingsControlButton(imageName: calendarDisplayMode == .month ? "calendar.day.timeline.left" : "calendar", action: {
                toggleCalendarDisplayMode()
            }, theme: theme)
            .accessibilityLabel("Toggle month or day view")

            Button(action: {
                calendarTodayTrigger = UUID()
            }) {
                Text(todayButtonLabel)
                    .font(todayButtonFont)
                    .lineLimit(1)
                    .minimumScaleFactor(todayButtonScaleFactor)
                    .allowsTightening(true)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(.white)
                    .padding(.horizontal, todayButtonHorizontalPadding)
                    .padding(.vertical, isUltraCompactWidth ? 7 : 8)
                    .background(
                        Capsule()
                            .fill(theme.accentFillStyle())
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to today")
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

    private var primaryActionButton: some View {
        Button(action: {
            if activeView == .calendar {
                // For calendar view, use the selected date from the calendar
                addEventInitialDate = calendarSelectedDate
                showingAddEvent = true
            } else {
                // For family view, use today's date
                addEventInitialDate = Date()
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

    private struct SettingsControlButton: View {
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

    private func switchToView(_ target: ActiveView) {
        guard activeView != target else { return }
        withAnimation(.spring()) {
            activeView = target
        }
    }

    private static func activeView(for screen: DefaultHomeScreen) -> ActiveView {
        switch screen {
        case .family:
            return .events
        case .calendarMonth, .calendarDay:
            return .calendar
        }
    }

    private func toggleActiveView() {
        let next: ActiveView = {
            switch activeView {
            case .events:
                return .calendar
            case .calendar:
                return .events
            }
        }()
        switchToView(next)
    }

    private func toggleCalendarDisplayMode() {
        withAnimation(.easeInOut) {
            calendarDisplayMode = calendarDisplayMode == .month ? .day : .month
        }
    }

    private func handleOpenEventDetail(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let eventIdentifier = userInfo["eventIdentifier"] as? String else {
            print("⚠️ Could not extract event identifier from notification")
            return
        }

        print("📅 Opening event detail for identifier: \(eventIdentifier)")

        // Fetch the event from EventKit
        guard let ekEvent = CalendarManager.shared.getEvent(withIdentifier: eventIdentifier) else {
            print("⚠️ Could not find event with identifier: \(eventIdentifier)")
            return
        }

        // Convert to UpcomingCalendarEvent
        let upcomingEvent = UpcomingCalendarEvent(
            id: ekEvent.eventIdentifier ?? "",
            title: ekEvent.title ?? "Event",
            location: ekEvent.location,
            meetingLink: ekEvent.url?.absoluteString,
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            calendarID: ekEvent.calendar.calendarIdentifier,
            calendarColor: UIColor(cgColor: ekEvent.calendar.cgColor),
            calendarTitle: ekEvent.calendar.title,
            hasRecurrence: ekEvent.hasRecurrenceRules,
            recurrenceRule: ekEvent.recurrenceRules?.first,
            isAllDay: ekEvent.isAllDay
        )

        // Show the event detail
        eventToShow = upcomingEvent
        showingEventDetail = true
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
