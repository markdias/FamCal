//
//  EventDetailView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import EventKit
import MapKit
import CoreLocation
import CoreData

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let event: UpcomingCalendarEvent

    private var defaultMapsApp: String { appSettingsManager.defaultMapsApp }

    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var ekEvent: EKEvent?
    @State private var alerts: [EKAlarm] = []
    @State private var mapRegion = MKCoordinateRegion()
    @State private var locationCoordinates: CLLocationCoordinate2D?
    @State private var isLoadingLocation = false
    @State private var showingCalendarPicker = false
    @State private var showingRecurringDeleteOptions = false
    @State private var showingLinkedDeleteDialog = false
    @State private var pendingDeleteSpan: EKSpan = .thisEvent
    @State private var pendingDeleteScope: DeleteScope = .singleCalendar
    @State private var driver: Driver?
    @State private var driverFamilyMemberId: UUID?
    @State private var selectedDriver: DriverWrapper?
    @State private var driverTravelTimeMinutes: Int = 15
    @State private var eventStore = EKEventStore()
    @State private var availableCalendars: [EKCalendar] = []
    @State private var geocodeTask: Task<Void, Never>?
    @State private var selectedCalendarID: String?
    @State private var pendingAlerts: [EKAlarm] = []
    @State private var showingAlertPicker = false
    @State private var selectedAlertMinutes: Int = 15
    @State private var showingCreateEventForDriverAlert = false
    @State private var driverToCreateEventFor: DriverWrapper?

    @FetchRequest(
        entity: Driver.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Driver.name, ascending: true)]
    )
    private var drivers: FetchedResults<Driver>

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @FetchRequest(
        entity: SavedAddress.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedAddress.name, ascending: true)]
    )
    private var savedAddresses: FetchedResults<SavedAddress>

    @FetchRequest(
        entity: Checklist.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Checklist.createdAt, ascending: true)]
    )
    private var allChecklists: FetchedResults<Checklist>

    private var eventChecklist: Checklist? {
        let eventId = event.id
        for checklist in allChecklists {
            if checklist.eventIdentifier == eventId && checklist.deletedAt == nil {
                return checklist
            }
        }
        return nil
    }

    private var driverFamilyMembers: [FamilyMember] {
        familyMembers.filter { $0.isDriver }
    }

    private var allAvailableDrivers: [DriverWrapper] {
        var combined: [DriverWrapper] = []
        for driver in drivers {
            combined.append(.regular(driver))
        }
        // Only include family members that are not already selected as the driver
        for member in driverFamilyMembers {
            if selectedDriver?.id != member.id {
                combined.append(.familyMember(member))
            }
        }
        return combined
    }

    private var relevantCalendars: [EKCalendar] {
        // Get all calendar IDs from family members and shared calendars
        var calendarIDs = Set<String>()

        for member in familyMembers {
            if let memberCals = member.memberCalendars?.allObjects as? [FamilyMemberCalendar] {
                for cal in memberCals {
                    if let calID = cal.calendarID {
                        calendarIDs.insert(calID)
                    }
                }
            }
        }

        for sharedCal in sharedCalendars {
            if let calID = sharedCal.calendarID {
                calendarIDs.insert(calID)
            }
        }

        // Filter availableCalendars to only include relevant ones
        return availableCalendars.filter { calendarIDs.contains($0.calendarIdentifier) }
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private func formatRecurrenceRule(_ rule: EKRecurrenceRule) -> String {
        let frequency: String
        switch rule.frequency {
        case .daily:
            frequency = "Daily"
        case .weekly:
            frequency = "Weekly"
        case .monthly:
            frequency = "Monthly"
        case .yearly:
            frequency = "Yearly"
        @unknown default:
            frequency = "Repeats"
        }

        var recurrenceText = frequency
        if rule.interval > 1 {
            recurrenceText += " every \(rule.interval) \(frequency.lowercased())"
        }

        if let endDate = rule.recurrenceEnd?.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            recurrenceText += " until \(formatter.string(from: endDate))"
        }

        return recurrenceText
    }

    private func getLinkedCalendars(for eventItem: UpcomingCalendarEvent) -> [String]? {
        var linkedCalendars: [String] = []

        // Get all family member calendars
        for member in familyMembers {
            if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
                for cal in memberCals {
                    if let calName = cal.calendarName, !linkedCalendars.contains(calName) {
                        // Check if this calendar contains the event
                        if let calId = cal.calendarID {
                            let store = EKEventStore()
                            if let calendar = store.calendar(withIdentifier: calId) {
                                let predicate = store.predicateForEvents(withStart: eventItem.startDate.addingTimeInterval(-86400), end: eventItem.startDate.addingTimeInterval(86400), calendars: [calendar])
                                let events = store.events(matching: predicate).filter { $0.title == eventItem.title }
                                if !events.isEmpty {
                                    linkedCalendars.append(calName)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Also check shared calendars
        if let sharedCals = familyMembers.first?.sharedCalendars as? Set<SharedCalendar> {
            for sharedCal in sharedCals {
                if let calName = sharedCal.calendarName, !linkedCalendars.contains(calName) {
                    if let calId = sharedCal.calendarID {
                        let store = EKEventStore()
                        if let calendar = store.calendar(withIdentifier: calId) {
                            let predicate = store.predicateForEvents(withStart: eventItem.startDate.addingTimeInterval(-86400), end: eventItem.startDate.addingTimeInterval(86400), calendars: [calendar])
                            let events = store.events(matching: predicate).filter { $0.title == eventItem.title }
                            if !events.isEmpty {
                                linkedCalendars.append(calName)
                            }
                        }
                    }
                }
            }
        }

        return linkedCalendars.isEmpty ? nil : linkedCalendars
    }

    private var recurringEventSection: some View {
        Group {
            if event.hasRecurrence {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "repeat.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))

                        Text("Recurring Event")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                    }

                    if let recurrenceRule = event.recurrenceRule {
                        Text(formatRecurrenceRule(recurrenceRule))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.leading, 28)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var linkedCalendarsSection: some View {
        Group {
            if let linkedCalendars = getLinkedCalendars(for: event), !linkedCalendars.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))

                        Text("Linked Calendars")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                    }

                    ForEach(linkedCalendars, id: \.self) { calendarName in
                        Text("• \(calendarName)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.leading, 28)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .contextMenu {
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
                                    Button(action: { deleteEvent(event, span: .thisEvent) }) {
                                        Label("Delete This Event", systemImage: "trash")
                                    }
                                    Button(role: .destructive, action: { deleteEvent(event, span: .futureEvents) }) {
                                        Label("Delete This & Future Events", systemImage: "trash")
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } else {
                                Button(role: .destructive, action: { deleteEvent(event) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                    // Location - tappable to open maps
                    if let location = event.location, !location.isEmpty {
                        Button(action: { MapsUtility.openLocation(location, in: defaultMapsApp) }) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 10) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Location")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)
                                        Text(location)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                    }

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }
                    }

                    if let meetingLink = event.meetingLink,
                       let destination = MeetingLinkHelper.normalizedURL(from: meetingLink) {
                        Link(destination: destination) {
                            HStack(spacing: 10) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Meeting Link")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                    Text(MeetingLinkHelper.displayLabel(for: meetingLink))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }
                    }

                    // Date and Time section with icons
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Date")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                Text(Self.fullDateFormatter.string(from: event.startDate))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            Spacer()
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Time")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                Text("\(Self.timeFormatter.string(from: event.startDate)) – \(Self.timeFormatter.string(from: event.endDate))")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)

                    // Calendar selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        HStack(spacing: 12) {
                            Menu {
                                ForEach(relevantCalendars, id: \.calendarIdentifier) { calendar in
                                    Button(action: {
                                        selectedCalendarID = calendar.calendarIdentifier
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
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(uiColor: event.calendarColor))
                                        .frame(width: 12, height: 12)

                                    Text(event.calendarTitle)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.primary)

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Checklist section - positioned before driver/alerts
                    ChecklistSectionView(
                        checklist: eventChecklist,
                        eventIdentifier: event.id,
                        eventGroupId: nil,
                        eventTitle: event.title,
                        eventStartDate: event.startDate,
                        eventEndDate: event.endDate
                    )

                    driverSection

                    // Alert section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        HStack(spacing: 12) {
                            AlertMenuButton(
                                currentAlert: alerts.first,
                                onSelect: { updateAlert(minutes: $0) }
                            )

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Map section with location header
                    if locationCoordinates != nil || isLoadingLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))

                                Text("Location Preview")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)

                                Spacer()
                            }
                            .padding(.horizontal, 20)

                            if locationCoordinates != nil {
                                Map(position: .constant(.region(mapRegion)))
                                    .frame(height: 280)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                            } else if isLoadingLocation {
                                HStack {
                                    ProgressView()
                                        .tint(Color(red: 0.33, green: 0.33, blue: 0.33))
                                    Text("Loading map...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 280)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    recurringEventSection
                    linkedCalendarsSection

                    // Delete button
                    Button(action: handleDeleteTap) {
                        Text("Delete Event")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isEditing = true }) {
                        Text("Edit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditEventView(upcomingEvent: event)
            }
            .onChange(of: isEditing) { _, newValue in
                // When the edit sheet closes, refresh alerts from the updated event
                if newValue == false {
                    fetchEventDetails()
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    startDeleteFlow(span: .thisEvent)
                }
            } message: {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, yyyy"
                let formattedDate = dateFormatter.string(from: event.startDate)

                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .short
                let formattedTime = timeFormatter.string(from: event.startDate)

                var message = "Are you sure you want to delete \"\(event.title)\"?\n\n📆 \(formattedDate) at \(formattedTime)"
                if let location = event.location, !location.isEmpty {
                    message += "\n📍 \(location)"
                }
                return Text(message)
            }
            .confirmationDialog("Delete Recurring Event?", isPresented: $showingRecurringDeleteOptions, titleVisibility: .visible) {
                Button("Delete Only This Event", role: .destructive) {
                    startDeleteFlow(span: .thisEvent)
                }
                Button("Delete This and Future Events", role: .destructive) {
                    startDeleteFlow(span: .futureEvents)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, yyyy"
                let formattedDate = dateFormatter.string(from: event.startDate)

                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .short
                let formattedTime = timeFormatter.string(from: event.startDate)

                var message = "Which instances of \"\(event.title)\" would you like to delete?\n\n📆 \(formattedDate) at \(formattedTime)"
                if let location = event.location, !location.isEmpty {
                    message += "\n📍 \(location)"
                }
                message += "\n\nThis is a recurring event."
                return Text(message)
            }
            .confirmationDialog("Delete Linked Copies?", isPresented: $showingLinkedDeleteDialog, titleVisibility: .visible) {
                Button("Delete only this calendar", role: .destructive) {
                    deleteEvent(scope: .singleCalendar, span: pendingDeleteSpan)
                }
                Button("Delete in all linked calendars", role: .destructive) {
                    deleteEvent(scope: .allLinked, span: pendingDeleteSpan)
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteScope = .singleCalendar
                }
            } message: {
                Text("This event is linked to other calendars. Delete only here or everywhere?")
            }
            .alert("Create Event for Driver?", isPresented: $showingCreateEventForDriverAlert) {
                Button("Yes") {
                    if let driver = driverToCreateEventFor {
                        createEventForDriver(driver)
                    }
                }
                Button("No") {
                    driverToCreateEventFor = nil
                }
            } message: {
                if let driver = driverToCreateEventFor {
                    Text("Would you like to create a separate event for \(driver.name)'s drive?")
                }
            }
            .onAppear {
                // Load available calendars for context menu
                loadAvailableCalendars()

                // Try to fetch event details, but don't fail if we can't
                fetchEventDetails()

                // Load location map regardless of event details
                if let location = event.location, !location.isEmpty {
                    geocodeLocation(location, zoom: 0.002) // Much tighter zoom
                }

                // Fetch driver information
                fetchDriver()
            }
            .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                fetchEventDetails()
            }
            .onDisappear {
                geocodeTask?.cancel()
            }
        }
    }

    // MARK: - View Components

    private var driverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Driver")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)

            // Driver selection dropdown
            HStack(spacing: 12) {
                Menu {
                    Button(action: { selectedDriver = nil }) {
                        HStack {
                            Text("None")
                            if selectedDriver == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    if !allAvailableDrivers.isEmpty {
                        Divider()

                        ForEach(allAvailableDrivers, id: \.id) { driverWrapper in
                            Button(action: {
                                selectedDriver = driverWrapper
                                // Only show alert if selecting a family member driver
                                if case .familyMember(_) = driverWrapper {
                                    driverToCreateEventFor = driverWrapper
                                    showingCreateEventForDriverAlert = true
                                }
                            }) {
                                HStack {
                                    Text(driverWrapper.name)
                                    if selectedDriver?.id == driverWrapper.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))

                        Text(selectedDriver?.name ?? "None")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .onChange(of: selectedDriver) { _, _ in
                    saveDriver()
                }
            }
            .padding(.horizontal, 20)

            // Phone button (only show if driver selected and has phone)
            if let selectedDriver = selectedDriver, let phone = selectedDriver.phone, !phone.isEmpty {
                HStack(spacing: 12) {
                    Link(destination: URL(string: "tel:\(phone)")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(phone)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helper Methods
    
    private func getSavedAddress(for location: String) -> SavedAddress? {
        // Try to find a saved address that matches this location
        return savedAddresses.first { savedAddr in
            guard let address = savedAddr.address else { return false }
            // Match if the event location contains the saved address or vice versa
            return location.lowercased().contains(address.lowercased()) ||
                   address.lowercased().contains(location.lowercased())
        }
    }

    private func fetchDriver() {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            print("🚗 Fetching driver for event: \(event.id)")
            print("   FamilyEvents found: \(results.count)")

            if let familyEvent = results.first {
                self.driver = familyEvent.driver
                self.driverFamilyMemberId = familyEvent.driverFamilyMemberId

                // Set selectedDriver for editing
                if let driver = familyEvent.driver {
                    self.selectedDriver = .regular(driver)
                    print("✅ Regular driver loaded: \(driver.name ?? "nil")")
                } else if let driverMemberId = familyEvent.driverFamilyMemberId,
                          let familyMember = self.familyMembers.first(where: { $0.id == driverMemberId }) {
                    self.selectedDriver = .familyMember(familyMember)
                    print("✅ Family member driver loaded: \(familyMember.name ?? "nil")")
                }

                // Ensure metadata exists remotely if we already have a driver
                if familyEvent.driver != nil || familyEvent.driverFamilyMemberId != nil {
                    Task {
                        await syncDriverMetadataToSupabase(for: familyEvent)
                    }
                }
            } else {
                print("ℹ️ No FamilyEvent found for this event")
            }
        } catch {
            print("❌ Failed to fetch driver for event: \(error.localizedDescription)")
        }
    }

    private func saveDriver() {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)

        do {
            let results = try viewContext.fetch(fetchRequest)

            // Ensure a FamilyEvent exists for this calendar item so we can persist driver metadata
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
                print("ℹ️ Created FamilyEvent placeholder for driver sync (event \(event.id))")
            }

            // Keep calendar linkage up to date
            if familyEvent.calendarId == nil {
                familyEvent.calendarId = event.calendarID
            }

            // Clear existing driver relationships
            familyEvent.driver = nil
            familyEvent.driverFamilyMemberId = nil

            // Set new driver
            if let selectedDriver = selectedDriver {
                switch selectedDriver {
                case .regular(let driver):
                    familyEvent.driver = driver
                    print("✅ Saved regular driver: \(driver.name ?? "Unknown")")

                case .familyMember(let member):
                    familyEvent.driverFamilyMemberId = member.id
                    print("✅ Saved family member driver: \(member.name ?? "Unknown")")

                    // If driver is a family member and not already in attendees, add them
                    if let attendees = familyEvent.attendees as? Set<FamilyMember> {
                        if !attendees.contains(member) {
                            familyEvent.addToAttendees(member)
                            print("✅ Added family member driver to attendees")
                        }
                    } else {
                        familyEvent.addToAttendees(member)
                        print("✅ Added family member driver to attendees")
                    }
                }
            } else {
                print("✅ Cleared driver")
            }

            try viewContext.save()
            print("✅ Driver saved to CoreData")

            // Persist the app-only driver link to Supabase
            Task {
                await syncDriverMetadataToSupabase(for: familyEvent)
            }
        } catch {
            print("❌ Failed to save driver: \(error.localizedDescription)")
        }
    }

    private func syncDriverMetadataToSupabase(for familyEvent: FamilyEvent) async {
        guard let userId = SupabaseAuthManager.shared.userId else {
            print("⚠️ Supabase sync skipped: no user ID")
            return
        }

        guard !event.calendarID.isEmpty else {
            print("⚠️ Supabase sync skipped: missing calendar ID for event \(event.id)")
            return
        }

        let driverFamilyMemberId = familyEvent.driverFamilyMemberId?.uuidString
        let extra = buildDriverExtraMetadata(from: selectedDriver)

        do {
            try await SupabaseManager.shared.upsertCalendarEventMetadata(
                userId: userId,
                eventIdentifier: event.id,
                driverFamilyMemberId: driverFamilyMemberId,
                extra: extra.isEmpty ? nil : extra
            )
            print("✅ Synced driver metadata to Supabase for event \(event.id)")
        } catch {
            print("❌ Failed to sync driver metadata to Supabase: \(error)")
        }
    }

    private func buildDriverExtraMetadata(from driver: DriverWrapper?) -> [String: AnyCodable] {
        guard let driver else { return [:] }

        switch driver {
        case .regular(let driverModel):
            var payload: [String: AnyCodable] = ["driver_type": .string("driver_record")]
            if let id = driverModel.id?.uuidString {
                payload["driver_id"] = .string(id)
            }
            if let name = driverModel.name {
                payload["driver_name"] = .string(name)
            }
            if let phone = driverModel.phone {
                payload["driver_phone"] = .string(phone)
            }
            if let email = driverModel.email {
                payload["driver_email"] = .string(email)
            }
            return payload
        case .familyMember(let member):
            var payload: [String: AnyCodable] = ["driver_type": .string("family_member")]
            if let name = member.name {
                payload["driver_name"] = .string(name)
            }
            if let memberId = member.id?.uuidString {
                payload["family_member_id"] = .string(memberId)
            }
            return payload
        }
    }

    private func callDriver(phone: String) {
        let cleanedPhone = phone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel:\(cleanedPhone)") {
            UIApplication.shared.open(url)
        }
    }

    private func emailDriver(email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }

    private func fetchEventDetails() {
        // Try to fetch full event details for alarms, but continue without them if not available
        // This prevents crashes if the event has been deleted or is inaccessible
        let ekEvent = CalendarManager.shared.fetchEventDetails(
            withIdentifier: event.id,
            occurrenceStartDate: event.startDate
        ) ?? CalendarManager.shared.fetchEventDetails(withIdentifier: event.id)

        guard let ekEvent else {
            print("⚠️ Could not find full event details for: \(event.id)")
            print("   Event may have been deleted or is inaccessible")
            return
        }

        self.ekEvent = ekEvent
        self.alerts = ekEvent.alarms ?? []
    }

    private func geocodeLocation(_ locationString: String, zoom: Double = 0.01) {
        let trimmedLocation = locationString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLocation.isEmpty else {
            return
        }

        geocodeTask?.cancel()
        isLoadingLocation = true

        geocodeTask = Task {
            do {
                let coordinate: CLLocationCoordinate2D? = try await {
                    if #available(iOS 17.0, *) {
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = trimmedLocation
                        let search = MKLocalSearch(request: request)
                        let response = try await search.start()
                        if #available(iOS 26.0, *) {
                            return response.mapItems.first?.location.coordinate
                        } else {
                            // Fallback on earlier versions - use CLGeocoder
                            let geocoder = CLGeocoder()
                            let placemarks = try await geocoder.geocodeAddressString(trimmedLocation)
                            return placemarks.first?.location?.coordinate
                        }
                    } else {
                        let geocoder = CLGeocoder()
                        let placemarks = try await geocoder.geocodeAddressString(trimmedLocation)
                        return placemarks.first?.location?.coordinate
                    }
                }()

                await MainActor.run {
                    isLoadingLocation = false
                    guard let coordinate else {
                        locationCoordinates = nil
                        return
                    }

                    locationCoordinates = coordinate
                    mapRegion = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: zoom, longitudeDelta: zoom)
                    )
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    isLoadingLocation = false
                    locationCoordinates = nil
                }
                print("⚠️ Failed to geocode location '\(trimmedLocation)': \(error.localizedDescription)")
            }
        }
    }

    private func handleDeleteTap() {
        if event.hasRecurrence {
            showingRecurringDeleteOptions = true
        } else {
            showingDeleteConfirmation = true
        }
    }

    private func startDeleteFlow(span: EKSpan) {
        pendingDeleteSpan = span

        let linked = linkedFamilyEvents(for: event.id)
        if linked.count > 1 {
            showingLinkedDeleteDialog = true
        } else {
            deleteEvent(scope: .singleCalendar, span: span)
        }
    }

    private func deleteEvent(scope: DeleteScope = .singleCalendar, span: EKSpan = .thisEvent) {
        isDeleting = true

        Task {
            let success = await deleteLinkedEvents(scope: scope, span: span)

            if success {
                DispatchQueue.main.async {
                    dismiss()
                }
            } else {
                DispatchQueue.main.async {
                    isDeleting = false
                }
            }
        }
    }

    private func deleteLinkedEvents(scope: DeleteScope, span: EKSpan) async -> Bool {
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
                    meetingLink: nil,
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
        }

        return anyDeleted
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

    private func alertDisplayText(_ alarm: EKAlarm) -> String {
        let minutes = abs(Int(alarm.relativeOffset / 60))

        if minutes == 0 {
            return "At time of event"
        } else if minutes < 60 {
            return minutes == 1 ? "1 minute before" : "\(minutes) minutes before"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour before" : "\(hours) hours before"
        } else {
            let days = minutes / 1440
            return days == 1 ? "1 day before" : "\(days) days before"
        }
    }

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
                    dismiss()
                } catch {
                    print("❌ Failed to move event: \(error.localizedDescription)")
                }
            }
        }
    }

    private func deleteEvent(_ event: UpcomingCalendarEvent, span: EKSpan = .thisEvent) {
        let success = CalendarManager.shared.deleteEvent(
            withIdentifier: event.id,
            occurrenceStartDate: event.startDate,
            from: event.calendarID,
            span: span
        )

        if success {
            // Cancel any scheduled notifications for this event
            Task {
                await NotificationManager.shared.cancelEventNotifications(for: event.id)
            }

            // Delete from CoreData
            let fetchRequest = FamilyEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)
            if let familyEvent = try? viewContext.fetch(fetchRequest).first {
                viewContext.delete(familyEvent)
                try? viewContext.save()
            }

            print("✅ Event deleted successfully")
            dismiss()
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
                // Show a success message and dismiss
                dismiss()
            } catch {
                print("❌ Failed to save duplicated event: \(error.localizedDescription)")
            }
        }
    }

    private func updateAlert(minutes: Int) {
        guard let ekEvent = ekEvent else { return }

        // Remove all existing alarms
        for alarm in ekEvent.alarms ?? [] {
            ekEvent.removeAlarm(alarm)
        }

        // Add the new alarm
        let alarm = EKAlarm(relativeOffset: -Double(minutes * 60))
        ekEvent.addAlarm(alarm)

        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)
            // Refresh alerts from the updated event
            self.alerts = ekEvent.alarms ?? []
            print("✅ Alert updated: \(alertTimeText(minutes))")
        } catch {
            print("❌ Failed to update alert: \(error.localizedDescription)")
        }
    }

    private func alertTimeText(_ minutes: Int) -> String {
        if minutes == 0 {
            return "At time of event"
        } else if minutes < 60 {
            return minutes == 1 ? "1 minute before" : "\(minutes) minutes before"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour before" : "\(hours) hours before"
        } else {
            let days = minutes / 1440
            return days == 1 ? "1 day before" : "\(days) days before"
        }
    }

    private func createEventForDriver(_ driver: DriverWrapper) {
        // Create a new event for the driver using the event's calendar
        let driverEventTitle = "\(event.title) - \(driver.name)'s drive"

        let eventId = CalendarManager.shared.createEvent(
            title: driverEventTitle,
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location?.isEmpty == true ? nil : event.location,
            notes: "Driving event for \(event.title)",
            isAllDay: event.isAllDay,
            in: event.calendarID,
            alertOption: AlertOption.none
        )

        if let eventId = eventId {
            print("✅ Created event for \(driver.name): \(eventId)")
        } else {
            print("❌ Failed to create event for driver")
        }
    }
}

private struct AlertMenuButton: View {
    let currentAlert: EKAlarm?
    let onSelect: (Int) -> Void

    var currentAlertText: String {
        guard let alert = currentAlert else { return "None" }
        let minutes = abs(Int(alert.relativeOffset / 60))
        return Self.formatAlert(minutes)
    }

    var body: some View {
        Menu {
            MenuItemFor0Minutes()
            MenuItemFor5Minutes()
            MenuItemFor10Minutes()
            MenuItemFor15Minutes()
            MenuItemFor30Minutes()
            MenuItemFor60Minutes()
            MenuItemFor1440Minutes()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))

                Text(currentAlertText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func makeMenuItem(_ minutes: Int) -> some View {
        let isSelected = currentAlert != nil && abs(Int(currentAlert!.relativeOffset)) == minutes * 60
        Button(action: { onSelect(minutes) }) {
            HStack {
                Text(Self.formatAlert(minutes))
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    @ViewBuilder
    private func MenuItemFor0Minutes() -> some View {
        makeMenuItem(0)
    }

    @ViewBuilder
    private func MenuItemFor5Minutes() -> some View {
        makeMenuItem(5)
    }

    @ViewBuilder
    private func MenuItemFor10Minutes() -> some View {
        makeMenuItem(10)
    }

    @ViewBuilder
    private func MenuItemFor15Minutes() -> some View {
        makeMenuItem(15)
    }

    @ViewBuilder
    private func MenuItemFor30Minutes() -> some View {
        makeMenuItem(30)
    }

    @ViewBuilder
    private func MenuItemFor60Minutes() -> some View {
        makeMenuItem(60)
    }

    @ViewBuilder
    private func MenuItemFor1440Minutes() -> some View {
        makeMenuItem(1440)
    }

    private static func formatAlert(_ minutes: Int) -> String {
        if minutes == 0 {
            return "At time of event"
        } else if minutes < 60 {
            return minutes == 1 ? "1 minute before" : "\(minutes) minutes before"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour before" : "\(hours) hours before"
        } else {
            let days = minutes / 1440
            return days == 1 ? "1 day before" : "\(days) days before"
        }
    }
}

#Preview {
        let testEvent = UpcomingCalendarEvent(
            id: "123",
            title: "Knee Op",
            location: "London Bridge Hospital",
            meetingLink: nil,
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendarID: "work-calendar",
            calendarColor: UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1.0),
            calendarTitle: "Mark",
            hasRecurrence: false,
            recurrenceRule: nil,
            isAllDay: false
        )

    EventDetailView(event: testEvent)
}
