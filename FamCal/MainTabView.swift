//
//  MainTabView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

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
    @State private var addEventInitialDate: Date? = nil
    @State private var calendarSelectedDate: Date = Date()
    @State private var calendarDisplayMode: CalendarView.CalendarDisplayMode = .month
    @State private var calendarTodayTrigger = UUID()
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: AppTheme {
        themeManager.selectedTheme
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
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(initialDate: addEventInitialDate)
                .environment(\.managedObjectContext, viewContext)
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
                Text("Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
