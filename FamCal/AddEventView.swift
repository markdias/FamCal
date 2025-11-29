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
    @State private var locationName: String = ""
    @State private var locationAddress: String = ""
    @State private var isAllDay: Bool = false
    @State private var showAsOption: ShowAsOption = .busy
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

    var isFormValid: Bool {
        let hasTitle = !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
        let hasAttendees = (!selectEveryone && !selectedMembers.isEmpty) || selectEveryone
        let hasCalendar = selectEveryone ? !selectedCalendarID.isEmpty : true

        return hasTitle && hasAttendees && hasCalendar
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
                theme.backgroundLayer()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        titleSection
                        locationSection
                        timeSection
                        attendeesSection
                        calendarSection
                        driverSection
                        repeatSection
                        alertSection
                        notesSection
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(16)
                }
                .background(Color.clear)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await saveEvent() }
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                // Request calendar permissions
                requestCalendarAccess()

                // Set default alert option
                if let defaultAlert = AlertOption(rawValue: defaultAlertOptionRawValue) {
                    alertOption = defaultAlert
                }

                // Set default start and end times
                let calendar = Calendar.current
                let now = Date()
                var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
                
                if let hour = components.hour, hour >= 23 {
                    // 11th hour logic: Start at 23:00, End at 00:00 next day
                    components.hour = 23
                    components.minute = 0
                    startTime = calendar.date(from: components) ?? now
                    
                    // End time is next day at 00:00
                    if let nextDay = calendar.date(byAdding: .day, value: 1, to: startTime),
                       let nextDayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: nextDay) {
                        endTime = nextDayStart
                    } else {
                        endTime = startTime.addingTimeInterval(3600)
                    }
                } else {
                    // Standard logic
                    components.hour = (components.hour ?? 0) + 1
                    components.minute = 0
                    startTime = calendar.date(from: components) ?? now.addingTimeInterval(3600)
                    
                    components.hour = (components.hour ?? 0) + 1
                    endTime = calendar.date(from: components) ?? startTime.addingTimeInterval(3600)
                }

                eventDate = now
                recurrenceConfig = RecurrenceConfiguration.none(anchor: now)

                // Build available calendars list
                updateAvailableCalendars()

                // Clean up stale selected members (in case they were deleted)
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
            // Everyone selected: use the selected shared calendar
            targets = [(selectedCalendarID, nil)]
        } else {
            // Specific people selected: add to each person's selected calendar
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
        let locationValue = locationAddress.isEmpty ? nil : locationAddress
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
            print("🔔 Scheduling ONE consolidated notification for event: \(eventId)")
            print("📋 Attendees: \(allAttendees.map { $0.name ?? "Unknown" }.joined(separator: ", "))")
            print("📍 Location: \(locationAddress.isEmpty ? "None" : locationAddress)")
            scheduleNotificationForCreatedEvent(
                eventIdentifier: eventId,
                attendingMembers: allAttendees,
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

            guard let ekEvent = CalendarManager.shared.getEvent(withIdentifier: eventIdentifier) else { return }

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

    @ViewBuilder
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Time")

            VStack(spacing: 0) {
                HStack {
                    Text("All-day")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(primaryTextColor)
                    Spacer()
                    Toggle("", isOn: $isAllDay)
                        .tint(accentColor)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 10)

                Divider().padding(.leading, 4)

                timeRow(title: "Starts",
                        dateText: formattedDate(startTime),
                        timeText: formattedTime(startTime),
                        dateAction: {
                            withAnimation {
                                activeTimePicker = activeTimePicker == .startDate ? .none : .startDate
                            }
                        },
                        timeAction: {
                            withAnimation {
                                activeTimePicker = activeTimePicker == .startTime ? .none : .startTime
                            }
                        })

                Divider().padding(.leading, 4)

                timeRow(title: "Ends",
                        dateText: formattedDate(endTime),
                        timeText: formattedTime(endTime),
                        dateAction: {
                            withAnimation {
                                activeTimePicker = activeTimePicker == .endDate ? .none : .endDate
                            }
                        },
                        timeAction: {
                            withAnimation {
                                activeTimePicker = activeTimePicker == .endTime ? .none : .endTime
                            }
                        })

                if activeTimePicker == .startDate {
                    DatePicker(
                        "Select Start Date",
                        selection: $startTime,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, calendarWithMondayAsFirstDay)
                    .onChange(of: startTime) { _, newValue in
                        // Update eventDate for recurrence anchor if needed, or just keep it in sync
                        eventDate = newValue
                        // When start date changes, also update end date to same date and end time to 1 hour later
                        let calendar = Calendar.current
                        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startTime)
                        var endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: endTime)
                        endComponents.year = startComponents.year
                        endComponents.month = startComponents.month
                        endComponents.day = startComponents.day
                        endComponents.hour = (startComponents.hour ?? 0) + 1
                        endTime = calendar.date(from: endComponents) ?? endTime
                    }
                }

                if activeTimePicker == .endDate {
                    DatePicker(
                        "Select End Date",
                        selection: $endTime,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, calendarWithMondayAsFirstDay)
                }

                Divider().padding(.leading, 4)

                timeShowAsRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(cardBackground)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(sectionBorder, lineWidth: 1)
            )



            if activeTimePicker == .startTime {
                DatePicker(
                    "Start Time",
                    selection: Binding(
                        get: { startTime },
                        set: { newValue in
                            // Round to nearest 5 minutes
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: newValue)
                            let minute = components.minute ?? 0
                            let roundedMinute = (minute / 5) * 5

                            var adjustedComponents = components
                            adjustedComponents.minute = roundedMinute
                            let adjustedValue = calendar.date(from: adjustedComponents) ?? newValue

                            startTime = adjustedValue

                            // When start time changes, update end time to 1 hour later (same date)
                            let startComponents = calendar.dateComponents([.hour, .minute], from: adjustedValue)
                            var endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: endTime)
                            endComponents.hour = (startComponents.hour ?? 0) + 1
                            endComponents.minute = startComponents.minute
                            endTime = calendar.date(from: endComponents) ?? endTime
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
            }

            if activeTimePicker == .endTime {
                DatePicker(
                    "End Time",
                    selection: Binding(
                        get: { endTime },
                        set: { newValue in
                            // Round to nearest 5 minutes
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: newValue)
                            let minute = components.minute ?? 0
                            let roundedMinute = (minute / 5) * 5

                            var adjustedComponents = components
                            adjustedComponents.minute = roundedMinute
                            endTime = calendar.date(from: adjustedComponents) ?? newValue
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
            }
        }
    }

    private func timeRow(title: String,
                         dateText: String,
                         timeText: String,
                         dateAction: @escaping () -> Void,
                         timeAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(primaryTextColor)

            Spacer()

            pillButton(dateText, action: dateAction)
            pillButton(timeText, action: timeAction)
        }
        .padding(.vertical, 10)
    }

    private var timeShowAsRow: some View {
        HStack {
            Text("Show as")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(primaryTextColor)

            Spacer()

            Menu {
                ForEach(ShowAsOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        showAsOption = option
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(showAsOption.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(secondaryTextColor)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(chipBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    private func pillButton(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(primaryTextColor)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(chipBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var attendeesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Attendees")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryTextColor)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.2")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(secondaryTextColor)
                        Text(attendeesSummary)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showingPeoplePicker.toggle()
                            }
                        }) {
                            Image(systemName: showingPeoplePicker ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .padding(12)
                    .background(fieldBackground)
                    .cornerRadius(12)

                    if showingPeoplePicker {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $selectEveryone.animation()) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(accentColor.opacity(0.9))
                                        .frame(width: 32, height: 32)
                                        .overlay(Text("👥").font(.system(size: 18)))
                                    Text("Everyone")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(primaryTextColor)
                                }
                            }
                            .tint(accentColor)

                            if !selectEveryone {
                                ForEach(familyMembers, id: \.objectID) { member in
                                    Toggle(isOn: Binding(
                                        get: { selectedMembers.contains(member.objectID) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedMembers.insert(member.objectID)
                                            } else {
                                                selectedMembers.remove(member.objectID)
                                            }
                                        }
                                    )) {
                                        HStack(spacing: 12) {
                                            if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar>,
                                               let firstCal = memberCals.first,
                                               let colorHex = firstCal.calendarColorHex {
                                                Circle()
                                                    .fill(Color.fromHex(colorHex))
                                                    .frame(width: 12, height: 12)
                                            } else {
                                                Circle()
                                                    .fill(Color.fromHex(member.colorHex ?? "#555555"))
                                                    .frame(width: 12, height: 12)
                                            }
                                            Text(member.name ?? "Unknown")
                                                .font(.system(size: 16, weight: .regular))
                                                .foregroundColor(primaryTextColor)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(fieldBackground)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var driverSection: some View {
        if !allAvailableDrivers.isEmpty {
            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Driver")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "car.fill")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(secondaryTextColor)
                            Text("Assign driver")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(primaryTextColor)
                            Spacer()
                            Menu {
                                Button(action: { selectedDriver = nil }) {
                                    HStack {
                                        Text("None")
                                        if selectedDriver == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }

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
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedDriver?.name ?? "None")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(primaryTextColor)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(secondaryTextColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(fieldBackground)
                                .cornerRadius(10)
                            }
                        }

                        if let driver = selectedDriver, driver.isFamilyMember {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(secondaryTextColor)
                                Text("Travel Time")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(primaryTextColor)
                                Spacer()
                                Menu {
                                    ForEach([5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { minutes in
                                        Button(action: { driverTravelTimeMinutes = minutes }) {
                                            HStack {
                                                Text("\(minutes) min")
                                                if driverTravelTimeMinutes == minutes {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("\(driverTravelTimeMinutes) min")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(primaryTextColor)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(fieldBackground)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var repeatSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Repeat")

                Menu {
                    ForEach(RepeatOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            handleRepeatSelection(option)
                        }
                    }
                } label: {
                    HStack {
                        Text("Repeat")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Text(repeatOption.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(secondaryTextColor)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(fieldBackground)
                    .cornerRadius(14)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recurrenceSummaryText(anchorDate: eventDate))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    Text(repeatDetailLabel)
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(fieldBackground)
                )

                Button {
                    if let existing = currentRecurrenceConfiguration(anchorDate: eventDate) {
                        recurrenceConfig = existing
                    } else {
                        recurrenceConfig = RecurrenceConfiguration.quick(option: .weekly, anchor: eventDate) ?? recurrenceConfig
                    }
                    repeatOption = .custom
                    showingCustomRepeatSheet = true
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Custom repeat options")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
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

    @ViewBuilder
    private var alertSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Alert")

                Menu {
                    ForEach(AlertOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            alertOption = option
                        }
                    }
                } label: {
                    HStack {
                        Text("Alert")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Text(alertOption.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(secondaryTextColor)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(fieldBackground)
                    .cornerRadius(14)
                }
            }
        }
    }

    @ViewBuilder
    private var calendarSection: some View {
        if selectEveryone && !availableCalendars.isEmpty {
            // For "Everyone": Show shared calendars selection
            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Calendar")

                    Menu {
                        ForEach(availableCalendars) { calendar in
                            Button(action: {
                                selectedCalendarID = calendar.calendarID
                            }) {
                                HStack {
                                    Circle()
                                        .fill(Color(uiColor: calendar.color))
                                        .frame(width: 12, height: 12)
                                    Text(calendar.calendarName)
                                    if selectedCalendarID == calendar.calendarID {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Calendar")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(primaryTextColor)
                            Spacer()
                            if let current = availableCalendars.first(where: { $0.calendarID == selectedCalendarID }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(uiColor: current.color))
                                        .frame(width: 10, height: 10)
                                    Text(current.calendarName)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(primaryTextColor)
                                }
                            } else {
                                Text("Select")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(secondaryTextColor)
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(fieldBackground)
                        .cornerRadius(14)
                    }
                }
            }
        } else if !selectEveryone {
            // For specific members: Show per-member calendar selection (always visible)
            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Calendars")

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(selectedMembers.sorted { mem1, mem2 in
                            let member1 = familyMembers.first(where: { $0.objectID == mem1 })?.name ?? "Unknown"
                            let member2 = familyMembers.first(where: { $0.objectID == mem2 })?.name ?? "Unknown"
                            return member1.localizedCaseInsensitiveCompare(member2) == .orderedAscending
                        }, id: \.self) { memberID in
                            if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                                memberCalendarSelector(for: member)
                            }
                        }
                    }
                }
            }
        }
    }

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

    @ViewBuilder
    private func memberCalendarSelector(for member: FamilyMember) -> some View {
        // Force-load the memberCalendars relationship
        let memberCalendars = (member.memberCalendars as? Set<FamilyMemberCalendar>) ?? Set()
        // Load personal calendars for this member
        let personalCalendars = (member.personalCalendars as? Set<PersonalCalendar>) ?? Set()

        // Combine both types into a single list
        let allCalendars = buildCombinedCalendarList(memberCalendars: memberCalendars, personalCalendars: personalCalendars)

        if !allCalendars.isEmpty {
            // Filter out subscription/read-only calendars
            let writableCalendars = allCalendars.filter { item in
                if let calendarID = (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID {
                    if let ekCalendar = CalendarManager.shared.getCalendar(withIdentifier: calendarID) {
                        return ekCalendar.allowsContentModifications
                    }
                }
                // Include calendars we can't verify (assume writable)
                return true
            }

            if !writableCalendars.isEmpty {
                let sortedCalendars = writableCalendars.sorted { item1, item2 in
                    // Auto-linked calendar first
                    if item1.isAutoLinked && !item2.isAutoLinked { return true }
                    if !item1.isAutoLinked && item2.isAutoLinked { return false }
                    // Then by name
                    return item1.name < item2.name
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(member.name ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)

                    Menu {
                        ForEach(sortedCalendars.indices, id: \.self) { index in
                            let item = sortedCalendars[index]
                            Button(action: {
                                // Store selected calendar per member
                                updateSelectedCalendarForMemberCombined(member: member, calendarID: (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID, type: item.type)
                            }) {
                                HStack {
                                    Circle()
                                        .fill(Color.fromHex(item.colorHex))
                                        .frame(width: 12, height: 12)
                                    Text(item.name)
                                    if isCalendarSelectedForMemberCombined(member: member, calendarID: (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID, type: item.type) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if let (selectedID, selectedColor) = getSelectedCalendarForMemberCombined(member: member) {
                                Circle()
                                    .fill(Color.fromHex(selectedColor))
                                    .frame(width: 10, height: 10)
                                if let memberCal = memberCalendars.first(where: { $0.calendarID == selectedID }) {
                                    Text(memberCal.calendarName ?? "Unknown")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(primaryTextColor)
                                } else if let personalCal = personalCalendars.first(where: { $0.calendarID == selectedID }) {
                                    Text(personalCal.calendarName ?? "Unknown")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(primaryTextColor)
                                } else {
                                    Text("Unknown")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(primaryTextColor)
                                }
                            } else {
                                Text("Select calendar")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(secondaryTextColor)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(fieldBackground)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Member Calendar Selection Helpers

    private func updateSelectedCalendarForMember(member: FamilyMember, calendar: FamilyMemberCalendar) {
        if let calendarID = calendar.calendarID {
            selectedMemberCalendars[member.objectID] = calendarID
            selectedCalendarID = calendarID // Also update main selection
        }
    }

    private func getSelectedCalendarForMember(member: FamilyMember) -> FamilyMemberCalendar? {
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
            // Check if there's a manually selected calendar for this member
            if let selectedCalID = selectedMemberCalendars[member.objectID],
               let selected = memberCalendars.first(where: { $0.calendarID == selectedCalID }) {
                return selected
            }

            // Otherwise return the first auto-linked calendar (predefined default)
            if let autoLinked = memberCalendars.first(where: { $0.isAutoLinked }) {
                return autoLinked
            }
            // If no auto-linked, return first calendar
            return memberCalendars.sorted { ($0.calendarName ?? "") < ($1.calendarName ?? "") }.first
        }
        return nil
    }

    private func isCalendarSelectedForMember(member: FamilyMember, calendar: FamilyMemberCalendar) -> Bool {
        if let selected = getSelectedCalendarForMember(member: member),
           selected.objectID == calendar.objectID {
            return true
        }
        return false
    }

    // New combined helpers for member + personal calendars
    private func updateSelectedCalendarForMemberCombined(member: FamilyMember, calendarID: String?, type: String) {
        if let calendarID = calendarID {
            selectedMemberCalendars[member.objectID] = calendarID
            selectedCalendarID = calendarID // Also update main selection
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
            return nil
        }

        // Default to first auto-linked member calendar
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar>,
           let autoLinked = memberCalendars.first(where: { $0.isAutoLinked }) {
            return (id: autoLinked.calendarID ?? "", color: autoLinked.calendarColorHex ?? "#555555")
        }

        // Fallback to first available member or personal calendar
        let memberCalendars = (member.memberCalendars as? Set<FamilyMemberCalendar>) ?? Set()
        if let firstMember = memberCalendars.sorted(by: { ($0.calendarName ?? "") < ($1.calendarName ?? "") }).first,
           let calID = firstMember.calendarID {
            return (id: calID, color: firstMember.calendarColorHex ?? "#555555")
        }

        if let personalCalendars = member.personalCalendars as? Set<PersonalCalendar>,
           let firstPersonal = personalCalendars.sorted(by: { ($0.calendarName ?? "") < ($1.calendarName ?? "") }).first,
           let calID = firstPersonal.calendarID {
            return (id: calID, color: firstPersonal.calendarColorHex ?? "#555555")
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

    @ViewBuilder
    private var notesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("Notes")

                TextEditor(text: $notes)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(primaryTextColor)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(fieldBackground)
                    .cornerRadius(12)
                    .frame(height: 120)
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
}




#Preview {
    AddEventView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
