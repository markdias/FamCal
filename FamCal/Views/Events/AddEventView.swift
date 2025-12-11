//
//  AddEventView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import MapKit
import Combine
import EventKit

struct AddEventView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let initialDate: Date?

    private var defaultAlertOptionRawValue: String { appSettingsManager.defaultAlertOptionRawValue }

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
        entity: Driver.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Driver.name, ascending: true)]
    )
    private var drivers: FetchedResults<Driver>

    enum TimePicker {
        case none
        case startDate
        case endDate
        case startTime
        case endTime
    }

    // Family members who are marked as drivers
    private var driverFamilyMembers: [FamilyMember] {
        familyMembers.filter { $0.isDriver }
    }

    // Combined list of all available drivers (regular + family members)
    private var allAvailableDrivers: [DriverWrapper] {
        var combined: [DriverWrapper] = []

        // Add regular drivers
        for driver in drivers {
            combined.append(.regular(driver))
        }

        // Add family members who are marked as drivers
        for member in driverFamilyMembers {
            combined.append(.familyMember(member))
        }

        // Sort by name
        return combined.sorted { $0.name < $1.name }
    }

    // Event details
    @State private var eventTitle: String = ""
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var repeatOption: RepeatOption = .none
    @State private var recurrenceConfig = RecurrenceConfiguration.none(anchor: Date())
    @State private var showingCustomRepeatSheet = false
    @State private var alertOption: AlertOption = .none
    @State private var notes: String = ""
    @State private var meetingLink: String = ""
    @State private var locationName: String = ""
    @State private var locationAddress: String = ""
    @State private var isAllDay: Bool = false
    @State private var showAsOption: ShowAsOption = .busy
    @State private var eventDuration: TimeInterval = 3600 // Default 1 hour
    private let notificationManager = NotificationManager.shared

    // People selection
    @State private var selectedMembers: Set<NSManagedObjectID> = []
    @State private var selectEveryone = false
    @State private var selectedMemberCalendars: [NSManagedObjectID: String] = [:] // Track calendar per member

    // Driver selection
    @State private var selectedDriver: DriverWrapper?
    @State private var driverTravelTimeMinutes: Int = 15
    @State private var shouldCreateTravelEvent: Bool = false

    // Location search
    @State private var showingLocationSearch = false

    // Permissions
    @State private var calendarAccessGranted = false
    @State private var showingPermissionAlert = false
    @State private var permissionErrorMessage = ""

    // UI state
    @State private var activeTimePicker: TimePicker = .none
    @State private var showingRepeatPicker = false
    @State private var showingAlertPicker = false
    @State private var showingPeoplePicker = false
    @State private var isSaving = false
    @State private var showingSuccessMessage = false
    @State private var selectedCalendarID: String = ""
    @State private var availableCalendars: [CalendarOption] = []
    @State private var showingCalendarPicker = false
    @State private var showingCreateEventForDriverAlert = false
    @State private var driverToCreateEventFor: DriverWrapper?
    @State private var showingMissingAttendeesAlert = false

    init(initialDate: Date? = nil) {
        self.initialDate = initialDate

        if let date = initialDate {
            _eventDate = State(initialValue: date)
            _startTime = State(initialValue: date)
            // Set end time to 1 hour after start time
            _endTime = State(initialValue: date.addingTimeInterval(3600))
        }
    }

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    private var cardBackground: Color { theme.cardBackground }
    private var sectionBorder: Color { theme.cardStroke }
    private var fieldBackground: Color { theme.cardBackground }
    private var chipBackground: Color { theme.chromeOverlay }
    private var accentColor: Color { theme.accentColor }
    private var cardShadow: Color { Color.black.opacity(theme.prefersDarkInterface ? 0.35 : 0.05) }

    @ViewBuilder
    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(primaryTextColor)
    }

    private var hasSelectedCalendar: Bool {
        selectEveryone ? !selectedCalendarID.isEmpty : true
    }

    private var hasAttendees: Bool {
        selectEveryone || !selectedMembers.isEmpty
    }

    var isFormValid: Bool {
        let hasTitle = !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
        return hasTitle && hasSelectedCalendar
    }

    private var meetingLinkValue: String? {
        let trimmed = meetingLink.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    struct CalendarOption: Identifiable {
        let id = UUID()
        let calendarID: String
        let calendarName: String
        let color: UIColor
    }

    var attendeesSummary: String {
        if selectEveryone {
            return "Everyone"
        }
        if selectedMembers.isEmpty {
            return "None"
        }
        let selected = familyMembers.filter { selectedMembers.contains($0.objectID) }
        let names = selected.map { $0.name ?? "Unknown" }
        return names.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        whenCard
                        whoCard
                        notesCard
                        
                        // Spacer for bottom safe area
                        Spacer().frame(height: 40)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        if hasAttendees {
                            Task { await saveEvent() }
                        } else {
                            showingMissingAttendeesAlert = true
                        }
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                                .bold()
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .alert("Choose attendees", isPresented: $showingMissingAttendeesAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please choose at least one attendee before saving.")
            }
            .onAppear {
                // Request calendar permissions
                requestCalendarAccess()

                // Set default alert option
                if let defaultAlert = AlertOption(rawValue: defaultAlertOptionRawValue) {
                    alertOption = defaultAlert
                }

                // Initial Setup logic (preserved)
                if initialDate == nil {
                    let calendar = Calendar.current
                    let now = Date()
                    var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)

                    if let hour = components.hour, hour >= 23 {
                        components.hour = 23
                        components.minute = 0
                        startTime = calendar.date(from: components) ?? now
                        
                        if let nextDay = calendar.date(byAdding: .day, value: 1, to: startTime),
                           let nextDayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: nextDay) {
                            endTime = nextDayStart
                        } else {
                            endTime = startTime.addingTimeInterval(3600)
                        }
                    } else {
                        components.hour = (components.hour ?? 0) + 1
                        components.minute = 0
                        startTime = calendar.date(from: components) ?? now.addingTimeInterval(3600)

                        components.hour = (components.hour ?? 0) + 1
                        endTime = calendar.date(from: components) ?? startTime.addingTimeInterval(3600)
                    }

                    eventDate = now
                    recurrenceConfig = RecurrenceConfiguration.none(anchor: now)
                } else {
                    let calendar = Calendar.current
                    var components = calendar.dateComponents([.year, .month, .day, .hour], from: initialDate!)

                    if let hour = components.hour, hour >= 23 {
                        components.hour = 23
                        components.minute = 0
                        startTime = calendar.date(from: components) ?? initialDate!

                        if let nextDay = calendar.date(byAdding: .day, value: 1, to: startTime),
                           let nextDayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: nextDay) {
                            endTime = nextDayStart
                        } else {
                            endTime = startTime.addingTimeInterval(3600)
                        }
                    } else {
                        components.hour = (components.hour ?? 0) + 1
                        components.minute = 0
                        startTime = calendar.date(from: components) ?? initialDate!.addingTimeInterval(3600)

                        components.hour = (components.hour ?? 0) + 1
                        endTime = calendar.date(from: components) ?? startTime.addingTimeInterval(3600)
                    }

                    recurrenceConfig = RecurrenceConfiguration.none(anchor: initialDate!)
                }

                // Build available calendars list
                updateAvailableCalendars()

                // Clean up stale selected members
                let validMemberIDs = Set(familyMembers.map { $0.objectID })
                selectedMembers = selectedMembers.intersection(validMemberIDs)
            }
            .onChange(of: selectEveryone) { _, _ in
                updateAvailableCalendars()
            }
            .onChange(of: selectedMembers) { _, _ in
                updateAvailableCalendars()
            }
            .alert("Calendar Access Required", isPresented: $showingPermissionAlert) {
                Button("OK") { }
            } message: {
                Text(permissionErrorMessage)
            }
            .alert("Event Created", isPresented: $showingSuccessMessage) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your event has been added successfully!")
            }
            .alert("Create Event for Driver?", isPresented: $showingCreateEventForDriverAlert) {
                Button("Yes") {
                    shouldCreateTravelEvent = true
                    driverToCreateEventFor = nil
                }
                Button("No") {
                    shouldCreateTravelEvent = false
                    driverToCreateEventFor = nil
                }
            } message: {
                if let driver = driverToCreateEventFor {
                    Text("Would you like to create a separate event for \(driver.name)'s drive?")
                }
            }
            .tint(accentColor)
        }
    }

    private func updateAvailableCalendars() {
        availableCalendars = []
        var calendarSet = Set<String>() // To avoid duplicates

        if selectEveryone {
            // Show shared calendars for "Everyone"
            for calendar in sharedCalendars {
                if let calendarID = calendar.calendarID, !calendarSet.contains(calendarID) {
                    calendarSet.insert(calendarID)
                    let color = UIColor(displayP3Red: CGFloat.random(in: 0...1),
                                       green: CGFloat.random(in: 0...1),
                                       blue: CGFloat.random(in: 0...1),
                                       alpha: 1)
                    if let colorHex = calendar.calendarColorHex {
                        let parseColor = UIColor(named: colorHex) ?? UIColor(displayP3Red: 0.5, green: 0.5, blue: 1, alpha: 1)
                        availableCalendars.append(CalendarOption(
                            calendarID: calendarID,
                            calendarName: calendar.calendarName ?? "Shared Calendar",
                            color: parseColor
                        ))
                    } else {
                        availableCalendars.append(CalendarOption(
                            calendarID: calendarID,
                            calendarName: calendar.calendarName ?? "Shared Calendar",
                            color: color
                        ))
                    }
                }
            }
        } else {
            // Show selected members' calendars
            for memberID in selectedMembers {
                if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                    if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
                        for memberCal in memberCalendars {
                            if let calendarID = memberCal.calendarID, !calendarSet.contains(calendarID) {
                                calendarSet.insert(calendarID)
                                let color = UIColor(named: memberCal.calendarColorHex ?? "#555555") ?? UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1.0)
                                availableCalendars.append(CalendarOption(
                                    calendarID: calendarID,
                                    calendarName: memberCal.calendarName ?? (member.name ?? "Unknown"),
                                    color: color
                                ))
                            }
                        }
                    }
                }
            }
        }

        // Set default selection if not already set
        if selectedCalendarID.isEmpty && !availableCalendars.isEmpty {
            selectedCalendarID = availableCalendars.first?.calendarID ?? ""
        }
    }

    private func requestCalendarAccess() {
        let eventStore = EKEventStore()

        if #available(iOS 17, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    calendarAccessGranted = granted
                    if !granted {
                        permissionErrorMessage = "Calendar access is required to create events. Please enable it in Settings."
                        showingPermissionAlert = true
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    calendarAccessGranted = granted
                    if !granted {
                        permissionErrorMessage = "Calendar access is required to create events. Please enable it in Settings."
                        showingPermissionAlert = true
                    }
                }
            }
        }
    }

    private func createTravelEvent(
        for familyMember: FamilyMember,
        eventName: String,
        eventStartTime: Date,
        travelTimeMinutes: Int
    ) -> String? {
        // Get the family member's linked personal calendar
        guard let memberCalendars = familyMember.memberCalendars as? Set<FamilyMemberCalendar>,
              let personalCalendar = memberCalendars.first(where: { $0.isAutoLinked }),
              let calendarID = personalCalendar.calendarID else {
            print("❌ Travel Event: Could not find linked calendar for family member \(familyMember.name ?? "Unknown")")
            return nil
        }

        // Calculate travel event timing
        let travelEventStartTime = eventStartTime.addingTimeInterval(-Double(travelTimeMinutes) * 60)
        let travelEventEndTime = eventStartTime // Travel event ends when main event starts

        let travelEventTitle = "Travel to \(eventName)"

        // Create the travel event
        let travelEventId = CalendarManager.shared.createEvent(
            title: travelEventTitle,
            startDate: travelEventStartTime,
            endDate: travelEventEndTime,
            location: nil,
            notes: "Travel time to \(eventName)",
            in: calendarID
        )

        if let eventId = travelEventId {
            print("✈️ Travel event created: '\(travelEventTitle)' on \(personalCalendar.calendarName ?? "Personal Calendar"), duration: \(travelTimeMinutes) min, event ID: \(eventId)")
        } else {
            print("❌ Failed to create travel event for family member \(familyMember.name ?? "Unknown")")
        }

        return travelEventId
    }

    private func saveEvent() async {
        // Check permissions first
        guard calendarAccessGranted else {
            permissionErrorMessage = "Please enable calendar access in Settings to create events."
            showingPermissionAlert = true
            return
        }

        await MainActor.run {
            isSaving = true
        }

        guard hasAttendees else {
            await MainActor.run {
                isSaving = false
                showingMissingAttendeesAlert = true
            }
            return
        }

        let eventGroupId = UUID()
        let title = eventTitle.trimmingCharacters(in: .whitespaces)

        // Use startTime and endTime directly as they now contain the correct date and time
        let eventStartDate = startTime
        let eventEndDate = endTime

        // Create recurrence rule if needed
        // Note: We generate this inside the loop now to ensure a fresh instance for each event
        // let recurrenceRule: EKRecurrenceRule? = selectedRecurrenceRule(startDate: eventStartDate)

        var createdEventIds: [String] = []

        print("🚗 DEBUG: About to save event. selectedDriver = \(selectedDriver?.name ?? "nil")")

        // Determine which calendars to add the event to, and which members are tied to each calendar
        var targets: [(calendarID: String, member: FamilyMember?)] = []

        if selectEveryone {
            // Everyone selected: use the shared family calendar
            targets = [(selectedCalendarID, nil)]
        } else {
            // Specific people selected: add to each person's selected calendar so it can be edited/updated across them
            for memberID in selectedMembers {
                if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                    if let selected = getSelectedCalendarForMemberCombined(member: member) {
                        let calendarID = selected.id
                        targets.append((calendarID, member))
                    }
                }
            }
        }

        // Collect all attendees for consolidated notification
        var allAttendees: [FamilyMember] = []
        if selectEveryone {
            allAttendees = Array(familyMembers)
        } else {
            for memberID in selectedMembers {
                if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                    allAttendees.append(member)
                }
            }
        }

        // Create event in all target calendars
        var firstEventId: String? = nil
        
        // Construct location string with name if available
        let locationValue: String?
        if locationAddress.isEmpty {
            locationValue = nil
        } else if !locationName.isEmpty && locationName != locationAddress {
            // Avoid duplication if name is part of address or identical
            if locationAddress.contains(locationName) {
                locationValue = locationAddress
            } else {
                locationValue = "\(locationName), \(locationAddress)"
            }
        } else {
            locationValue = locationAddress
        }
        
        let notesValue = notes.isEmpty ? nil : notes
        for target in targets {
            var eventId: String?
            
            // Generate a fresh recurrence rule for THIS specific event instance
            // EKRecurrenceRule is a reference type and can be "claimed" by the first event it's added to
            let recurrenceRule = selectedRecurrenceRule(startDate: eventStartDate)

            if let recurrenceRule = recurrenceRule {
                eventId = CalendarManager.shared.createRecurringEvent(
                    title: title,
                    startDate: eventStartDate,
                    endDate: eventEndDate,
                    location: locationValue,
                    notes: notesValue,
                    meetingLink: meetingLinkValue,
                    recurrenceRule: recurrenceRule,
                    isAllDay: isAllDay,
                    in: target.calendarID,
                    alertOption: alertOption
                )
            } else {
                eventId = CalendarManager.shared.createEvent(
                    title: title,
                    startDate: eventStartDate,
                    endDate: eventEndDate,
                    location: locationValue,
                    notes: notesValue,
                    meetingLink: meetingLinkValue,
                    isAllDay: isAllDay,
                    in: target.calendarID,
                    alertOption: alertOption
                )
            }

            print("📅 Created event with ID: \(eventId ?? "nil") in calendar: \(target.calendarID)")

            if let eventId = eventId {
                // Store first event ID for notification scheduling
                var finalEventId: String? = eventId

                // Ensure recurrence is applied in every target calendar (may recreate with a new ID)
                if let recurrenceRule = recurrenceRule {
                finalEventId = enforceRecurringSeries(
                    eventId: eventId,
                    calendarId: target.calendarID,
                    title: title,
                    startDate: eventStartDate,
                    endDate: eventEndDate,
                    location: locationValue,
                    notes: notesValue,
                    meetingLink: meetingLinkValue,
                    isAllDay: isAllDay,
                        recurrenceRule: recurrenceRule,
                        alertOption: alertOption
                    )
                }

                if firstEventId == nil, let resolvedId = finalEventId {
                    firstEventId = resolvedId
                }

                if let resolvedId = finalEventId {
                    createdEventIds.append(resolvedId)
                }

                // Store in CoreData
                let familyEvent = FamilyEvent(context: viewContext)
                familyEvent.id = eventGroupId
                familyEvent.eventGroupId = eventGroupId
                familyEvent.eventIdentifier = finalEventId ?? eventId
                familyEvent.calendarId = target.calendarID
                familyEvent.createdAt = Date()
                familyEvent.isSharedCalendarEvent = selectEveryone

                // Add driver information
                if let driverWrapper = selectedDriver {
                    switch driverWrapper {
                    case .regular(let driver):
                        familyEvent.driver = driver
                        print("🚗 Added regular driver: \(driver.name ?? "Unknown")")

                    case .familyMember(let member):
                        // Store family member ID as driver (don't create Driver entity)
                        familyEvent.driverFamilyMemberId = member.id
                        print("🚗 Set family member as driver: \(member.name ?? "Unknown")")

                        // Create travel event only if user confirmed
                        if shouldCreateTravelEvent {
                            _ = createTravelEvent(
                                for: member,
                                eventName: title,
                                eventStartTime: eventStartDate,
                                travelTimeMinutes: driverTravelTimeMinutes
                            )

                            print("🚗 Created travel event for family member driver: \(member.name ?? "Unknown"), travel time: \(driverTravelTimeMinutes) min")
                        } else {
                            print("🚗 Skipped travel event creation for family member driver: \(member.name ?? "Unknown")")
                        }
                    }
                }

                print("📝 Saving FamilyEvent: eventIdentifier=\(eventId), driver=\(familyEvent.driver?.name ?? "None")")
                print("   Driver object ID: \(familyEvent.driver?.objectID.debugDescription ?? "nil")")
                print("   Driver is in context: \(familyEvent.driver?.managedObjectContext != nil)")
                print("   FamilyEvent will have driver: \(familyEvent.driver != nil)")

                // Add attendees for non-shared events
                var addedAttendeeIds = Set<UUID>()

                if !selectEveryone {
                    for memberID in selectedMembers {
                        if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                            familyEvent.addToAttendees(member)
                            addedAttendeeIds.insert(member.id ?? UUID())
                        }
                    }
                } else {
                    // If "Everyone" selected, add all family members
                    for member in familyMembers {
                        familyEvent.addToAttendees(member)
                        addedAttendeeIds.insert(member.id ?? UUID())
                    }
                }

                // If driver is a family member and not already in attendees, add them
                if let driverWrapper = selectedDriver, case .familyMember(let driverMember) = driverWrapper {
                    if let driverId = driverMember.id, !addedAttendeeIds.contains(driverId) {
                        familyEvent.addToAttendees(driverMember)
                        print("✅ Added family member driver \(driverMember.name ?? "Unknown") to attendees")
                    }
                }

                print("✅ FamilyEvent saved for eventId: \(eventId)")
            }
        }

        // Schedule ONE consolidated notification for all attendees
        if let eventId = firstEventId {
            // Deduplicate attendees by ID to prevent duplicates
            var uniqueAttendees: [FamilyMember] = []
            var seenIds = Set<UUID>()
            for attendee in allAttendees {
                if let attendeeId = attendee.id {
                    if !seenIds.contains(attendeeId) {
                        uniqueAttendees.append(attendee)
                        seenIds.insert(attendeeId)
                    }
                } else {
                    uniqueAttendees.append(attendee)
                }
            }

            print("🔔 Scheduling ONE consolidated notification for event: \(eventId)")
            print("📋 Attendees: \(uniqueAttendees.map { $0.name ?? "Unknown" }.joined(separator: ", "))")
            print("📍 Location: \(locationAddress.isEmpty ? "None" : locationAddress)")
            scheduleNotificationForCreatedEvent(
                eventIdentifier: eventId,
                startDate: eventStartDate,
                alertOption: alertOption,
                attendingMembers: uniqueAttendees,
                location: locationAddress.isEmpty ? nil : locationAddress
            )
        } else {
            print("❌ ERROR: No firstEventId was set! Created \(createdEventIds.count) events but couldn't schedule notification")
        }

        // Save CoreData changes and show success
        do {
            try viewContext.save()
            print("✅ CoreData saved successfully. Created \(createdEventIds.count) event(s)")

            // Verify the save by fetching back immediately
            let fetchRequest = FamilyEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventIdentifier IN %@", createdEventIds)
            let saved = try viewContext.fetch(fetchRequest)
            print("📋 Verified: \(saved.count) FamilyEvent(s) saved to database")
            for event in saved {
                print("   - Event: \(event.eventIdentifier ?? "unknown"), Driver: \(event.driver?.name ?? "nil")")
            }


            // Trigger haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

            // Show success message and auto-dismiss
            await MainActor.run {
                showingSuccessMessage = true
                shouldCreateTravelEvent = false
            }

            // Wait a bit before showing the alert, then auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("Failed to save event: \(error.localizedDescription)")
            await MainActor.run {
                isSaving = false
            }
        }
    }

    private func currentRecurrenceConfiguration(anchorDate: Date) -> RecurrenceConfiguration? {
        if repeatOption == .custom {
            return recurrenceConfig.isEnabled ? recurrenceConfig : nil
        }

        if let quickConfig = RecurrenceConfiguration.quick(option: repeatOption, anchor: anchorDate), quickConfig.isEnabled {
            return quickConfig
        }

        return nil
    }

    private func recurrenceSummaryText(anchorDate: Date) -> String {
        guard let config = currentRecurrenceConfiguration(anchorDate: anchorDate) else {
            return "Does not repeat"
        }
        return config.summary(anchor: anchorDate)
    }

    private func selectedRecurrenceRule(startDate: Date) -> EKRecurrenceRule? {
        currentRecurrenceConfiguration(anchorDate: startDate)?.toRecurrenceRule(anchor: startDate)
    }

    private func scheduleNotificationForCreatedEvent(
        eventIdentifier: String,
        startDate: Date,
        alertOption: AlertOption,
        attendingMembers: [FamilyMember],
        location: String? = nil
    ) {
        // Clear any stale pending notifications for this identifier
        Task {
            await notificationManager.cancelEventNotifications(for: eventIdentifier)

            guard alertOption != .none else { return }

            let memberIds = attendingMembers.compactMap { $0.id }

            // Get first member's calendar to check notification settings
            let firstCalendarId: String? = {
                if selectEveryone, let sharedCal = sharedCalendars.first {
                    return sharedCal.calendarID
                } else if let member = attendingMembers.first,
                          let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar>,
                          let firstCal = memberCals.first {
                    return firstCal.calendarID
                }
                return nil
            }()

            guard let calendarId = firstCalendarId else { return }

            guard notificationManager.shouldNotifyForEvent(
                calendarId: calendarId,
                memberIds: memberIds
            ) else { return }

            // Try to get the event, but if it's not immediately available (common after creation),
            // use a dummy EKEvent with the provided details instead
            let ekEvent: EKEvent?
            if let found = CalendarManager.shared.getEvent(withIdentifier: eventIdentifier) {
                ekEvent = found
            } else {
                // Create a temporary EKEvent with the details we have
                // This avoids notification failures due to EventKit cache lag
                let tempEvent = EKEvent(eventStore: EKEventStore())
                tempEvent.title = eventTitle
                tempEvent.startDate = startDate
                tempEvent.endDate = endTime
                tempEvent.location = location
                tempEvent.notes = notes.isEmpty ? nil : notes
                if let url = MeetingLinkHelper.normalizedURL(from: meetingLink) {
                    tempEvent.url = url
                }
                tempEvent.isAllDay = isAllDay
                ekEvent = tempEvent
            }

            guard let ekEvent = ekEvent else { return }

            let memberNames = attendingMembers.compactMap { $0.name }
            let driverName: String? = {
                switch selectedDriver {
                case .regular(let driver):
                    return driver.name
                case .familyMember(let member):
                    return member.name
                case .none:
                    return nil
                }
            }()

            notificationManager.scheduleEventNotification(
                event: ekEvent,
                alertOption: alertOption,
                familyMembers: memberNames,
                drivers: driverName,
                location: location,
                isSharedCalendarEvent: selectEveryone
            )
        }
    }

    private var repeatDetailLabel: String {
        switch repeatOption {
        case .custom: return "Custom pattern"
        case .none: return "Off"
        default: return "Quick repeat"
        }
    }

    private func handleRepeatSelection(_ option: RepeatOption) {
        switch option {
        case .custom:
            if let existing = currentRecurrenceConfiguration(anchorDate: eventDate) {
                recurrenceConfig = existing
            } else if !recurrenceConfig.isEnabled {
                recurrenceConfig = RecurrenceConfiguration.quick(option: .weekly, anchor: eventDate) ?? recurrenceConfig
            }
            repeatOption = .custom
            showingCustomRepeatSheet = true
        default:
            repeatOption = option
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        return calendar.date(from: combinedComponents) ?? date
    }
    
    private var calendarWithMondayAsFirstDay: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar
    }



    // MARK: - Section Builders

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(sectionBorder, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Title")

            HStack(spacing: 10) {
                TextField("Event Title", text: $eventTitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(primaryTextColor)

                Button(action: {}) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.93, green: 0.44, blue: 0.8),
                                Color(red: 0.99, green: 0.62, blue: 0.31),
                                Color(red: 0.73, green: 0.38, blue: 0.99)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: cardShadow, radius: 12, y: 6)
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("Location")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)

                    Button(action: { showingLocationSearch = true }) {
                        HStack {
                            if locationName.isEmpty {
                                Text("Add Location")
                                    .foregroundColor(secondaryTextColor)
                            } else {
                                Text(locationName)
                                    .foregroundColor(primaryTextColor)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(secondaryTextColor)
                        }
                        .padding(10)
                        .background(fieldBackground)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    if !locationName.isEmpty {
                        Button(action: {
                            locationName = ""
                            locationAddress = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(secondaryTextColor)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !locationAddress.isEmpty && locationAddress != locationName {
                    Text(locationAddress)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                        .padding(.leading, 80) // Align with text field start roughly
                }
            }
        }
        .sheet(isPresented: $showingLocationSearch) {
            LocationSearchView(locationName: $locationName, locationAddress: $locationAddress)
                .environment(\.managedObjectContext, viewContext)
        }
    }



    // MARK: - Section Builders

    @ViewBuilder
    private var headerCard: some View {
        VStack(spacing: 0) {
            // Title
            QuickRow(icon: "text.alignleft", title: "Title", showChevron: false, color: .purple) {
                TextField("Event Title", text: $eventTitle)
                    .font(.system(size: 17))
            }
            
            Divider().padding(.leading, 44)
            
            // Location
            QuickRow(icon: "mappin.circle.fill", title: "Location", showChevron: false, color: .red) {
                Button(action: { showingLocationSearch = true }) {
                    if locationName.isEmpty {
                        Text("Add Location")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text(locationName)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchView(locationName: $locationName, locationAddress: $locationAddress)
                    .environment(\.managedObjectContext, viewContext)
            }
            
            Divider().padding(.leading, 44)
            
            // Link
            QuickRow(icon: "link", title: "Video Call", showChevron: false, color: .blue) {
                TextField("Add URL", text: $meetingLink)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
            }
        }
        .background(Color(uiColor: .systemBackground)) // White/Dark card
        .cornerRadius(12)
    }

    @ViewBuilder
    private var whenCard: some View {
        VStack(spacing: 0) {
            // All-day
            QuickRow(icon: "clock", title: "All-day", showChevron: false, color: .blue) {
                Button(action: { isAllDay.toggle() }) {
                    Text(isAllDay ? "Yes" : "No")
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Starts
            VStack(spacing: 0) {
                QuickRow(icon: "", title: "Starts", showChevron: false) {
                    Button(action: {
                        withAnimation {
                            if activeTimePicker == .startDate || activeTimePicker == .startTime {
                                activeTimePicker = .none
                            } else {
                                activeTimePicker = isAllDay ? .startDate : .startTime
                            }
                        }
                    }) {
                        HStack {
                            Text(startTime.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(activeTimePicker == .startDate ? .blue : .primary)
                                .padding(6)
                                .background(activeTimePicker == .startDate ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            
                            if !isAllDay {
                                Text(startTime.formatted(date: .omitted, time: .shortened))
                                    .foregroundColor(activeTimePicker == .startTime ? .blue : .primary)
                                    .padding(6)
                                    .background(activeTimePicker == .startTime ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if activeTimePicker == .startDate {
                    DatePicker("", selection: $startTime, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                }
                
                if activeTimePicker == .startTime && !isAllDay {
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Ends
            VStack(spacing: 0) {
                QuickRow(icon: "", title: "Ends", showChevron: false) {
                    Button(action: {
                        withAnimation {
                            if activeTimePicker == .endDate || activeTimePicker == .endTime {
                                activeTimePicker = .none
                            } else {
                                activeTimePicker = isAllDay ? .endDate : .endTime
                            }
                        }
                    }) {
                        HStack {
                            Text(endTime.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(activeTimePicker == .endDate ? .blue : .primary)
                                .padding(6)
                                .background(activeTimePicker == .endDate ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            
                            if !isAllDay {
                                Text(endTime.formatted(date: .omitted, time: .shortened))
                                    .foregroundColor(activeTimePicker == .endTime ? .blue : .primary)
                                    .padding(6)
                                    .background(activeTimePicker == .endTime ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if activeTimePicker == .endDate {
                    DatePicker("", selection: $endTime, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                }
                
                if activeTimePicker == .endTime && !isAllDay {
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Repeat
            QuickRow(icon: "repeat", title: "Repeat", color: .gray) {
                Menu {
                    ForEach(RepeatOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            handleRepeatSelection(option)
                        }
                    }
                } label: {
                    Text(repeatOption == .custom ? (recurrenceConfig.isEnabled ? recurrenceConfig.summary(anchor: eventDate) : "Custom") : repeatOption.rawValue)
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showingCustomRepeatSheet) {
                CustomRepeatView(
                    recurrence: $recurrenceConfig,
                    anchorDate: eventDate
                ) { updated in
                    repeatOption = updated.isEnabled ? .custom : .none
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var whoCard: some View {
        VStack(spacing: 0) {
            // Invitees
            QuickRow(icon: "person.2.fill", title: "Invitees", color: .indigo) {
                HStack(spacing: 4) {
                     Text(attendeesSummary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { showingPeoplePicker.toggle() }
                }
            }
            
            if showingPeoplePicker {
                Divider().padding(.leading, 44)
                
                VStack(spacing: 0) {
                     // Everyone toggle
                    QuickRow(icon: "person.3.fill", title: "Everyone", showChevron: false, color: .blue) {
                        Button(action: { selectEveryone.toggle() }) {
                            Text(selectEveryone ? "Yes" : "No")
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    
                    if !selectEveryone {
                        Divider().padding(.leading, 44)
                        
                        ForEach(familyMembers, id: \.objectID) { member in
                            QuickRow(icon: "person.fill", title: member.name ?? "Unknown", showChevron: false, color: .gray) {
                                Button(action: {
                                    if selectedMembers.contains(member.objectID) {
                                        selectedMembers.remove(member.objectID)
                                    } else {
                                        selectedMembers.insert(member.objectID)
                                    }
                                }) {
                                    Image(systemName: selectedMembers.contains(member.objectID) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedMembers.contains(member.objectID) ? .blue : .secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                            // Add divider if not last
                            if member.objectID != familyMembers.last?.objectID {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Calendar(s)
            if selectEveryone {
                // Single shared calendar selection
                QuickRow(icon: "calendar", title: "Calendar", color: .red) {
                    Menu {
                        ForEach(availableCalendars) { cal in
                            Button(action: { selectedCalendarID = cal.calendarID }) {
                                HStack {
                                    if selectedCalendarID == cal.calendarID { Image(systemName: "checkmark") }
                                    Circle().fill(Color(uiColor: cal.color)).frame(width: 8, height: 8)
                                    Text(cal.calendarName)
                                }
                            }
                        }
                    } label: {
                        if let current = availableCalendars.first(where: { $0.calendarID == selectedCalendarID }) {
                            Text(current.calendarName).foregroundColor(.primary)
                        } else {
                            Text("Select").foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // Per-member calendar selection
                // We'll show this as a subgroup if members are selected, or always?
                // If members are selected, we show a row for each member's calendar preference
                if !selectedMembers.isEmpty {
                   ForEach(selectedMembers.sorted { id1, id2 in
                       let m1 = familyMembers.first(where: { $0.objectID == id1 })?.name ?? ""
                       let m2 = familyMembers.first(where: { $0.objectID == id2 })?.name ?? ""
                       return m1 < m2
                   }, id: \.self) { memberID in
                       if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                           // Check if member has multiple calendars
                           let allCalendars = buildCombinedCalendarList(
                               memberCalendars: (member.memberCalendars as? Set<FamilyMemberCalendar>) ?? Set(),
                               personalCalendars: (member.personalCalendars as? Set<PersonalCalendar>) ?? Set()
                           )
                           let writableCount = allCalendars.filter { item in
                               if let calendarID = (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID {
                                   if let ekCalendar = CalendarManager.shared.getCalendar(withIdentifier: calendarID) {
                                       return ekCalendar.allowsContentModifications
                                   }
                               }
                               return true
                           }.count
                           
                           // Only show if member has more than one calendar
                           if writableCount > 1 {
                               QuickRow(icon: "calendar", title: "\(member.name ?? "")'s Cal", color: .red) {
                                   memberCalendarMenu(for: member)
                               }
                               Divider().padding(.leading, 44)
                           }
                       }
                   }
                } else {
                    QuickRow(icon: "calendar", title: "Calendar", color: .red) {
                        Text("Select invitees first").foregroundColor(.secondary)
                    }
                    Divider().padding(.leading, 44)
                }
            }

            // Driver
            QuickRow(icon: "car.fill", title: "Driver", color: .green) {
                Menu {
                    Button("None") { selectedDriver = nil }
                    Divider()
                    ForEach(allAvailableDrivers, id: \.id) { driver in
                        Button(action: {
                            selectedDriver = driver
                            if case .familyMember(_) = driver {
                                driverToCreateEventFor = driver
                                showingCreateEventForDriverAlert = true
                            }
                        }) {
                            HStack {
                                if selectedDriver?.id == driver.id { Image(systemName: "checkmark") }
                                Text(driver.name)
                            }
                        }
                    }
                } label: {
                    Text(selectedDriver?.name ?? "None").foregroundColor(.primary)
                }
            }
            
            // Travel Time (Conditional)
            if let driver = selectedDriver, driver.isFamilyMember {
                Divider().padding(.leading, 44)
                
                QuickRow(icon: "timer", title: "Travel Time", color: .orange) {
                    Menu {
                        ForEach([5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { minutes in
                            Button("\(minutes) min") { driverTravelTimeMinutes = minutes }
                        }
                    } label: {
                        Text("\(driverTravelTimeMinutes) min").foregroundColor(.primary)
                    }
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Alert
            QuickRow(icon: "bell.fill", title: "Alert", color: .red) {
                Menu {
                    ForEach(AlertOption.allCases, id: \.self) { option in
                         Button(option.rawValue) { alertOption = option }
                    }
                } label: {
                    Text(alertOption.rawValue).foregroundColor(.primary)
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Show As
            QuickRow(icon: "circle.square", title: "Show As", color: .gray) {
                Menu {
                    ForEach(ShowAsOption.allCases, id: \.self) { option in
                        Button(option.rawValue) { showAsOption = option }
                    }
                } label: {
                     Text(showAsOption.rawValue).foregroundColor(.primary)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .scrollContentBackground(.hidden) 
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }
    
    // Helper for per-member calendar menu
    @ViewBuilder
    private func memberCalendarMenu(for member: FamilyMember) -> some View {
        let allCalendars = buildCombinedCalendarList(
            memberCalendars: (member.memberCalendars as? Set<FamilyMemberCalendar>) ?? Set(),
            personalCalendars: (member.personalCalendars as? Set<PersonalCalendar>) ?? Set()
        )
        
        let writable = allCalendars.filter { item in
             if let calendarID = (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID {
                 if let ekCalendar = CalendarManager.shared.getCalendar(withIdentifier: calendarID) {
                     return ekCalendar.allowsContentModifications
                 }
             }
             return true
        }

        Menu {
            ForEach(writable.indices, id: \.self) { index in
                let item = writable[index]
                Button(action: {
                    updateSelectedCalendarForMemberCombined(member: member, calendarID: (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID, type: item.type)
                }) {
                     HStack {
                         if isCalendarSelectedForMemberCombined(member: member, calendarID: (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID, type: item.type) {
                             Image(systemName: "checkmark")
                         }
                         Circle().fill(Color.fromHex(item.colorHex))
                         Text(item.name)
                     }
                }
            }
        } label: {
             if let (selectedID, _) = getSelectedCalendarForMemberCombined(member: member) {
                  // Find name
                 let name: String = {
                     if let m = (member.memberCalendars as? Set<FamilyMemberCalendar>)?.first(where: { $0.calendarID == selectedID }) { return m.calendarName ?? "" }
                     if let p = (member.personalCalendars as? Set<PersonalCalendar>)?.first(where: { $0.calendarID == selectedID }) { return p.calendarName ?? "" }
                     return "Unknown"
                 }()
                 Text(name).foregroundColor(.primary)
             } else {
                 Text("Select").foregroundColor(.secondary)
             }
        }
    }

    private func createEventForDriver(_ driver: DriverWrapper) {
        // Create a new event for the driver in the first available shared calendar
        // Note: startTime and endTime already contain the full date and time
        let driverEventTitle = "\(eventTitle) - \(driver.name)'s drive"

        if let firstCalendar = availableCalendars.first {
            let eventId = CalendarManager.shared.createEvent(
                title: driverEventTitle,
                startDate: startTime,
                endDate: endTime,
                location: locationAddress.isEmpty ? nil : locationAddress,
                notes: notes.isEmpty ? nil : notes,
                isAllDay: isAllDay,
                in: firstCalendar.calendarID,
                alertOption: alertOption
            )

            if let eventId = eventId {
                print("✅ Created event for \(driver.name): \(eventId)")
            } else {
                print("❌ Failed to create event for driver")
            }
        } else {
            print("❌ No available calendars to create driver event")
        }
    }

    /// Some calendar providers drop recurrence on creation; reapply if needed so every target calendar gets the full series.
    private func enforceRecurringSeries(
        eventId: String,
        calendarId: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        notes: String?,
        meetingLink: String?,
        isAllDay: Bool,
        recurrenceRule: EKRecurrenceRule,
        alertOption: AlertOption?
    ) -> String {
        let createdEvent = CalendarManager.shared.fetchEventDetails(
            withIdentifier: eventId,
            occurrenceStartDate: startDate
        ) ?? CalendarManager.shared.getEvent(withIdentifier: eventId)

        if let createdEvent,
           let rules = createdEvent.recurrenceRules,
           !rules.isEmpty {
            print("✅ Recurrence already present for event \(eventId) in calendar \(calendarId)")
            return eventId
        }

        print("♻️ Recurrence missing for event \(eventId) in calendar \(calendarId); reapplying rule")
        let updated = CalendarManager.shared.enforceRecurrence(
            for: eventId,
            occurrenceStartDate: nil, // allow EventKit to resolve the master event
            in: calendarId,
            recurrenceRule: recurrenceRule
        )

        if updated {
            print("✅ Successfully re-applied recurrence for event \(eventId) in calendar \(calendarId)")
            return eventId
        }

        print("❌ Failed to re-apply recurrence for event \(eventId) in calendar \(calendarId). Attempting recreate.")

        // As a last resort, delete the non-recurring instance and recreate a recurring event
        _ = CalendarManager.shared.deleteEvent(
            withIdentifier: eventId,
            occurrenceStartDate: startDate,
            from: calendarId,
            span: .thisEvent
        )

        if let newId = CalendarManager.shared.createRecurringEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            meetingLink: meetingLink,
            recurrenceRule: recurrenceRule,
            isAllDay: isAllDay,
            in: calendarId,
            alertOption: alertOption
        ) {
            print("✅ Recreated recurring event with ID \(newId) in calendar \(calendarId)")
            return newId
        }

        print("❌ Failed to recreate recurring event in calendar \(calendarId). Keeping original ID \(eventId)")
        return eventId
    }

    // MARK: - Calendar Selection Helpers

    private func buildCombinedCalendarList(memberCalendars: Set<FamilyMemberCalendar>, personalCalendars: Set<PersonalCalendar>) -> [(calendar: Any, type: String, name: String, colorHex: String, isAutoLinked: Bool)] {
        var allCalendars: [(calendar: Any, type: String, name: String, colorHex: String, isAutoLinked: Bool)] = []

        // Add member calendars
        for cal in memberCalendars {
            allCalendars.append((
                calendar: cal,
                type: "member",
                name: cal.calendarName ?? "Unknown",
                colorHex: cal.calendarColorHex ?? "#555555",
                isAutoLinked: cal.isAutoLinked
            ))
        }

        // Add personal calendars
        for cal in personalCalendars {
            allCalendars.append((
                calendar: cal,
                type: "personal",
                name: cal.calendarName ?? "Unknown",
                colorHex: cal.calendarColorHex ?? "#555555",
                isAutoLinked: false
            ))
        }

        return allCalendars
    }

    private func updateSelectedCalendarForMemberCombined(member: FamilyMember, calendarID: String?, type: String) {
        if let calendarID = calendarID {
            selectedMemberCalendars[member.objectID] = calendarID
            // For now, if editing a single user's calendar choice, we rely on the map.
        }
    }

    private func getSelectedCalendarForMemberCombined(member: FamilyMember) -> (id: String, color: String)? {
        if let selectedCalID = selectedMemberCalendars[member.objectID] {
            // Check if it's a member calendar
            if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar>,
               let selected = memberCalendars.first(where: { $0.calendarID == selectedCalID }) {
                return (id: selectedCalID, color: selected.calendarColorHex ?? "#555555")
            }
            // Check if it's a personal calendar
            if let personalCalendars = member.personalCalendars as? Set<PersonalCalendar>,
               let selected = personalCalendars.first(where: { $0.calendarID == selectedCalID }) {
                return (id: selectedCalID, color: selected.calendarColorHex ?? "#555555")
            }
            // Fallback if ID exists but object not found easily (data inconsistency?)
            return (id: selectedCalID, color: "#555555")
        }

        // Default to first auto-linked member calendar or first avail
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
            if let autoLinked = memberCalendars.first(where: { $0.isAutoLinked }) {
                return (id: autoLinked.calendarID ?? "", color: autoLinked.calendarColorHex ?? "#555555")
            }
        }
        return nil
    }

    private func isCalendarSelectedForMemberCombined(member: FamilyMember, calendarID: String?, type: String) -> Bool {
        guard let calendarID = calendarID else { return false }

        if let (selectedID, _) = getSelectedCalendarForMemberCombined(member: member) {
            return selectedID == calendarID
        }
        return false
    }
}




#Preview {
    AddEventView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
