//
//  EditEventView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import MapKit
import Combine
import EventKit

struct EditEventView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    private enum DeleteScope {
        case singleCalendar
        case allLinked
    }

    let upcomingEvent: UpcomingCalendarEvent

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
    @State private var notes: String = ""
    @State private var locationName: String = ""
    @State private var locationAddress: String = ""
    @State private var isAllDay: Bool = false
    @State private var showAsOption: ShowAsOption = .busy
    @State private var repeatOption: RepeatOption = .none
    @State private var recurrenceConfig = RecurrenceConfiguration.none(anchor: Date())
    @State private var showingCustomRepeatSheet = false
    @State private var alertOption: AlertOption = .none

    // Location search
    @State private var showingLocationSearch = false

    // Calendar info for updating
    @State private var calendarId: String? = nil
    @State private var selectedMemberCalendars: [NSManagedObjectID: String] = [:] // Track calendar per member

    // Driver selection
    @State private var selectedDriver: DriverWrapper?
    @State private var driverTravelTimeMinutes: Int = 15
    @State private var shouldCreateTravelEvent: Bool = false

    // UI state
    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var showingStartTimePicker = false
    @State private var showingEndTimePicker = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingRecurringDeleteOptions = false
    @State private var showingSuccessMessage = false
    @State private var showingDeleteSuccess = false
    @State private var showingUpdateScopeDialog = false
    @State private var showingLinkedDeleteOptions = false
    @State private var pendingDeleteScope: DeleteScope = .singleCalendar
    @State private var linkedFamilyEvents: [FamilyEvent] = []
    @State private var externalEditCalendars: [String] = []
    @State private var showingCreateEventForDriverAlert = false
    @State private var driverToCreateEventFor: DriverWrapper?
    @State private var showingRecurringDriverChangeOptions = false
    @State private var pendingDriverChange: DriverWrapper?
    @State private var pendingDriverChangeSpan: EKSpan = .thisEvent
    private let notificationManager = NotificationManager.shared

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
        !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var eventForm: some View {
        ZStack {
            theme.backgroundLayer()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    locationSection
                    timeSection
                    repeatSection
                    alertSection
                    calendarSection
                    driverSection
                    notesSection
                    Spacer()
                        .frame(height: 20)
                }
                .padding(16)
            }
            .background(Color.clear)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button(action: handleDeleteTap) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                }

                Button(action: handleSaveTapped) {
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
    }

    var body: some View {
        NavigationStack {
            eventForm
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .confirmationDialog("Delete Event", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        Task { await deleteEvent(scope: pendingDeleteScope) }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this event? This cannot be undone.")
                }
                .confirmationDialog("Update Linked Calendars?", isPresented: $showingUpdateScopeDialog, titleVisibility: .visible) {
                    Button("Update all linked calendars") {
                        Task { await saveEvent(applyToGroup: true) }
                    }
                    Button("Update only this calendar") {
                        Task { await saveEvent(applyToGroup: false) }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    if externalEditCalendars.isEmpty {
                        Text("This event exists in multiple calendars. Do you want to apply these changes to all linked copies?")
                    } else {
                        let calendars = externalEditCalendars.joined(separator: ", ")
                        Text("This event exists in multiple calendars. Changes were detected outside this app on: \(calendars). Overwrite them with your updates?")
                    }
                }
                .confirmationDialog("Delete Linked Copies?", isPresented: $showingLinkedDeleteOptions, titleVisibility: .visible) {
                    Button("Delete only in this calendar", role: .destructive) {
                        pendingDeleteScope = .singleCalendar
                        if upcomingEvent.hasRecurrence {
                            showingRecurringDeleteOptions = true
                        } else {
                            Task { await deleteEvent(scope: .singleCalendar) }
                        }
                    }
                    Button("Delete in all linked calendars", role: .destructive) {
                        pendingDeleteScope = .allLinked
                        if upcomingEvent.hasRecurrence {
                            showingRecurringDeleteOptions = true
                        } else {
                            Task { await deleteEvent(scope: .allLinked) }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    if externalEditCalendars.isEmpty {
                        Text("This event is linked to other calendars. Do you want to delete it only here or everywhere?")
                    } else {
                        let calendars = externalEditCalendars.joined(separator: ", ")
                        Text("This event is linked to other calendars. Some copies were edited outside this app (\(calendars)). Delete only here or everywhere?")
                    }
                }
                .confirmationDialog("Delete Recurring Event?", isPresented: $showingRecurringDeleteOptions, titleVisibility: .visible) {
                    Button("Delete Only This Event", role: .destructive) {
                        Task { await deleteEvent(scope: pendingDeleteScope, span: .thisEvent) }
                    }
                    Button("Delete This and Future Events", role: .destructive) {
                        Task { await deleteEvent(scope: pendingDeleteScope, span: .futureEvents) }
                    }
                    Button("Cancel", role: .cancel) { }
                }
                .confirmationDialog("Change Driver for Recurring Event?", isPresented: $showingRecurringDriverChangeOptions, titleVisibility: .visible) {
                    Button("Change Only This Event") {
                        applyDriverChange(span: .thisEvent)
                    }
                    Button("Change This and Future Events") {
                        applyDriverChange(span: .futureEvents)
                    }
                    Button("Cancel", role: .cancel) { }
                }
                .onAppear {
                    // Populate fields from existing event
                    eventTitle = upcomingEvent.title
                    startTime = upcomingEvent.startDate
                    endTime = upcomingEvent.endDate
                    eventDate = upcomingEvent.startDate
                    locationAddress = upcomingEvent.location ?? ""
                    locationAddress = upcomingEvent.location ?? ""
                    locationName = upcomingEvent.location ?? ""
                    recurrenceConfig = RecurrenceConfiguration.none(anchor: upcomingEvent.startDate)
                    loadRecurrenceFromEventStore()

                    // Fetch calendar ID from CoreData
                    fetchCalendarId()

                    // Fetch driver from CoreData
                    fetchDriver()

                    // Load existing alert from the saved event so edits keep prior value
                    loadExistingAlertOption()

                    // Load linked copies so we can offer update/delete choices
                    loadLinkedFamilyEvents()

                    // Clean up stale selected members (in case they were deleted)
                    let validMemberIDs = Set(familyMembers.map { $0.objectID })
                    selectedMemberCalendars = selectedMemberCalendars.filter { validMemberIDs.contains($0.key) }
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
                .alert("Event Updated", isPresented: $showingSuccessMessage) {
                    Button("Done") {
                        dismiss()
                    }
                } message: {
                    Text("Your event has been updated successfully!")
                }
                .alert("Event Deleted", isPresented: $showingDeleteSuccess) {
                    Button("Done") {
                        dismiss()
                    }
                } message: {
                    Text("Your event has been deleted successfully!")
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

    private func fetchCalendarId() {
        // Use the calendar ID directly from the event (it comes from EventKit)
        calendarId = upcomingEvent.calendarID
    }

    private func attendeeInfoForNotification() -> (memberIds: [UUID], memberNames: [String]) {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        if let familyEvent = try? viewContext.fetch(fetchRequest).first,
           let attendees = familyEvent.attendees as? Set<FamilyMember>,
           !attendees.isEmpty {
            let ids = attendees.compactMap { $0.id }
            let names = attendees.compactMap { $0.name }
            return (ids, names)
        }

        // Fallback to all family members so calendar-only filters can still pass
        let ids = familyMembers.compactMap { $0.id }
        let names = familyMembers.compactMap { $0.name }
        return (ids, names)
    }

    private func selectedDriverName() -> String? {
        switch selectedDriver {
        case .regular(let driver):
            return driver.name
        case .familyMember(let member):
            return member.name
        case .none:
            return nil
        }
    }

    private func loadExistingAlertOption() {
        let ekEvent = CalendarManager.shared.fetchEventDetails(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate
        ) ?? CalendarManager.shared.fetchEventDetails(withIdentifier: upcomingEvent.id)

        guard let ekEvent else {
            alertOption = .none
            return
        }

        if let alarm = ekEvent.alarms?.first {
            alertOption = alertOption(from: alarm)
        } else {
            alertOption = .none
        }
    }

    private func alertOption(from alarm: EKAlarm) -> AlertOption {
        let minutesOffset = Int(alarm.relativeOffset / 60)
        switch minutesOffset {
        case 0:
            return .atTime
        case -15:
            return .fifteenMinsBefore
        case -60:
            return .oneHourBefore
        case -1440:
            return .oneDayBefore
        default:
            return .custom
        }
    }

    private func fetchDriver() {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let familyEvent = results.first, let driver = familyEvent.driver {
                // Check if this driver is linked to a family member
                if let familyMemberId = driver.familyMemberId {
                    // This is a family member driver - find the family member and wrap it
                    if let familyMember = familyMembers.first(where: { $0.id == familyMemberId }) {
                        selectedDriver = .familyMember(familyMember)
                    }
                } else {
                    // This is a regular driver
                    selectedDriver = .regular(driver)
                }

                // Load the travel time if this is a family member driver
                if driver.familyMemberId != nil {
                    driverTravelTimeMinutes = Int(driver.travelTimeMinutes)
                }
            }
        } catch {
            print("Failed to fetch driver for event: \(error.localizedDescription)")
        }
    }

    private func loadLinkedFamilyEvents() {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            if let current = try viewContext.fetch(fetchRequest).first {
                var results: [FamilyEvent] = [current]

                if let groupId = current.eventGroupId {
                    let groupFetch = FamilyEvent.fetchRequest()
                    groupFetch.predicate = NSPredicate(format: "eventGroupId == %@", groupId as CVarArg)
                    results = try viewContext.fetch(groupFetch)
                }

                // Deduplicate and keep only entries with identifiers
                let keyed: [(String, FamilyEvent)] = results.compactMap { familyEvent in
                    guard let identifier = familyEvent.eventIdentifier else { return nil }
                    return (identifier, familyEvent)
                }

                let grouped = Dictionary(grouping: keyed, by: { pair in pair.0 })
                let unique: [FamilyEvent] = grouped.compactMap { _, value in
                    value.first?.1
                }

                linkedFamilyEvents = unique
                print("🔗 Loaded \(linkedFamilyEvents.count) linked event(s) for group.")
            } else {
                linkedFamilyEvents = []
            }
        } catch {
            print("❌ Failed to load linked events: \(error.localizedDescription)")
            linkedFamilyEvents = []
        }
    }

    private func applyDriverChange(span: EKSpan) {
        selectedDriver = pendingDriverChange
        pendingDriverChange = nil
        pendingDriverChangeSpan = span

        // Only show alert if selecting a family member driver
        if let driver = selectedDriver, case .familyMember(_) = driver {
            driverToCreateEventFor = driver
            showingCreateEventForDriverAlert = true
        }
    }

    private func handleSaveTapped() {
        externalEditCalendars = []

        if linkedFamilyEvents.count > 1 {
            externalEditCalendars = detectExternalChanges(in: linkedFamilyEvents)
            showingUpdateScopeDialog = true
        } else {
            Task { await saveEvent(applyToGroup: false) }
        }
    }

    private func detectExternalChanges(in familyEvents: [FamilyEvent]) -> [String] {
        var externallyEditedCalendars: Set<String> = []

        for familyEvent in familyEvents {
            guard let identifier = familyEvent.eventIdentifier else { continue }
            let ekEvent = CalendarManager.shared.fetchEventDetails(
                withIdentifier: identifier,
                occurrenceStartDate: upcomingEvent.startDate
            ) ?? CalendarManager.shared.fetchEventDetails(withIdentifier: identifier)

            guard let ekEvent else { continue }

            if let modifiedDate = ekEvent.lastModifiedDate {
                let lastUpdated = familyEvent.createdAt ?? .distantPast
                if modifiedDate > lastUpdated.addingTimeInterval(1) {
                    externallyEditedCalendars.insert(ekEvent.calendar.title)
                }
            }
        }

        return Array(externallyEditedCalendars)
    }

    private func loadRecurrenceFromEventStore() {
        let anchorDate = upcomingEvent.startDate

        // Prefer loading the full recurrence rule from EventKit to keep all days/end dates intact
        if let ekEvent = CalendarManager.shared.fetchEventDetails(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate
        ) ?? CalendarManager.shared.getEvent(withIdentifier: upcomingEvent.id),
           let rule = ekEvent.recurrenceRules?.first {

            if let parsed = RecurrenceConfiguration.from(rule: rule, anchor: ekEvent.startDate) {
                recurrenceConfig = parsed
                repeatOption = parsed.suggestedRepeatOption(anchor: ekEvent.startDate)
            } else {
                recurrenceConfig.isEnabled = true
                repeatOption = .custom
            }
            return
        }

        // Fallbacks when no rule found
        if upcomingEvent.hasRecurrence {
            recurrenceConfig.isEnabled = true
            repeatOption = .custom
        } else {
            recurrenceConfig = RecurrenceConfiguration.none(anchor: anchorDate)
            repeatOption = .none
        }
    }

    private func propagateUpdateToLinkedEvents(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        notes: String?,
        isAllDay: Bool,
        recurrenceRule: EKRecurrenceRule?,
        span: EKSpan,
        alertOption: AlertOption?
    ) async {
        let otherEvents = linkedFamilyEvents.filter { $0.eventIdentifier != upcomingEvent.id }
        guard !otherEvents.isEmpty else { return }

        print("🔗 Propagating updates to \(otherEvents.count) linked event(s)")

        for familyEvent in otherEvents {
            guard let calId = familyEvent.calendarId,
                  let eventId = familyEvent.eventIdentifier else { continue }

            let occurrenceDate = CalendarManager.shared.fetchEventDetails(withIdentifier: eventId)?.startDate

            let success = CalendarManager.shared.updateEvent(
                withIdentifier: eventId,
                occurrenceStartDate: occurrenceDate,
                in: calId,
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes,
                isAllDay: isAllDay,
                recurrenceRule: recurrenceRule,
                updateRecurrence: true,
                span: span,
                alertOption: alertOption
            )

            if success {
                await MainActor.run {
                    familyEvent.createdAt = Date()
                }
            } else {
                print("⚠️ Failed to update linked event \(eventId) in calendar \(calId)")
            }
        }

        await MainActor.run {
            if viewContext.hasChanges {
                try? viewContext.save()
            }
        }
    }

    private func saveEvent(applyToGroup: Bool = false) async {
        await MainActor.run {
            isSaving = true
            print("📝 Starting save event for: \(upcomingEvent.title)")
            print("   Event ID: \(upcomingEvent.id)")
            print("   Calendar ID: \(upcomingEvent.calendarID)")
        }

        // Ensure we have the calendar ID
        guard let calId = calendarId, !calId.isEmpty else {
            await MainActor.run {
                errorMessage = "Unable to determine which calendar this event is in. Please try again."
                showingError = true
                isSaving = false
            }
            return
        }

        let title = eventTitle.trimmingCharacters(in: .whitespaces)

        // Use startTime and endTime directly as they now contain the correct date and time
        let eventStartDate = startTime
        let eventEndDate = endTime

        print("📝 Event details:")
        print("   Title: \(title)")
        print("   Start: \(eventStartDate)")
        print("   End: \(eventEndDate)")
        print("   Location: \(locationAddress.isEmpty ? "(none)" : locationAddress)")

        let recurrenceRule = selectedRecurrenceRule(startDate: eventStartDate)
        let updateSpan: EKSpan = (upcomingEvent.hasRecurrence || recurrenceRule != nil) ? .futureEvents : .thisEvent

        let success = CalendarManager.shared.updateEvent(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate,
            in: calId,
            title: title,
            startDate: eventStartDate,
            endDate: eventEndDate,
            location: locationAddress.isEmpty ? nil : locationAddress,
            notes: notes.isEmpty ? nil : notes,
            isAllDay: isAllDay,
            recurrenceRule: recurrenceRule,
            updateRecurrence: true,
            span: updateSpan,
            alertOption: alertOption
        )

        if success {
            if applyToGroup {
                await propagateUpdateToLinkedEvents(
                    title: title,
                    startDate: eventStartDate,
                    endDate: eventEndDate,
                    location: locationAddress.isEmpty ? nil : locationAddress,
                    notes: notes.isEmpty ? nil : notes,
                    isAllDay: isAllDay,
                    recurrenceRule: recurrenceRule,
                    span: updateSpan,
                    alertOption: alertOption
                )
            }

            // Update CoreData record if needed
            updateFamilyEvent()
            await syncDriverMetadataForLinks(span: updateSpan, applyToGroup: applyToGroup)

            await MainActor.run {
                loadLinkedFamilyEvents()
            }

            // Refresh local notifications to mirror the new alert setting
            Task {
                await notificationManager.cancelEventNotifications(for: upcomingEvent.id)

                if alertOption != .none {
                    let attendeeInfo = attendeeInfoForNotification()
                    if notificationManager.shouldNotifyForEvent(
                        calendarId: calId,
                        memberIds: attendeeInfo.memberIds
                    ),
                       let ekEvent = CalendarManager.shared.getEvent(withIdentifier: upcomingEvent.id) {
                        let isSharedEvent = linkedFamilyEvents.first?.isSharedCalendarEvent ?? false
                        notificationManager.scheduleEventNotification(
                            event: ekEvent,
                            alertOption: alertOption,
                            familyMembers: attendeeInfo.memberNames,
                            drivers: selectedDriverName(),
                            isSharedCalendarEvent: isSharedEvent
                        )
                    }
                }
            }

            await MainActor.run {
                // Trigger haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)

                // Show success message and auto-dismiss
                showingSuccessMessage = true
            }

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } else {
            await MainActor.run {
                errorMessage = "Failed to update event. The event may have been deleted or the calendar is no longer accessible. Please try refreshing and creating a new event."
                showingError = true
                isSaving = false
            }
        }
    }

    private func updateFamilyEvent() {
        print("🚗 updateFamilyEvent called for event: \(upcomingEvent.id)")
        print("   Selected driver: \(selectedDriver?.name ?? "nil")")

        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            print("   FamilyEvents found: \(results.count)")

            let familyEvent: FamilyEvent
            if let existing = results.first {
                familyEvent = existing
                print("   Updating existing FamilyEvent with ID: \(familyEvent.id?.uuidString ?? "nil")")
            } else {
                // Create a new FamilyEvent record for this event
                print("   No FamilyEvent found - creating new one")
                familyEvent = FamilyEvent(context: viewContext)
                familyEvent.id = UUID()
                familyEvent.eventGroupId = UUID()
                familyEvent.eventIdentifier = upcomingEvent.id
                familyEvent.calendarId = upcomingEvent.calendarID
                familyEvent.createdAt = Date()
                familyEvent.isSharedCalendarEvent = false
                print("   Created new FamilyEvent with ID: \(familyEvent.id?.uuidString ?? "nil")")
            }

            print("   Has changes before: \(viewContext.hasChanges)")

            // Update the modified event in CoreData
            familyEvent.createdAt = Date() // Update timestamp

            // Handle driver assignment
            if let driverWrapper = selectedDriver {
                switch driverWrapper {
                case .regular(let driver):
                    familyEvent.driver = driver
                    print("🚗 Assigned regular driver: \(driver.name ?? "Unknown")")

                case .familyMember(let member):
                    // Store family member ID as driver (don't create Driver entity)
                    familyEvent.driverFamilyMemberId = member.id
                    // Clear any regular driver that was previously set
                    familyEvent.driver = nil
                    print("🚗 Set family member as driver: \(member.name ?? "Unknown")")

                    // Update or create travel event only if user confirmed
                    if shouldCreateTravelEvent {
                        updateTravelEvent(
                            for: member,
                            eventName: eventTitle,
                            eventStartTime: combineDateAndTime(date: eventDate, time: startTime),
                            travelTimeMinutes: driverTravelTimeMinutes,
                            driver: nil
                        )

                        print("🚗 Updated travel event for family member driver: \(member.name ?? "Unknown"), travel time: \(driverTravelTimeMinutes) min")
                    } else if !shouldCreateTravelEvent {
                        print("🚗 Skipped travel event update for family member driver: \(member.name ?? "Unknown")")
                    }
                }
            } else {
                // No driver selected - clear the driver
                familyEvent.driver = nil
                familyEvent.driverFamilyMemberId = nil
            }

            print("   Driver assigned: \(familyEvent.driver?.name ?? "nil")")
            print("   Has changes after: \(viewContext.hasChanges)")

            try viewContext.save()
            print("✅ FamilyEvent saved successfully")

            // Verify the save
            if let saved = try viewContext.fetch(fetchRequest).first {
                print("✅ Verified: FamilyEvent driver is now \(saved.driver?.name ?? "nil")")
            }

            // Sync driver metadata to Supabase so future pulls reflect the latest selection
            Task {
                await syncDriverMetadataToSupabase(for: familyEvent)
            }
        } catch {
            print("❌ Failed to update FamilyEvent record: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   Error domain: \(nsError.domain)")
            print("   Error code: \(nsError.code)")
        }
    }

    private func syncDriverMetadataToSupabase(for familyEvent: FamilyEvent) async {
        guard let userId = SupabaseAuthManager.shared.userId else {
            print("⚠️ Supabase sync skipped: no user ID")
            return
        }

        let calId = calendarId ?? upcomingEvent.calendarID
        guard !calId.isEmpty else {
            print("⚠️ Supabase sync skipped: missing calendar ID for event \(upcomingEvent.id)")
            return
        }

        let driverFamilyMemberId = familyEvent.driverFamilyMemberId?.uuidString
        let extra = buildDriverExtraMetadata(from: selectedDriver)

        do {
            try await SupabaseManager.shared.upsertCalendarEventMetadata(
                userId: userId,
                eventIdentifier: upcomingEvent.id,
                driverFamilyMemberId: driverFamilyMemberId,
                extra: extra.isEmpty ? nil : extra
            )
            print("✅ Synced driver metadata to Supabase for event \(upcomingEvent.id)")
        } catch {
            print("❌ Failed to sync driver metadata to Supabase: \(error)")
        }
    }

    /// Syncs driver metadata for the current event and any linked events when applying to a group/future events.
    private func syncDriverMetadataForLinks(span: EKSpan, applyToGroup: Bool) async {
        guard let userId = SupabaseAuthManager.shared.userId else {
            print("⚠️ Supabase sync skipped: no user ID")
            return
        }

        let driverFamilyMemberId = selectedDriver?.familyMemberId?.uuidString
        let extra = buildDriverExtraMetadata(from: selectedDriver)
        let calendarIdForCurrent = calendarId ?? upcomingEvent.calendarID

        var targets: [(eventId: String, calendarId: String)] = []

        if !calendarIdForCurrent.isEmpty {
            targets.append((eventId: upcomingEvent.id, calendarId: calendarIdForCurrent))
        }

        if applyToGroup || span == .futureEvents {
            for familyEvent in linkedFamilyEvents {
                guard let eid = familyEvent.eventIdentifier,
                      let calId = familyEvent.calendarId else { continue }
                targets.append((eventId: eid, calendarId: calId))
            }
        }

        var seen: Set<String> = []
        for target in targets {
            let key = "\(target.eventId)|\(target.calendarId)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            do {
                try await SupabaseManager.shared.upsertCalendarEventMetadata(
                    userId: userId,
                    eventIdentifier: target.eventId,
                    driverFamilyMemberId: driverFamilyMemberId,
                    extra: extra.isEmpty ? nil : extra
                )
                print("✅ Synced driver metadata to Supabase for event \(target.eventId)")
            } catch {
                print("❌ Failed to sync driver metadata to Supabase for event \(target.eventId): \(error)")
            }
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

    private func updateTravelEvent(
        for familyMember: FamilyMember,
        eventName: String,
        eventStartTime: Date,
        travelTimeMinutes: Int,
        driver: Driver?
    ) {
        // Get the family member's linked personal calendar
        guard let memberCalendars = familyMember.memberCalendars as? Set<FamilyMemberCalendar>,
              let personalCalendar = memberCalendars.first(where: { $0.isAutoLinked }),
              let calendarID = personalCalendar.calendarID else {
            print("❌ Travel Event: Could not find linked calendar for family member \(familyMember.name ?? "Unknown")")
            return
        }

        // Calculate travel event timing
        let travelEventStartTime = eventStartTime.addingTimeInterval(-Double(travelTimeMinutes) * 60)
        let travelEventEndTime = eventStartTime
        let travelEventTitle = "Travel to \(eventName)"

        // If there's an existing travel event, update it
        if let existingTravelEventId = driver?.travelEventIdentifier, !existingTravelEventId.isEmpty {
            let success = CalendarManager.shared.updateEvent(
                withIdentifier: existingTravelEventId,
                occurrenceStartDate: travelEventStartTime,
                in: calendarID,
                title: travelEventTitle,
                startDate: travelEventStartTime,
                endDate: travelEventEndTime,
                location: nil,
                notes: "Travel time to \(eventName)"
            )

            if success {
                print("✈️ Travel event updated: '\(travelEventTitle)' on \(personalCalendar.calendarName ?? "Personal Calendar"), duration: \(travelTimeMinutes) min")
            } else {
                print("❌ Failed to update travel event")
            }
        } else {
            // Create a new travel event if one doesn't exist
            let travelEventId = CalendarManager.shared.createEvent(
                title: travelEventTitle,
                startDate: travelEventStartTime,
                endDate: travelEventEndTime,
                location: nil,
                notes: "Travel time to \(eventName)",
                in: calendarID
            )

            if let eventId = travelEventId {
                driver?.travelEventIdentifier = eventId
                print("✈️ Travel event created: '\(travelEventTitle)' on \(personalCalendar.calendarName ?? "Personal Calendar"), duration: \(travelTimeMinutes) min")
            } else {
                print("❌ Failed to create travel event")
            }
        }
    }

    private func handleDeleteTap() {
        pendingDeleteScope = .singleCalendar
        externalEditCalendars = []

        if linkedFamilyEvents.count > 1 {
            externalEditCalendars = detectExternalChanges(in: linkedFamilyEvents)
            showingLinkedDeleteOptions = true
            return
        }

        if upcomingEvent.hasRecurrence {
            showingRecurringDeleteOptions = true
        } else {
            showingDeleteConfirmation = true
        }
    }

    private func deleteEvent(scope: DeleteScope = .singleCalendar, span: EKSpan = .thisEvent) async {
        await MainActor.run {
            isSaving = true
            print("🗑️  Starting delete event for: \(upcomingEvent.title)")
            print("   Event ID: \(upcomingEvent.id)")
            print("   Calendar ID: \(upcomingEvent.calendarID)")
        }

        // Ensure we have the calendar ID
        let calId = calendarId ?? upcomingEvent.calendarID
        guard !calId.isEmpty else {
            await MainActor.run {
                errorMessage = "Unable to determine which calendar this event is in. Please try again."
                showingError = true
                isSaving = false
            }
            return
        }

        let success = await deleteLinkedEvents(scope: scope, span: span, primaryCalendarId: calId)

        if success {
            await MainActor.run {
                // Trigger haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)

                // Show success message and auto-dismiss
                showingDeleteSuccess = true
            }

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } else {
            await MainActor.run {
                errorMessage = "Failed to delete event. The event may have already been deleted or the calendar is no longer accessible."
                showingError = true
                isSaving = false
            }
        }
    }

    private func deleteLinkedEvents(scope: DeleteScope, span: EKSpan, primaryCalendarId: String) async -> Bool {
        let linked = linkedFamilyEvents.filter { $0.eventIdentifier != upcomingEvent.id }
        let includeLinked = scope == .allLinked && !linked.isEmpty

        var targets: [(id: String, calendarId: String, occurrence: Date)] = []
        targets.append((id: upcomingEvent.id, calendarId: primaryCalendarId, occurrence: upcomingEvent.startDate))

        if includeLinked {
            print("🗑️ Deleting \(linked.count) linked event(s)")
            for familyEvent in linked {
                guard let eid = familyEvent.eventIdentifier,
                      let calId = familyEvent.calendarId else { continue }

                let occurrence = CalendarManager.shared
                    .fetchEventDetails(withIdentifier: eid)?
                    .startDate ?? upcomingEvent.startDate

                targets.append((id: eid, calendarId: calId, occurrence: occurrence))
            }
        }

        var anyDeleted = false

        for target in targets {
            let success = CalendarManager.shared.deleteEvent(
                withIdentifier: target.id,
                occurrenceStartDate: target.occurrence,
                from: target.calendarId,
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
                print("⚠️ Failed to delete event \(target.id) in calendar \(target.calendarId)")
            }
        }

        await MainActor.run {
            if viewContext.hasChanges {
                try? viewContext.save()
            }
        }

        return anyDeleted
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

                timeRow(
                    title: "Starts",
                    dateText: formattedDate(startTime),
                    timeText: formattedTime(startTime),
                    dateAction: {
                        withAnimation {
                            if showingStartDatePicker {
                                showingStartDatePicker = false
                            } else {
                                showingStartDatePicker = true
                                showingEndDatePicker = false
                                showingStartTimePicker = false
                                showingEndTimePicker = false
                            }
                        }
                    },
                    timeAction: {
                        withAnimation {
                            if showingStartTimePicker {
                                showingStartTimePicker = false
                            } else {
                                showingStartTimePicker = true
                                showingStartDatePicker = false
                                showingEndDatePicker = false
                                showingEndTimePicker = false
                            }
                        }
                    }
                )

                Divider().padding(.leading, 4)

                timeRow(
                    title: "Ends",
                    dateText: formattedDate(endTime),
                    timeText: formattedTime(endTime),
                    dateAction: {
                        withAnimation {
                            if showingEndDatePicker {
                                showingEndDatePicker = false
                            } else {
                                showingEndDatePicker = true
                                showingStartDatePicker = false
                                showingStartTimePicker = false
                                showingEndTimePicker = false
                            }
                        }
                    },
                    timeAction: {
                        withAnimation {
                            if showingEndTimePicker {
                                showingEndTimePicker = false
                            } else {
                                showingEndTimePicker = true
                                showingStartDatePicker = false
                                showingEndDatePicker = false
                                showingStartTimePicker = false
                            }
                        }
                    }
                )
                
                if showingStartDatePicker {
                    DatePicker(
                        "Select Start Date",
                        selection: $startTime,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, calendarWithMondayAsFirstDay)
                    .onChange(of: startTime) { _, newValue in
                        // Update eventDate for recurrence anchor if needed
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
                
                if showingEndDatePicker {
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



            if showingStartTimePicker {
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

            if showingEndTimePicker {
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

    private var repeatDetailLabel: String {
        switch repeatOption {
        case .custom: return "Custom pattern"
        case .none: return "Off"
        default: return "Quick repeat"
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
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Calendar")

                if let member = getEventMember() {
                    memberCalendarSelector(for: member)
                } else {
                    Text("Calendar: \(upcomingEvent.calendarTitle)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(primaryTextColor)
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

                Menu {
                    ForEach(sortedCalendars.indices, id: \.self) { index in
                        let item = sortedCalendars[index]
                        Button(action: {
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
            } else {
                Text("Calendar: \(upcomingEvent.calendarTitle)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(primaryTextColor)
            }
        } else {
            Text("Calendar: \(upcomingEvent.calendarTitle)")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(primaryTextColor)
        }
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

    // MARK: - Calendar Selection Helpers

    private func getEventMember() -> FamilyMember? {
        // Try to find which member this event belongs to
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let familyEvent = results.first {
                if let attendees = familyEvent.attendees as? Set<FamilyMember>, !attendees.isEmpty {
                    return attendees.first
                }
            }
        } catch {
            print("Error fetching event member: \(error.localizedDescription)")
        }

        return nil
    }

    private func updateSelectedCalendarForMember(member: FamilyMember, calendar: FamilyMemberCalendar) {
        if let calendarID = calendar.calendarID {
            selectedMemberCalendars[member.objectID] = calendarID
            calendarId = calendarID
        }
    }

    private func getSelectedCalendarForMember(member: FamilyMember) -> FamilyMemberCalendar? {
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
            // Check if there's a manually selected calendar for this member
            if let selectedCalID = selectedMemberCalendars[member.objectID],
               let selected = memberCalendars.first(where: { $0.calendarID == selectedCalID }) {
                return selected
            }

            // Check if current event's calendar matches one of the member's calendars
            if let eventCalID = calendarId,
               let selected = memberCalendars.first(where: { $0.calendarID == eventCalID }) {
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
            self.calendarId = calendarID // Also update main selection
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

        // Prefer the event's current calendar ID if it matches this member's calendars
        let eventCalID = calendarId ?? upcomingEvent.calendarID
        if !eventCalID.isEmpty {
            if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar>,
               let match = memberCalendars.first(where: { $0.calendarID == eventCalID }) {
                return (id: eventCalID, color: match.calendarColorHex ?? "#555555")
            }
            if let personalCalendars = member.personalCalendars as? Set<PersonalCalendar>,
               let match = personalCalendars.first(where: { $0.calendarID == eventCalID }) {
                return (id: eventCalID, color: match.calendarColorHex ?? "#555555")
            }
        }

        // Default to first auto-linked member calendar
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar>,
           let autoLinked = memberCalendars.first(where: { $0.isAutoLinked }) {
            return (id: autoLinked.calendarID ?? "", color: autoLinked.calendarColorHex ?? "#555555")
        }

        // Fallback to first available member calendar
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar>,
           let firstMember = memberCalendars.sorted(by: { ($0.calendarName ?? "") < ($1.calendarName ?? "") }).first,
           let calID = firstMember.calendarID {
            return (id: calID, color: firstMember.calendarColorHex ?? "#555555")
        }

        // Fallback to first personal calendar
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
                                Button(action: {
                                    // Check if changing driver on a recurring event
                                    if selectedDriver != nil && upcomingEvent.hasRecurrence {
                                        pendingDriverChange = nil
                                        showingRecurringDriverChangeOptions = true
                                    } else {
                                        selectedDriver = nil
                                    }
                                }) {
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
                                        // Check if changing driver on a recurring event
                                        if selectedDriver?.id != driverWrapper.id && upcomingEvent.hasRecurrence {
                                            pendingDriverChange = driverWrapper
                                            showingRecurringDriverChangeOptions = true
                                        } else {
                                            selectedDriver = driverWrapper
                                            // Only show alert if selecting a family member driver
                                            if case .familyMember(_) = driverWrapper {
                                                driverToCreateEventFor = driverWrapper
                                                showingCreateEventForDriverAlert = true
                                            }
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
    private func createEventForDriver(_ driver: DriverWrapper) {
        // Create a new event for the driver using the current calendar
        // Note: startTime and endTime already contain the full date and time
        let driverEventTitle = "\(eventTitle) - \(driver.name)'s drive"

        if let calendarId = calendarId {
            let eventId = CalendarManager.shared.createEvent(
                title: driverEventTitle,
                startDate: startTime,
                endDate: endTime,
                location: locationAddress.isEmpty ? nil : locationAddress,
                notes: notes.isEmpty ? nil : notes,
                isAllDay: isAllDay,
                in: calendarId,
                alertOption: alertOption
            )

            if let eventId = eventId {
                print("✅ Created event for \(driver.name): \(eventId)")
            } else {
                print("❌ Failed to create event for driver")
            }
        } else {
            print("❌ No calendar ID available to create driver event")
        }
    }
}

#Preview {
    let testEvent = UpcomingCalendarEvent(
        id: "123",
        title: "Team Meeting",
        location: "Conference Room",
        startDate: Date().addingTimeInterval(3600),
        endDate: Date().addingTimeInterval(7200),
        calendarID: "demo-calendar",
        calendarColor: UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1.0),
        calendarTitle: "Work",
        hasRecurrence: false, recurrenceRule: nil, isAllDay: false
    )

    EditEventView(upcomingEvent: testEvent)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
