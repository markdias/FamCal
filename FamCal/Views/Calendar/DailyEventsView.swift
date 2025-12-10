import SwiftUI
import CoreData
import EventKit

struct DailyEventsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    var events: [DayEventItem]
    var selectedDate: Date
    var selectedDateString: String
    var familyMembers: [FamilyMember]
    var memberColors: [NSManagedObjectID: UIColor]
    @Binding var selectedEventIds: Set<String>
    var onDeleteSelected: (() -> Void)?

    @State private var tappedEvent: DayEventItem?
    @State private var selectedMemberIDs: [NSManagedObjectID] = []
    @State private var currentTime = Date()
    @State private var timer: Timer?
    @State private var editingEvent: DayEventItem?
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var eventToDelete: DayEventItem?
    @State private var selectedEventForDetail: UpcomingCalendarEvent?
    @State private var showingEventDetail = false
    @State private var isSelectionMode = false
    @State private var lastTapTime: Date = .distantPast
    @State private var lastTappedEventId: String = ""
    @State private var tapDelayTimer: Timer?

    private let timeColumnWidth: CGFloat = 60
    private let hourHeight: CGFloat = 60
    private let overlappingEventSpacing: CGFloat = 4
    private let memberColumnSpacing: CGFloat = 8
    private let allDayTitleLineHeight: CGFloat = UIFont.systemFont(ofSize: 13, weight: .semibold).lineHeight
    private let allDayRowHeight: CGFloat = UIFont.systemFont(ofSize: 13, weight: .semibold).lineHeight * 2 + 8
    private let calendar = Calendar.current
    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = verticalSizeClass == .compact
            let filteredEvents = events.filter { event in
                if selectedMemberIDs.isEmpty {
                    return true // Show all if no filter is selected
                }
                return !Set(selectedMemberIDs).isDisjoint(with: Set(event.memberIDs))
            }
            let timedEvents = filteredEvents.filter { !$0.isAllDay }
            let allDayEvents = filteredEvents.filter { $0.isAllDay }
            let activeMembers = currentActiveMembers

            VStack(alignment: .leading, spacing: 0) {
                if !isLandscape {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(selectedDateString)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            if isSelectionMode {
                                Button(action: {
                                    isSelectionMode = false
                                    selectedEventIds.removeAll()
                                }) {
                                    Text("Cancel")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding()
                        .background(theme.cardBackground)

                        if isSelectionMode && !selectedEventIds.isEmpty {
                            HStack {
                                Text("\(selectedEventIds.count) event\(selectedEventIds.count == 1 ? "" : "s") selected")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button(action: {
                                    onDeleteSelected?()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash.fill")
                                        Text("Delete")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red)
                                    .cornerRadius(6)
                                }
                            }
                            .padding()
                            .background(theme.cardBackground.opacity(0.8))
                        } else {
                            memberFilterView
                                .padding(.bottom, 8)
                        }
                    }

                    Divider()
                } else if !activeMembers.isEmpty {
                    memberColumnsHeader(for: activeMembers, totalWidth: proxy.size.width)
                        .padding(.vertical, 4)
                }

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !allDayEvents.isEmpty {
                                allDayEventsSection(for: allDayEvents)
                            }

                            ZStack(alignment: .topLeading) {
                                timelineView
                                eventsView(for: timedEvents, isLandscape: isLandscape, activeMembers: activeMembers)

                                // Current time line
                                if calendar.isDate(selectedDate, inSameDayAs: currentTime) {
                                    VStack(spacing: 0) {
                                        Spacer()
                                            .frame(height: yOffset(for: currentTime))

                                        HStack(spacing: 0) {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 8, height: 8)

                                            Rectangle()
                                                .fill(Color.red)
                                                .frame(height: 0.5)
                                        }
                                        .id("currentTime")

                                        Spacer()
                                    }
                                }
                            }
                            .padding(.top, 10)

                            Spacer(minLength: 24)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if calendar.isDate(selectedDate, inSameDayAs: currentTime) {
                                withAnimation {
                                    scrollProxy.scrollTo("currentTime", anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(theme.cardBackground)
            .cornerRadius(isLandscape ? 0 : 16)
            .overlay(
                Group {
                    if !isLandscape {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.cardStroke, lineWidth: 1)
                    }
                }
            )
            .ignoresSafeArea(isLandscape ? .container : [], edges: .horizontal)
        }
        .onAppear {
            selectedMemberIDs = familyMembers.map { $0.objectID }
            startTimeUpdates()
        }
        .onDisappear {
            stopTimeUpdates()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let event = editingEvent {
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
                EditEventView(upcomingEvent: upcomingEvent)
            }
        }
        .confirmationDialog("Delete Event", isPresented: $showingDeleteConfirmation, presenting: eventToDelete) { event in
            Button("Delete", role: .destructive) {
                deleteEvent(event)
            }
        } message: { event in
            Text("Are you sure you want to delete '\(event.title)'?")
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEventForDetail {
                EventDetailView(event: event)
            }
        }
    }

    private func handleEventTap(event: DayEventItem) {
        // Cancel any pending single tap timer
        tapDelayTimer?.invalidate()

        // Check if this is a double tap
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

        if lastTappedEventId == event.eventIdentifier && timeSinceLastTap < 0.3 {
            // Double tap detected - enter selection mode
            isSelectionMode = true
            selectedEventIds.removeAll()
            selectedEventIds.insert(event.eventIdentifier)
            lastTapTime = .distantPast  // Reset to prevent triple tap issues
            tapDelayTimer?.invalidate()
            tapDelayTimer = nil
        } else {
            // Possible start of double tap or single tap
            lastTapTime = now
            lastTappedEventId = event.eventIdentifier

            // Delay action to see if another tap comes
            tapDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                handleSingleTap(event: event)
                tapDelayTimer = nil
            }
        }
    }

    private func handleSingleTap(event: DayEventItem) {
        if isSelectionMode {
            // In selection mode: toggle selection
            if selectedEventIds.contains(event.eventIdentifier) {
                selectedEventIds.remove(event.eventIdentifier)
            } else {
                selectedEventIds.insert(event.eventIdentifier)
            }
        } else {
            // Normal mode: show event details
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
            selectedEventForDetail = upcomingEvent
            showingEventDetail = true
        }
    }

    private func deleteEvent(_ event: DayEventItem) {
        let store = EKEventStore()
        if let ekEvent = store.event(withIdentifier: event.eventIdentifier) {
            do {
                try store.remove(ekEvent, span: .thisEvent, commit: true)
            } catch {
                print("❌ Failed to delete event: \(error.localizedDescription)")
            }
        }
        eventToDelete = nil
    }

    private var currentActiveMembers: [FamilyMember] {
        let selectedIDs = selectedMemberIDs.isEmpty ? Set(familyMembers.map { $0.objectID }) : Set(selectedMemberIDs)
        return familyMembers.filter { selectedIDs.contains($0.objectID) }
    }

    private var memberFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(familyMembers) { member in
                    Button(action: {
                        withAnimation {
                            if let index = selectedMemberIDs.firstIndex(of: member.objectID) {
                                selectedMemberIDs.remove(at: index)
                            } else {
                                selectedMemberIDs.append(member.objectID)
                            }
                        }
                    }) {
                        Text(member.name ?? "")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedMemberIDs.contains(member.objectID) ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selectedMemberIDs.contains(member.objectID) ? Color(memberColors[member.objectID] ?? .gray) : Color.clear)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func memberColumnsHeader(for members: [FamilyMember], totalWidth: CGFloat) -> some View {
        let columnCount = max(1, members.count)
        let contentWidth = max(0, totalWidth - timeColumnWidth)
        let columnWidth = columnCount == 0 ? 0 : (contentWidth - CGFloat(max(0, columnCount - 1)) * memberColumnSpacing) / CGFloat(columnCount)

        return HStack(alignment: .center, spacing: memberColumnSpacing) {
            ForEach(members, id: \.objectID) { member in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(memberColors[member.objectID] ?? .gray))
                        .frame(width: 8, height: 8)

                    Text(member.name ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(width: columnWidth, alignment: .leading)
                .background(theme.cardBackground.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.leading, timeColumnWidth)
    }

    private var timelineView: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(formatHour(hour))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.mutedTagColor)
                        .frame(width: 45, alignment: .trailing)
                        .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

                    VStack(spacing: 0) {
                        Divider()
                    }
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }

    private func eventsView(for events: [DayEventItem], isLandscape: Bool, activeMembers: [FamilyMember]) -> some View {
        GeometryReader { geometry in
            let layouts: [EventLayout]

            if isLandscape {
                layouts = calculateMemberColumnLayouts(for: events, members: activeMembers, availableWidth: geometry.size.width)
            } else {
                layouts = calculateStackedLayouts(for: events, contentWidth: geometry.size.width - timeColumnWidth)
            }

            return ZStack(alignment: .topLeading) {
                ForEach(layouts) { layout in
                    eventCell(for: layout.event, isTapped: tappedEvent == layout.event, isSelected: selectedEventIds.contains(layout.event.eventIdentifier))
                        .frame(width: layout.width, height: layout.height)
                        .offset(x: layout.x, y: layout.y)
                        .onTapGesture {
                            handleEventTap(event: layout.event)
                        }
                        .contextMenu {
                            Button(action: {
                                editingEvent = layout.event
                                showingEditSheet = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive, action: {
                                eventToDelete = layout.event
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }

                            Divider()

                            Button(action: {
                                isSelectionMode = true
                                selectedEventIds.insert(layout.event.eventIdentifier)
                            }) {
                                Label("Select for Batch Delete", systemImage: "checkmark.circle")
                            }
                        }
                }
            }
            .padding(.leading, timeColumnWidth)
        }
    }

    private func allDayEventsSection(for events: [DayEventItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All-Day")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(events) { event in
                allDayEventCell(for: event)
            }
        }
        .padding(.bottom, 8)
    }

    private func allDayEventCell(for event: DayEventItem) -> some View {
        let isPast = Date() > event.endDate
        let isSelected = selectedEventIds.contains(event.eventIdentifier)

        return ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 8) {
                Capsule()
                    .fill(Color(event.color))
                    .frame(width: 4, height: allDayTitleLineHeight)
                    .opacity(isPast ? 0.6 : 1.0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .opacity(isPast ? 0.7 : 1.0)
                    HStack(spacing: 4) {
                        Text(event.memberNames.joined(separator: ", "))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(theme.mutedTagColor)
                            .opacity(isPast ? 0.7 : 1.0)

                        if let driverName = event.driverName {
                            Group {
                                if let phone = event.driverPhone, !phone.isEmpty {
                                    Link(destination: URL(string: "tel:\(phone)")!) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "car.fill")
                                                .font(.system(size: 10))
                                            Text(driverName)
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(theme.mutedTagColor)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 10))
                                        Text(driverName)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(theme.mutedTagColor)
                                }
                            }
                            .opacity(isPast ? 0.7 : 1.0)
                        }

                        if event.hasChecklist, let progress = event.checklistProgress {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.square")
                                    .font(.system(size: 10))
                                Text(progress.displayString)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(theme.mutedTagColor)
                            .opacity(isPast ? 0.7 : 1.0)
                        }
                    }
                }

                Spacer()
            }
            .frame(minHeight: allDayRowHeight, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color(event.color).opacity(0.25) : Color(event.color).opacity(isPast ? 0.10 : 0.15))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .onTapGesture {
                handleEventTap(event: event)
            }
            .contextMenu {
                Button(action: {
                    editingEvent = event
                    showingEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: {
                    eventToDelete = event
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete", systemImage: "trash")
                }

                Divider()

                Button(action: {
                    isSelectionMode = true
                    selectedEventIds.insert(event.eventIdentifier)
                }) {
                    Label("Select for Batch Delete", systemImage: "checkmark.circle")
                }
            }

            // Selection indicator for all-day events
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color(event.color)))
            }
        }
    }

    private func eventCell(for event: DayEventItem, isTapped: Bool, isSelected: Bool = false) -> some View {
        let isPast = Date() > event.endDate
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let isShortEvent = duration <= 1800 // 30 minutes

        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: isShortEvent ? 0 : 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(isShortEvent ? 1 : 2)
                    .opacity(isPast ? 0.7 : 1.0)

                if !isShortEvent {
                    Text(event.timeRange ?? "")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(isPast ? 0.6 : 0.8))

                    HStack(spacing: 4) {
                        Text(event.memberNames.joined(separator: ", "))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(isPast ? 0.6 : 0.8))

                        if let driverName = event.driverName {
                            if let phone = event.driverPhone, !phone.isEmpty {
                                Link(destination: URL(string: "tel:\(phone)")!) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 8))
                                        Text(driverName)
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundColor(.white.opacity(isPast ? 0.6 : 0.8))
                                }
                            } else {
                                HStack(spacing: 2) {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 8))
                                    Text(driverName)
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(isPast ? 0.6 : 0.8))
                            }
                        }

                        if event.hasChecklist, let progress = event.checklistProgress {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.square")
                                    .font(.system(size: 8))
                                Text(progress.displayString)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(isPast ? 0.6 : 0.8))
                        }
                    }
                }
            }
            .padding(isShortEvent ? 2 : 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(event.color).opacity(isPast ? (isTapped ? 0.5 : 0.35) : (isTapped ? 1.0 : 0.6)))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(event.color), lineWidth: 1)
                    .opacity(isPast ? 0.6 : 1.0)
            )

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color(event.color)))
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }

    private func calculateMemberColumnLayouts(for events: [DayEventItem], members: [FamilyMember], availableWidth: CGFloat) -> [EventLayout] {
        guard !members.isEmpty else {
            return calculateStackedLayouts(for: events, contentWidth: availableWidth - timeColumnWidth)
        }

        let contentWidth = max(0, availableWidth - timeColumnWidth)
        let perMemberSpacing = memberColumnSpacing
        let columnWidth = (contentWidth - CGFloat(max(0, members.count - 1)) * perMemberSpacing) / CGFloat(members.count)

        var layouts: [EventLayout] = []
        for (memberIndex, member) in members.enumerated() {
            let memberEvents = events.filter { $0.memberIDs.contains(member.objectID) }
            let xOffset = CGFloat(memberIndex) * (columnWidth + perMemberSpacing)
            layouts.append(contentsOf: calculateStackedLayouts(for: memberEvents, contentWidth: columnWidth, xOffset: xOffset))
        }

        return layouts
    }

    private func calculateStackedLayouts(for events: [DayEventItem], contentWidth: CGFloat, xOffset: CGFloat = 0) -> [EventLayout] {
        guard contentWidth > 0 else { return [] }

        var layouts: [EventLayout] = []
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        var columns: [[DayEventItem]] = []

        for event in sortedEvents {
            var placed = false
            for (columnIndex, column) in columns.enumerated() {
                if let lastEvent = column.last, event.startDate >= lastEvent.endDate {
                    columns[columnIndex].append(event)
                    placed = true
                    break
                }
            }
            if !placed {
                columns.append([event])
            }
        }

        let totalColumns = max(columns.count, 1)
        let columnWidth = (contentWidth - CGFloat(max(0, totalColumns - 1)) * overlappingEventSpacing) / CGFloat(totalColumns)

        for (columnIndex, column) in columns.enumerated() {
            for event in column {
                let yPosition = yOffset(for: event.startDate)
                let height = max(15, yOffset(for: event.endDate) - yPosition)
                let xPosition = xOffset + CGFloat(columnIndex) * (columnWidth + overlappingEventSpacing)

                layouts.append(EventLayout(event: event, x: xPosition, y: yPosition, width: columnWidth, height: height))
            }
        }

        return layouts
    }

    private func yOffset(for date: Date) -> CGFloat {
        let startOfDay = calendar.startOfDay(for: date)
        let timeInterval = date.timeIntervalSince(startOfDay)
        return (CGFloat(timeInterval) / 3600.0 * hourHeight) + 4.0
    }

    private func startTimeUpdates() {
        currentTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimeUpdates() {
        timer?.invalidate()
        timer = nil
    }
}

struct EventLayout: Identifiable {
    let id = UUID()
    let event: DayEventItem
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

extension DayEventItem: Equatable {
    static func == (lhs: DayEventItem, rhs: DayEventItem) -> Bool {
        lhs.id == rhs.id
    }
}
