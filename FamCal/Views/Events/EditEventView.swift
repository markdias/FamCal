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

    init(upcomingEvent: UpcomingCalendarEvent, editSpan: EKSpan? = nil) {
        self.upcomingEvent = upcomingEvent
        _selectedEditSpan = State(initialValue: editSpan ?? .futureEvents)
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

    enum TimePicker {
        case none
        case startDate
        case endDate
        case startTime
        case endTime
    }

    // Event details
    @State private var eventTitle: String = ""
    @State private var eventDate = Date()
    @State private var eventEndDate = Date()
    @State private var notes: String = ""
    @State private var locationName: String = ""
    @State private var locationAddress: String = ""
    @State private var meetingLink: String = ""
    @State private var isAllDay: Bool = false
    @State private var showAsOption: ShowAsOption = .busy
    @State private var repeatOption: RepeatOption = .none
    @State private var recurrenceConfig = RecurrenceConfiguration.none(anchor: Date())
    @State private var showingCustomRepeatSheet = false
    @State private var alertOption: AlertOption = .none
    @State private var eventDuration: TimeInterval = 3600 // Default 1 hour
    @State private var travelTimeMinutes: Int? = nil
    @State private var showingTravelTimePicker = false

    // Location search
    @State private var showingLocationSearch = false

    // Calendar info for updating
    @State private var calendarId: String? = nil
    @State private var selectedMemberCalendars: [NSManagedObjectID: String] = [:] // Track calendar per member
    @State private var availableCalendars: [AvailableCalendar] = []

    // Driver selection
    @State private var selectedDriver: DriverWrapper?
    @State private var driverTravelTimeMinutes: Int = 15

    // Attendee selection
    @State private var selectedAttendees: Set<NSManagedObjectID> = []
    @State private var selectEveryone: Bool = false
    @State private var showingAttendeePicker: Bool = false

    // UI state
    @State private var activeTimePicker: TimePicker = .none
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingRecurringDeleteOptions = false
    @State private var showingDeleteSuccess = false
    @State private var showingUpdateScopeDialog = false
    @State private var showingLinkedDeleteOptions = false
    @State private var pendingDeleteScope: DeleteScope = .singleCalendar
    @State private var linkedFamilyEvents: [FamilyEvent] = []
    @State private var externalEditCalendars: [String] = []
    @State private var showingRecurringDriverChangeOptions = false
    @State private var pendingDriverChange: DriverWrapper?
    @State private var pendingDriverChangeSpan: EKSpan = .thisEvent
    @State private var selectedEditSpan: EKSpan

    // New deletion flow state
    @State private var showingInitialDeleteConfirm = false
    @State private var showingDeletionTypeDialog = false
    @State private var showingDeletionTargetDialog = false
    @State private var showingDeletionConfirmDialog = false
    @State private var pendingDeleteTarget: DeletionTarget = .singleOccurrence
    @State private var pendingDeleteActionType: DeleteActionType = .softDelete
    @State private var deletionReason: String = ""
    @State private var showingDeletionReasonSheet = false

    // Attendee editing state
    @State private var originalAttendees: Set<NSManagedObjectID> = []
    @State private var showingAttendeeEditScopeDialog = false
    @State private var pendingAttendeeEditApplyToGroup = false

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


    var isFormValid: Bool {
        !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var meetingLinkValue: String? {
        let trimmed = meetingLink.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var selectedCalendarName: String {
        let activeId = calendarId ?? upcomingEvent.calendarID
        if let match = availableCalendars.first(where: { $0.id == activeId }) {
            return match.title
        }
        return upcomingEvent.calendarTitle
    }

    private var relevantCalendarOptions: [AvailableCalendar] {
        var calendarIDs = Set<String>()

        for member in familyMembers {
            if let memberCals = member.memberCalendars?.allObjects as? [FamilyMemberCalendar] {
                for cal in memberCals {
                    if let calId = cal.calendarID {
                        calendarIDs.insert(calId)
                    }
                }
            }

            if let personalCals = member.personalCalendars?.allObjects as? [PersonalCalendar] {
                for cal in personalCals {
                    if let calId = cal.calendarID {
                        calendarIDs.insert(calId)
                    }
                }
            }

            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for cal in sharedCals {
                    if let calId = cal.calendarID {
                        calendarIDs.insert(calId)
                    }
                }
            }
        }

        return availableCalendars.filter { calendarIDs.contains($0.id) }
    }

    private var attendeesSummary: String {
        if selectEveryone {
            return "Everyone"
        }
        if selectedAttendees.isEmpty {
            return "None"
        }
        let selected = familyMembers.filter { selectedAttendees.contains($0.objectID) }
        let names = selected.map { $0.name ?? "Unknown" }
        return names.joined(separator: ", ")
    }

    private var driverFamilyMember: FamilyMember? {
        if case .familyMember(let member) = selectedDriver { return member }
        return nil
    }

    private func togglePicker(_ picker: TimePicker) {
        withAnimation {
            activeTimePicker = activeTimePicker == picker ? .none : picker
        }
    }

    private var deletionContext: DeletionContext? {
        let peopleNames = LinkedEventDeletionHandler.shared.getAffectedPeopleNames(
            scope: pendingDeleteScope,
            linkedFamilyEvents: linkedFamilyEvents,
            currentMemberName: nil
        )

        // Format event date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let formattedDate = dateFormatter.string(from: upcomingEvent.startDate)

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let formattedTime = timeFormatter.string(from: upcomingEvent.startDate)

        return DeletionContext(
            scope: pendingDeleteScope,
            target: pendingDeleteTarget,
            actionType: pendingDeleteActionType,
            affectedPeople: peopleNames,
            linkedEventCount: linkedFamilyEvents.count + 1,
            personName: nil,
            isRecurring: upcomingEvent.hasRecurrence,
            eventTitle: upcomingEvent.title,
            eventDate: formattedDate,
            eventTime: formattedTime,
            eventLocation: upcomingEvent.location
        )
    }

    @ViewBuilder
    private var deletionReasonSheet: some View {
        NavigationStack {
            Form {
                Section("Why are you removing this event?") {
                    TextEditor(text: $deletionReason)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Removal Reason")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingDeletionReasonSheet = false
                        deletionReason = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Remove") {
                        showingDeletionReasonSheet = false
                        Task { await executeNewDeletion() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var eventForm: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                whenCard
                whoCard
                notesCard
                
                Button(action: handleDeleteTap) {
                     Text("Delete Event")
                         .font(.system(size: 17, weight: .semibold))
                         .foregroundColor(.white)
                         .frame(maxWidth: .infinity)
                         .padding(.vertical, 16)
                         .background(Color.red)
                         .cornerRadius(12)
                }
                .padding(.top, 10)
                
                Spacer().frame(height: 40)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(action: handleSaveTapped) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save")
                        .bold()
                }
            }
            .disabled(!isFormValid || isSaving)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground) // New background
                    .ignoresSafeArea()
                
                eventForm
                    .navigationTitle("Edit Event") // Added title
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }

                allDialogs()
            }
            .onAppear {
                eventTitle = upcomingEvent.title
                eventDate = upcomingEvent.startDate
                eventEndDate = upcomingEvent.endDate
                UIDatePicker.appearance().minuteInterval = 5
                // existing logic
                // Initialize duration from the loaded event
                eventDuration = upcomingEvent.endDate.timeIntervalSince(upcomingEvent.startDate)
                locationAddress = upcomingEvent.location ?? ""
                locationName = upcomingEvent.location ?? ""
                recurrenceConfig = RecurrenceConfiguration.none(anchor: upcomingEvent.startDate)
                loadRecurrenceFromEventStore()
                meetingLink = upcomingEvent.meetingLink ?? ""
                fetchCalendarId()
                fetchDriver()
                loadExistingAlertOption()
                loadExistingTravelTime()
                loadLinkedFamilyEvents()
                loadAvailableCalendars()
                let validMemberIDs = Set(familyMembers.map { $0.objectID })
                selectedMemberCalendars = selectedMemberCalendars.filter { validMemberIDs.contains($0.key) }
                loadExistingAttendees()
            }
            .onChange(of: selectEveryone) { _, newValue in
                if newValue {
                    selectedAttendees.removeAll()
                }
            }
            .onChange(of: selectedAttendees) { _, _ in
                applyCalendarSelectionForSingleAttendee()
            }
            .sheet(isPresented: $showingAttendeePicker) {
                attendeePicker
            }
            .tint(accentColor)
            }
    }

    @ViewBuilder
    private var attendeePicker: some View {
        NavigationStack {
            Form {
                Section("Invitees") {
                    Toggle("Everyone", isOn: $selectEveryone)
                    if !selectEveryone {
                        ForEach(familyMembers, id: \.objectID) { member in
                            Button {
                                toggleAttendee(member)
                            } label: {
                                HStack {
                                    Text(member.name ?? "Unknown")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedAttendees.contains(member.objectID) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                if !selectEveryone, let member = singleSelectedMember {
                    let calendars = buildCombinedCalendarList(
                        memberCalendars: (member.memberCalendars as? Set<FamilyMemberCalendar>) ?? Set(),
                        personalCalendars: (member.personalCalendars as? Set<PersonalCalendar>) ?? Set()
                    )
                    if !calendars.isEmpty {
                        Section("Calendar") {
                            Menu {
                                ForEach(calendars.indices, id: \.self) { index in
                                    let item = calendars[index]
                                    let calendarID = (item.calendar as? FamilyMemberCalendar)?.calendarID ?? (item.calendar as? PersonalCalendar)?.calendarID
                                    Button {
                                        updateSelectedCalendarForMemberCombined(member: member, calendarID: calendarID, type: item.type)
                                        applyCalendarSelectionForSingleAttendee()
                                    } label: {
                                        HStack {
                                            Circle()
                                                .fill(Color.fromHex(item.colorHex))
                                                .frame(width: 10, height: 10)
                                            Text(item.name)
                                            if isCalendarSelectedForMemberCombined(member: member, calendarID: calendarID, type: item.type) {
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
                                        if let memberCal = (member.memberCalendars as? Set<FamilyMemberCalendar>)?.first(where: { $0.calendarID == selectedID }) {
                                            Text(memberCal.calendarName ?? "Unknown")
                                        } else if let personalCal = (member.personalCalendars as? Set<PersonalCalendar>)?.first(where: { $0.calendarID == selectedID }) {
                                            Text(personalCal.calendarName ?? "Unknown")
                                        } else {
                                            Text("Select Calendar")
                                        }
                                    } else {
                                        Text("Select Calendar")
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invitees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAttendeePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyCalendarSelectionForSingleAttendee()
                        showingAttendeePicker = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func allDialogs() -> some View {
        EmptyView()
            .confirmationDialog("Delete Event", isPresented: $showingInitialDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Event", role: .destructive) {
                    proceedAfterInitialConfirm()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, yyyy"
                let formattedDate = dateFormatter.string(from: upcomingEvent.startDate)

                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .short
                let formattedTime = timeFormatter.string(from: upcomingEvent.startDate)

                var message = ""
                if let location = upcomingEvent.location, !location.isEmpty {
                    message = "Are you sure you want to delete \"\(upcomingEvent.title)\"?\n\n📆 \(formattedDate) at \(formattedTime)\n📍 \(location)"
                } else {
                    message = "Are you sure you want to delete \"\(upcomingEvent.title)\"?\n\n📆 \(formattedDate) at \(formattedTime)"
                }
                return Text(message)
            }
            .confirmationDialog("Update Attendees", isPresented: $showingAttendeeEditScopeDialog, titleVisibility: .visible) {
                Button("Update for this event only") {
                    pendingAttendeeEditApplyToGroup = false
                    Task { await saveEvent(applyToGroup: false) }
                }
                Button("Update for all linked events") {
                    pendingAttendeeEditApplyToGroup = true
                    Task { await saveEvent(applyToGroup: true) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You've changed the attendees. Would you like to update attendees for this event only, or for all linked calendar copies?")
            }
            .confirmationDialog("Update Linked Calendars?", isPresented: $showingUpdateScopeDialog, titleVisibility: .visible) {
                if upcomingEvent.hasRecurrence {
                    Button("Update all linked calendars (this event only)") {
                        selectedEditSpan = .thisEvent
                        Task { await saveEvent(applyToGroup: true) }
                    }
                    Button("Update all linked calendars (this & future)") {
                        selectedEditSpan = .futureEvents
                        Task { await saveEvent(applyToGroup: true) }
                    }
                } else {
                    Button("Update all linked calendars") {
                        Task { await saveEvent(applyToGroup: true) }
                    }
                }
                Button("Update only this calendar") {
                    Task { await saveEvent(applyToGroup: false) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let linkedCalendars = getLinkedCalendarNames()
                var messageText = "This event exists in \(linkedCalendars.count) calendars"
                if !linkedCalendars.isEmpty {
                    messageText += ": " + linkedCalendars.joined(separator: ", ")
                }
                if !externalEditCalendars.isEmpty {
                    let external = externalEditCalendars.joined(separator: ", ")
                    messageText += "\n\nChanges were detected outside this app on: \(external). Overwrite them with your updates?"
                } else {
                    messageText += ". Do you want to apply these changes to all linked copies?"
                }
                return Text(messageText)
            }
            .confirmationDialog("Delete Scope", isPresented: $showingLinkedDeleteOptions, titleVisibility: .visible) {
                Button("Delete only in this calendar", role: .destructive) {
                    pendingDeleteScope = .singleCalendar
                    proceedWithDeletion()
                }
                Button("Delete in all linked calendars", role: .destructive) {
                    pendingDeleteScope = .allLinked
                    proceedWithDeletion()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if externalEditCalendars.isEmpty {
                    Text("This event is linked to \(linkedFamilyEvents.count) calendar(s). Where would you like to delete it?")
                } else {
                    let calendars = externalEditCalendars.joined(separator: ", ")
                    Text("This event is linked to other calendars. Some copies were edited outside this app (\(calendars)).\n\nWhere would you like to delete it?")
                }
            }
            .confirmationDialog("Deletion Type", isPresented: $showingDeletionTypeDialog, titleVisibility: .visible) {
                Button("Mark as Not Attending", role: .none) {
                    pendingDeleteActionType = .softDelete
                    proceedWithDeletionAfterType()
                }
                Button("Delete Permanently", role: .destructive) {
                    pendingDeleteActionType = .hardDelete
                    proceedWithDeletionAfterType()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("How would you like to handle this deletion?")
            }
            .confirmationDialog("Deletion Target", isPresented: $showingDeletionTargetDialog, titleVisibility: .visible) {
                Button("This event only", role: .none) {
                    pendingDeleteTarget = .singleOccurrence
                    proceedWithConfirmation()
                }
                Button("This and future events", role: .none) {
                    pendingDeleteTarget = .thisAndFuture
                    proceedWithConfirmation()
                }
                if pendingDeleteActionType == .hardDelete {
                    Button("All events in series", role: .destructive) {
                        pendingDeleteTarget = .allInSeries
                        proceedWithConfirmation()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Which occurrences would you like to delete?")
            }
            .confirmationDialog("Delete Event", isPresented: $showingDeletionConfirmDialog, titleVisibility: .visible) {
                Button(deletionContext?.actionButtonTitle ?? "Delete", role: deletionContext?.actionType == .hardDelete ? .destructive : .none) {
                    if pendingDeleteActionType == .softDelete {
                        showingDeletionReasonSheet = true
                    } else {
                        Task { await executeNewDeletion() }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let context = deletionContext {
                    Text(context.displayMessage)
                }
            }
            .sheet(isPresented: $showingDeletionReasonSheet) {
                deletionReasonSheet
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
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }

            .alert("Event Deleted", isPresented: $showingDeleteSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your event has been deleted successfully!")
            }
    }

    private func fetchCalendarId() {
        // Use the calendar ID directly from the event (it comes from EventKit)
        calendarId = upcomingEvent.calendarID
    }

    private func loadAvailableCalendars() {
        availableCalendars = CalendarManager.shared.fetchAvailableCalendars()
    }

    private func moveEventToCalendarIfNeeded(newCalendarId: String) -> Bool {
        let currentId = upcomingEvent.calendarID
        if newCalendarId == currentId {
            return true
        }

        let store = CalendarManager.shared.eventStore
        guard let event = store.event(withIdentifier: upcomingEvent.id),
              let targetCalendar = store.calendar(withIdentifier: newCalendarId) else {
            print("❌ Unable to move event - missing event or calendar")
            return false
        }

        do {
            event.calendar = targetCalendar
            try store.save(event, span: .thisEvent, commit: true)
            updateStoredCalendarId(newCalendarId)
            print("✅ Moved event to calendar \(targetCalendar.title)")
            return true
        } catch {
            print("❌ Failed to move event: \(error.localizedDescription)")
            return false
        }
    }

    private func updateStoredCalendarId(_ calendarId: String) {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)
        if let familyEvent = try? viewContext.fetch(fetchRequest).first {
            familyEvent.calendarId = calendarId
            try? viewContext.save()
        }
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

        // Return empty attendees if none found (don't show all members in notification)
        // The calendar filter will still work because it checks calendarId separately
        print("⚠️ No attendees found for event \(upcomingEvent.id) - notification will not list attendees")
        return ([], [])
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

    private func loadExistingTravelTime() {
        let ekEvent = CalendarManager.shared.fetchEventDetails(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate
        ) ?? CalendarManager.shared.fetchEventDetails(withIdentifier: upcomingEvent.id)

        guard let ekEvent else {
            travelTimeMinutes = nil
            return
        }

        travelTimeMinutes = CalendarManager.shared.getTravelTimeMinutes(from: ekEvent)
    }

    private func calendarIds(for member: FamilyMember) -> Set<String> {
        var ids: Set<String> = []
        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
            ids.formUnion(memberCals.compactMap { $0.calendarID })
        }
        if let personalCals = member.personalCalendars as? Set<PersonalCalendar> {
            ids.formUnion(personalCals.compactMap { $0.calendarID })
        }
        return ids
    }

    private func applyTravelTime(
        baseMinutes: Int?,
        driverExtraMinutes: Int?,
        to eventId: String,
        occurrenceStart: Date?,
        calendarId: String?,
        span: EKSpan,
        driverCalendarIds: Set<String>
    ) {
        guard let calendarId else { return }

        let totalMinutes: Int?
        if let base = baseMinutes {
            if let extra = driverExtraMinutes, driverCalendarIds.contains(calendarId) {
                totalMinutes = base + extra
            } else {
                totalMinutes = base
            }
        } else {
            totalMinutes = nil
        }

        guard let ekEvent = CalendarManager.shared.fetchEventDetails(withIdentifier: eventId, occurrenceStartDate: occurrenceStart) ?? CalendarManager.shared.fetchEventDetails(withIdentifier: eventId) else {
            return
        }

        _ = CalendarManager.shared.setTravelTime(on: ekEvent, travelTimeMinutes: totalMinutes, span: span)
    }

    private func applyTravelTimesToTargets(
        baseMinutes: Int?,
        driverExtraMinutes: Int?,
        driverCalendarIds: Set<String>,
        span: EKSpan,
        applyToGroup: Bool,
        currentCalendarId: String,
        currentOccurrence: Date
    ) {
        var targets: [(id: String, calendarId: String, occurrence: Date?)] = [
            (id: upcomingEvent.id, calendarId: currentCalendarId, occurrence: currentOccurrence)
        ]

        if applyToGroup || span == .futureEvents {
            for familyEvent in linkedFamilyEvents {
                guard let eid = familyEvent.eventIdentifier,
                      let calId = familyEvent.calendarId else { continue }
                targets.append((id: eid, calendarId: calId, occurrence: nil))
            }
        }

        var seen = Set<String>()
        for target in targets {
            let key = "\(target.id)|\(target.calendarId)"
            guard seen.insert(key).inserted else { continue }
            applyTravelTime(
                baseMinutes: baseMinutes,
                driverExtraMinutes: driverExtraMinutes,
                to: target.id,
                occurrenceStart: target.occurrence,
                calendarId: target.calendarId,
                span: span,
                driverCalendarIds: driverCalendarIds
            )
        }
    }

    private func driverCalendarId(for member: FamilyMember) -> String? {
        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar>,
           let auto = memberCals.first(where: { $0.isAutoLinked })?.calendarID {
            return auto
        }
        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar>,
           let first = memberCals.first?.calendarID {
            return first
        }
        if let personal = member.personalCalendars as? Set<PersonalCalendar>,
           let first = personal.first?.calendarID {
            return first
        }
        return nil
    }

    private func createDriverTravelEvents(
        driver: FamilyMember,
        calendarId: String,
        eventName: String,
        eventStartDate: Date,
        eventEndDate: Date,
        outboundMinutes: Int?,
        returnMinutes: Int?
    ) {
        if let outbound = outboundMinutes, outbound > 0 {
            let start = eventStartDate.addingTimeInterval(-Double(outbound) * 60)
            _ = CalendarManager.shared.createEvent(
                title: "Travel to \(eventName)",
                startDate: start,
                endDate: eventStartDate,
                location: locationAddress.isEmpty ? nil : locationAddress,
                notes: notes.isEmpty ? nil : notes,
                isAllDay: false,
                in: calendarId,
                alertOption: AlertOption.none
            )
            print("🚗 Created outbound travel for driver \(driver.name ?? "Unknown")")
        }

        if let ret = returnMinutes, ret > 0 {
            let end = eventEndDate.addingTimeInterval(Double(ret) * 60)
            _ = CalendarManager.shared.createEvent(
                title: "Return journey from \(eventName)",
                startDate: eventEndDate,
                endDate: end,
                location: locationAddress.isEmpty ? nil : locationAddress,
                notes: notes.isEmpty ? nil : notes,
                isAllDay: false,
                in: calendarId,
                alertOption: AlertOption.none
            )
            print("🚗 Created return journey for driver \(driver.name ?? "Unknown")")
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
            let results = try viewContext.fetch(fetchRequest)
            print("🔗 DEBUG: Found \(results.count) FamilyEvent(s) with identifier '\(upcomingEvent.id)'")

            if let current = results.first {
                var allLinked: [FamilyEvent] = [current]

                print("🔗 DEBUG: Current event groupId: \(current.eventGroupId?.uuidString ?? "nil")")

                if let groupId = current.eventGroupId {
                    let groupFetch = FamilyEvent.fetchRequest()
                    groupFetch.predicate = NSPredicate(format: "eventGroupId == %@", groupId as CVarArg)
                    let groupResults = try viewContext.fetch(groupFetch)
                    print("🔗 DEBUG: Found \(groupResults.count) events in group")
                    allLinked = groupResults
                }

                // Deduplicate and keep only entries with identifiers
                let keyed: [(String, FamilyEvent)] = allLinked.compactMap { familyEvent in
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
                print("🔗 DEBUG: No FamilyEvent found with eventIdentifier - checking if this event exists in CoreData at all")
                // Try fetching all FamilyEvents to understand data state
                let allFetch = FamilyEvent.fetchRequest()
                let allEvents = try viewContext.fetch(allFetch)
                print("🔗 DEBUG: Total FamilyEvents in database: \(allEvents.count)")
                linkedFamilyEvents = []
            }
        } catch {
            print("❌ Failed to load linked events: \(error.localizedDescription)")
            linkedFamilyEvents = []
        }
    }

    private var singleSelectedMember: FamilyMember? {
        guard !selectEveryone, selectedAttendees.count == 1, let id = selectedAttendees.first else { return nil }
        return familyMembers.first(where: { $0.objectID == id })
    }

    private func toggleAttendee(_ member: FamilyMember) {
        if selectedAttendees.contains(member.objectID) {
            selectedAttendees.remove(member.objectID)
        } else {
            selectedAttendees.insert(member.objectID)
        }
        selectEveryone = false
    }

    private func applyCalendarSelectionForSingleAttendee() {
        guard let member = singleSelectedMember else { return }
        if let selectedID = selectedMemberCalendars[member.objectID] {
            calendarId = selectedID
            return
        }
        if let selection = getSelectedCalendarForMemberCombined(member: member) {
            calendarId = selection.id
        }
    }

    private func loadExistingAttendees() {
        var attendeeIDs = Set<NSManagedObjectID>()
        let store = CalendarManager.shared.eventStore

        // Check if this was originally an "Everyone" event
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)
        if let familyEvent = try? viewContext.fetch(fetchRequest).first {
            selectEveryone = familyEvent.isSharedCalendarEvent
        }

        // First, find all linked event identifiers (events with the same title)
        var linkedEventIdentifiers = Set<String>()
        linkedEventIdentifiers.insert(upcomingEvent.id) // Include the main event

        // Scan all calendars to find linked events with the same title
        for member in familyMembers {
            if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
                for memberCal in memberCals {
                    if let calendarId = memberCal.calendarID {
                        if let calendar = store.calendar(withIdentifier: calendarId) {
                            let predicate = store.predicateForEvents(
                                withStart: upcomingEvent.startDate.addingTimeInterval(-86400),
                                end: upcomingEvent.startDate.addingTimeInterval(86400),
                                calendars: [calendar]
                            )
                            let events = store.events(matching: predicate).filter { $0.title == upcomingEvent.title }
                            for ekEvent in events {
                                if let eventId = ekEvent.eventIdentifier {
                                    linkedEventIdentifiers.insert(eventId)
                                }
                            }
                        }
                    }
                }
            }

            // Also check shared calendars for linked events
            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for sharedCal in sharedCals {
                    if let calendarId = sharedCal.calendarID {
                        if let calendar = store.calendar(withIdentifier: calendarId) {
                            let predicate = store.predicateForEvents(
                                withStart: upcomingEvent.startDate.addingTimeInterval(-86400),
                                end: upcomingEvent.startDate.addingTimeInterval(86400),
                                calendars: [calendar]
                            )
                            let events = store.events(matching: predicate).filter { $0.title == upcomingEvent.title }
                            for ekEvent in events {
                                if let eventId = ekEvent.eventIdentifier {
                                    linkedEventIdentifiers.insert(eventId)
                                }
                            }
                        }
                    }
                }
            }
        }

        print("📋 Found \(linkedEventIdentifiers.count) linked event(s) with matching title")

        // Now check which family members have any of these linked events in their calendars
        for member in familyMembers {
            if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
                for memberCal in memberCals {
                    if let calendarId = memberCal.calendarID {
                        if let calendar = store.calendar(withIdentifier: calendarId) {
                            let predicate = store.predicateForEvents(
                                withStart: upcomingEvent.startDate.addingTimeInterval(-86400),
                                end: upcomingEvent.startDate.addingTimeInterval(86400),
                                calendars: [calendar]
                            )
                            let events = store.events(matching: predicate)
                            for ekEvent in events {
                                if let eventId = ekEvent.eventIdentifier, linkedEventIdentifiers.contains(eventId) {
                                    attendeeIDs.insert(member.objectID)
                                    print("📋 Found linked event in \(member.name ?? "Unknown")'s calendar")
                                    break // Found in this member's calendar, move to next member
                                }
                            }
                        }
                    }
                }
            }

            // Skip checking shared calendars if already found in personal calendars
            if attendeeIDs.contains(member.objectID) {
                continue
            }

            // Also check shared calendars
            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for sharedCal in sharedCals {
                    if let calendarId = sharedCal.calendarID {
                        if let calendar = store.calendar(withIdentifier: calendarId) {
                            let predicate = store.predicateForEvents(
                                withStart: upcomingEvent.startDate.addingTimeInterval(-86400),
                                end: upcomingEvent.startDate.addingTimeInterval(86400),
                                calendars: [calendar]
                            )
                            let events = store.events(matching: predicate)
                            for ekEvent in events {
                                if let eventId = ekEvent.eventIdentifier, linkedEventIdentifiers.contains(eventId) {
                                    attendeeIDs.insert(member.objectID)
                                    print("📋 Found linked event in shared calendar for \(member.name ?? "Unknown")")
                                    break // Found in shared calendar, move to next member
                                }
                            }
                        }
                    }
                }
            }
        }

        selectedAttendees = attendeeIDs
        originalAttendees = attendeeIDs  // Track the original attendees for comparison
        print("📋 Loaded \(selectedAttendees.count) total attendees from all linked events")
        applyCalendarSelectionForSingleAttendee()
    }

    private func applyDriverChange(span: EKSpan) {
        selectedDriver = pendingDriverChange
        pendingDriverChange = nil
        pendingDriverChangeSpan = span

    }

    private func getLinkedCalendarNames() -> [String] {
        return linkedFamilyEvents.compactMap { familyEvent in
            // Try to get the calendar title from EventKit
            let eventKit = CalendarManager.shared.eventStore
            if let calendarId = familyEvent.calendarId,
               let calendar = eventKit.calendar(withIdentifier: calendarId) {
                return calendar.title
            }
            return nil
        }
    }

    private func handleSaveTapped() {
        // Check if attendees have changed
        let attendeesChanged = selectedAttendees != originalAttendees

        if attendeesChanged && linkedFamilyEvents.count > 1 {
            // Attendees changed and there are linked events - ask about scope
            showingAttendeeEditScopeDialog = true
            return
        }

        externalEditCalendars = []

        if linkedFamilyEvents.count > 1 {
            // Found linked events via CoreData
            externalEditCalendars = detectExternalChanges(in: linkedFamilyEvents)
            showingUpdateScopeDialog = true
        } else {
            // No CoreData linked events found, check EventKit for events with same title in other calendars
            checkForLinkedEventsInEventKit()
        }
    }

    private func checkForLinkedEventsInEventKit() {
        // Get all family member calendars
        var allMemberCalendars: [(calendarId: String, calendarName: String)] = []

        for member in familyMembers {
            if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
                for cal in memberCals {
                    if let calId = cal.calendarID, let calName = cal.calendarName {
                        allMemberCalendars.append((calId, calName))
                    }
                }
            }
        }

        // Also check shared calendars
        if let sharedCals = familyMembers.first?.sharedCalendars as? Set<SharedCalendar> {
            for sharedCal in sharedCals {
                if let calId = sharedCal.calendarID, let calName = sharedCal.calendarName {
                    allMemberCalendars.append((calId, calName))
                }
            }
        }

        // Search for linked events in other calendars
        var foundLinkedCalendars: [String] = []

        for (calendarId, calendarName) in allMemberCalendars {
            let store = CalendarManager.shared.eventStore
            if let calendar = store.calendar(withIdentifier: calendarId) {
                let predicate = store.predicateForEvents(withStart: upcomingEvent.startDate.addingTimeInterval(-86400), end: upcomingEvent.startDate.addingTimeInterval(86400), calendars: [calendar])
                let events = store.events(matching: predicate).filter { $0.title == upcomingEvent.title }

                for ekEvent in events {
                    if ekEvent.eventIdentifier != upcomingEvent.id {
                        foundLinkedCalendars.append(calendarName)
                        print("🔗 Found linked event in calendar: \(calendarName)")
                        break // Only add each calendar once
                    }
                }
            }
        }

        if !foundLinkedCalendars.isEmpty {
            // Found linked events - show the dialog
            let calendars = foundLinkedCalendars
            Task { @MainActor in
                self.externalEditCalendars = calendars
                self.showingUpdateScopeDialog = true
            }
            print("🔗 Found \(foundLinkedCalendars.count) calendar(s) with linked event")
        } else {
            // No linked events found - save normally
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
        meetingLink: String?,
        isAllDay: Bool,
        recurrenceRule: EKRecurrenceRule?,
        span: EKSpan,
        alertOption: AlertOption?
    ) async {
        // First try to use FamilyEvent records from CoreData
        let otherEvents = linkedFamilyEvents.filter { $0.eventIdentifier != upcomingEvent.id }

        // If no other FamilyEvent records found, search EventKit directly for this event in all family member calendars
        if otherEvents.isEmpty {
            print("🔗 No FamilyEvent records found for linked events. Searching EventKit...")

            // Get all family member calendars
            var allMemberCalendars: [(calendarId: String, member: FamilyMember?)] = []

            for member in familyMembers {
                if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
                    for cal in memberCals {
                        if let calId = cal.calendarID {
                            allMemberCalendars.append((calId, member))
                        }
                    }
                }
            }

            // Also check shared calendars
            if let sharedCals = familyMembers.first?.sharedCalendars as? Set<SharedCalendar> {
                for sharedCal in sharedCals {
                    if let calId = sharedCal.calendarID {
                        allMemberCalendars.append((calId, nil))
                    }
                }
            }

            // Search each calendar for the event by title
            for (calendarId, _) in allMemberCalendars {
                let store = CalendarManager.shared.eventStore
                if let calendar = store.calendar(withIdentifier: calendarId) {
                    let predicate = store.predicateForEvents(withStart: upcomingEvent.startDate.addingTimeInterval(-86400), end: upcomingEvent.startDate.addingTimeInterval(86400), calendars: [calendar])
                    let events = store.events(matching: predicate).filter { $0.title == upcomingEvent.title }

                    for ekEvent in events {
                        if ekEvent.eventIdentifier != upcomingEvent.id {
                            let eventTitle = ekEvent.title ?? "Untitled event"
                            let eventId = ekEvent.eventIdentifier ?? "unknown"
                            let calendarTitle = calendar.title
                            print("🔗 Found linked event '\(eventTitle)' with ID '\(eventId)' in calendar '\(calendarTitle)'")

                            // Use the linked event's occurrence date, not the original event's date
                            guard let linkedEventOccurrenceDate = ekEvent.startDate else { continue }

                            let success = CalendarManager.shared.updateEvent(
                                withIdentifier: ekEvent.eventIdentifier,
                                occurrenceStartDate: linkedEventOccurrenceDate,
                                in: calendarId,
                                title: title,
                                startDate: startDate,
                                endDate: endDate,
                                location: location,
                                notes: notes,
                                meetingLink: meetingLink,
                                isAllDay: isAllDay,
                                recurrenceRule: recurrenceRule,
                                updateRecurrence: true,
                                span: span,
                                alertOption: alertOption
                            )

                            if success {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateStyle = .medium
                                dateFormatter.timeStyle = .short
                                let occurrenceDateStr = dateFormatter.string(from: linkedEventOccurrenceDate)
                                print("✅ Updated linked event in calendar: \(calendarTitle) (occurrence: \(occurrenceDateStr))")
                            } else {
                                print("⚠️ Failed to update linked event in calendar: \(calendarTitle)")
                            }
                        }
                    }
                }
            }
            return
        }

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
                    meetingLink: meetingLink,
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
        let driverNotAttending: Bool = {
            guard let driver = driverFamilyMember else { return false }
            return !selectEveryone && !selectedAttendees.contains(driver.objectID)
        }()

        // Use eventDate and eventEndDate directly
        let eventStartDate = eventDate
        let finalEventEndDate = eventEndDate

        print("📝 Event details:")
        print("   Title: \(title)")
        print("   Start: \(eventStartDate)")
        print("   End: \(finalEventEndDate)")
        
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
        
        print("   Location: \(locationValue ?? "(none)")")

        let recurrenceRule = selectedRecurrenceRule(startDate: eventStartDate)
        let isExistingRecurring = upcomingEvent.hasRecurrence
        let isCreatingRecurrence = !upcomingEvent.hasRecurrence && recurrenceRule != nil
        let updateSpan: EKSpan
        if isCreatingRecurrence {
            updateSpan = .futureEvents
        } else if isExistingRecurring {
            updateSpan = selectedEditSpan
        } else if recurrenceRule != nil {
            updateSpan = .futureEvents
        } else {
            updateSpan = .thisEvent
        }

        if calId != upcomingEvent.calendarID {
            let moved = moveEventToCalendarIfNeeded(newCalendarId: calId)
            if !moved {
                await MainActor.run {
                    errorMessage = "Could not move the event to the selected calendar. Please check calendar permissions and try again."
                    showingError = true
                    isSaving = false
                }
                return
            }
        }

        let success = CalendarManager.shared.updateEvent(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate,
            in: calId,
            title: title,
            startDate: eventStartDate,
            endDate: finalEventEndDate,
            location: locationValue,
            notes: notes.isEmpty ? nil : notes,
            meetingLink: meetingLinkValue,
            isAllDay: isAllDay,
            recurrenceRule: recurrenceRule,
            updateRecurrence: true,
            span: updateSpan,
            alertOption: alertOption
        )

        if success {
            let baseTravelMinutes = travelTimeMinutes
            let driverExtraMinutes: Int? = (driverNotAttending && driverFamilyMember != nil) ? driverTravelTimeMinutes : nil
            let driverCalendarIds: Set<String> = driverFamilyMember.map { calendarIds(for: $0) } ?? []

            if applyToGroup {
                await propagateUpdateToLinkedEvents(
                    title: title,
                    startDate: eventStartDate,
                    endDate: finalEventEndDate,
                    location: locationValue,
                    notes: notes.isEmpty ? nil : notes,
                    meetingLink: meetingLinkValue,
                    isAllDay: isAllDay,
                    recurrenceRule: recurrenceRule,
                    span: updateSpan,
                    alertOption: alertOption
                )
            }

            applyTravelTimesToTargets(
                baseMinutes: baseTravelMinutes,
                driverExtraMinutes: driverExtraMinutes,
                driverCalendarIds: driverCalendarIds,
                span: updateSpan,
                applyToGroup: applyToGroup,
                currentCalendarId: calId,
                currentOccurrence: eventStartDate
            )

            if driverNotAttending,
               let driver = driverFamilyMember,
               let driverCalId = driverCalendarId(for: driver) {
                createDriverTravelEvents(
                    driver: driver,
                    calendarId: driverCalId,
                    eventName: title,
                    eventStartDate: eventStartDate,
                    eventEndDate: finalEventEndDate,
                    outboundMinutes: baseTravelMinutes,
                    returnMinutes: driverTravelTimeMinutes
                )
            }

            // Update CoreData record if needed
            updateFamilyEvent()

            // Save checklist changes
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
            familyEvent.calendarId = calendarId ?? upcomingEvent.calendarID
            familyEvent.isSharedCalendarEvent = selectEveryone

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
                }
            } else {
                // No driver selected - clear the driver
                familyEvent.driver = nil
                familyEvent.driverFamilyMemberId = nil
            }

            // Update attendees
            if selectEveryone {
                familyEvent.attendees = NSSet(array: Array(familyMembers))
                print("📋 Set all family members as attendees")
            } else {
                let selectedAttendeesArray = familyMembers.filter { selectedAttendees.contains($0.objectID) }
                familyEvent.attendees = NSSet(array: selectedAttendeesArray)
                print("📋 Set \(selectedAttendeesArray.count) attendees")
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

    private func handleDeleteTap() {
        pendingDeleteScope = .singleCalendar
        pendingDeleteActionType = .softDelete
        pendingDeleteTarget = .singleOccurrence
        externalEditCalendars = []

        // Show initial confirmation with event details
        showingInitialDeleteConfirm = true
    }

    private func proceedAfterInitialConfirm() {
        // Step 1: Check if multiple linked copies exist
        if linkedFamilyEvents.count > 1 {
            externalEditCalendars = detectExternalChanges(in: linkedFamilyEvents)
            showingLinkedDeleteOptions = true
            return
        }

        // Step 2: Single calendar - go straight to deletion type
        proceedWithDeletion()
    }

    private func proceedWithDeletion() {
        // Show deletion type dialog: soft delete (mark not attending) vs hard delete (permanent)
        showingDeletionTypeDialog = true
    }

    private func proceedWithDeletionAfterType() {
        // If recurring and hard delete, show target dialog
        if upcomingEvent.hasRecurrence {
            showingDeletionTargetDialog = true
        } else {
            // Non-recurring or soft delete: go straight to confirmation
            proceedWithConfirmation()
        }
    }

    private func proceedWithConfirmation() {
        // Show final confirmation dialog with detailed message
        showingDeletionConfirmDialog = true
    }

    private func executeNewDeletion() async {
        await MainActor.run {
            isSaving = true
        }

        let success = await LinkedEventDeletionHandler.shared.executeLinkedEventDeletion(
            scope: pendingDeleteScope,
            target: pendingDeleteTarget,
            actionType: pendingDeleteActionType,
            primaryEvent: upcomingEvent,
            linkedFamilyEvents: linkedFamilyEvents,
            affectedMember: nil,
            deletionReason: deletionReason.isEmpty ? nil : deletionReason,
            viewContext: viewContext
        )

        if success {
            await MainActor.run {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                showingDeleteSuccess = true
            }

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

            // Travel Time
            QuickRow(icon: "car.fill", title: "Travel Time", showChevron: false, color: .orange) {
                Button(action: { showingTravelTimePicker.toggle() }) {
                    if let minutes = travelTimeMinutes {
                        Text("\(minutes) min")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("Add")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            if showingTravelTimePicker {
                Divider().padding(.leading, 44)

                VStack(spacing: 12) {
                    // Preset options
                    HStack(spacing: 8) {
                        ForEach([15, 30, 45, 60], id: \.self) { minutes in
                            Button(action: { travelTimeMinutes = minutes }) {
                                Text("\(minutes)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(travelTimeMinutes == minutes ? Color.orange.opacity(0.3) : Color.gray.opacity(0.1))
                                    .foregroundColor(travelTimeMinutes == minutes ? .orange : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Custom input
                    HStack(spacing: 12) {
                        Text("Custom:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("Minutes", value: $travelTimeMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)

                        Button(action: { travelTimeMinutes = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGray6))
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
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var whoCard: some View {
        VStack(spacing: 0) {
            QuickRow(icon: "person.2.fill", title: "Invitees", showChevron: true, color: .green) {
                Button {
                    showingAttendeePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(attendeesSummary)
                            .foregroundColor(attendeesSummary == "None" ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().padding(.leading, 44)

            QuickRow(icon: "calendar", title: "Calendar", showChevron: true, color: .red) {
                let currentColor = CalendarManager.shared
                    .getCalendar(withIdentifier: calendarId ?? upcomingEvent.calendarID)?
                    .cgColor
                let color = currentColor.map { Color(UIColor(cgColor: $0)) } ?? Color(uiColor: upcomingEvent.calendarColor)

                Menu {
                    ForEach(relevantCalendarOptions, id: \.id) { calendar in
                        Button {
                            calendarId = calendar.id
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(uiColor: calendar.color))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                                if calendar.id == (calendarId ?? upcomingEvent.calendarID) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                        Text(selectedCalendarName)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().padding(.leading, 44)

            // Driver
            QuickRow(icon: "car.fill", title: "Driver", showChevron: true, color: .orange) {
                Menu {
                    Button(action: {
                        if selectedDriver != nil && upcomingEvent.hasRecurrence {
                            pendingDriverChange = nil
                            showingRecurringDriverChangeOptions = true
                        } else {
                            selectedDriver = nil
                        }
                    }) {
                        Label("None", systemImage: selectedDriver == nil ? "checkmark" : "")
                    }
                    Divider()
                    ForEach(allAvailableDrivers, id: \.id) { driverWrapper in
                        Button(action: {
                            if selectedDriver?.id != driverWrapper.id && upcomingEvent.hasRecurrence {
                                pendingDriverChange = driverWrapper
                                showingRecurringDriverChangeOptions = true
                            } else {
                                selectedDriver = driverWrapper
                            }
                        }) {
                            Label(driverWrapper.name, systemImage: selectedDriver?.id == driverWrapper.id ? "checkmark" : "")
                        }
                    }
                } label: {
                    Text(selectedDriver?.name ?? "None")
                        .foregroundColor(selectedDriver == nil ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if let driver = selectedDriver, driver.isFamilyMember {
                Divider().padding(.leading, 44)
                QuickRow(icon: "timer", title: "Return Journey", showChevron: true, color: .orange) {
                    Menu {
                        ForEach([5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { minutes in
                            Button(action: { driverTravelTimeMinutes = minutes }) {
                                Label("\(minutes) min", systemImage: driverTravelTimeMinutes == minutes ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Text("\(driverTravelTimeMinutes) min")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            Divider().padding(.leading, 44)

            // Alert
            QuickRow(icon: "bell.fill", title: "Alert", showChevron: true, color: .red) {
                Menu {
                    ForEach(AlertOption.allCases, id: \.self) { option in
                        Button(action: { alertOption = option }) {
                            Label(option.rawValue, systemImage: alertOption == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    Text(alertOption.rawValue)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var notesCard: some View {
        VStack(spacing: 0) {
            QuickRow(icon: "note.text", title: "Notes", showChevron: false, color: .yellow) {
                 TextField("Add notes", text: $notes, axis: .vertical)
                     .lineLimit(3...6)
                     .multilineTextAlignment(.leading)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var whenCard: some View {
        VStack(spacing: 0) {
            // All-day
            QuickRow(icon: "clock.fill", title: "All-day", showChevron: false, color: .blue) {
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
                    HStack {
                        Text(eventDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(activeTimePicker == .startDate ? .blue : .primary)
                            .padding(6)
                            .background(activeTimePicker == .startDate ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .onTapGesture { togglePicker(.startDate) }
                        
                        if !isAllDay {
                            Text(eventDate.formatted(date: .omitted, time: .shortened))
                                .foregroundColor(activeTimePicker == .startTime ? .blue : .primary)
                                .padding(6)
                                .background(activeTimePicker == .startTime ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                                .onTapGesture { togglePicker(.startTime) }
                        }
                    }
                }
                
                if activeTimePicker == .startDate {
                    DatePicker("", selection: $eventDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                }
                
                if activeTimePicker == .startTime && !isAllDay {
                    DatePicker("", selection: $eventDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Ends
            VStack(spacing: 0) {
                QuickRow(icon: "", title: "Ends", showChevron: false) {
                    HStack {
                        Text(eventEndDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(activeTimePicker == .endDate ? .blue : .primary)
                            .padding(6)
                            .background(activeTimePicker == .endDate ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .onTapGesture { togglePicker(.endDate) }
                        
                        if !isAllDay {
                            Text(eventEndDate.formatted(date: .omitted, time: .shortened))
                                .foregroundColor(activeTimePicker == .endTime ? .blue : .primary)
                                .padding(6)
                                .background(activeTimePicker == .endTime ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                                .onTapGesture { togglePicker(.endTime) }
                        }
                    }
                }
                
                if activeTimePicker == .endDate {
                    DatePicker("", selection: $eventEndDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                }
                
                if activeTimePicker == .endTime && !isAllDay {
                    DatePicker("", selection: $eventEndDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Divider().padding(.leading, 44)
            
            // Repeat
            QuickRow(icon: "repeat", title: "Repeat", showChevron: true, color: .gray) {
                Menu {
                    ForEach(RepeatOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            handleRepeatSelection(option)
                        }
                    }
                } label: {
                    Text(repeatOption == .custom ? (recurrenceConfig.isEnabled ? recurrenceConfig.summary(anchor: eventDate) : "Custom") : repeatOption.rawValue)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            

        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .onChange(of: eventDate) { _, newValue in
            // Maintain duration when start date changes
            eventEndDate = newValue.addingTimeInterval(eventDuration)
        }
        .onChange(of: eventEndDate) { _, newValue in
             // Update duration when end date changes
             eventDuration = newValue.timeIntervalSince(eventDate)
        }
    }
    private func createEventForDriver(_ driver: DriverWrapper) {
        // Create a new event for the driver using the current calendar
        // Note: startTime and endTime already contain the full date and time
        let driverEventTitle = "\(eventTitle) - \(driver.name)'s drive"

        if let calendarId = calendarId {
            let eventId = CalendarManager.shared.createEvent(
                title: driverEventTitle,
                startDate: eventDate,
                endDate: eventEndDate,
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
        meetingLink: nil,
        startDate: Date().addingTimeInterval(3600),
        endDate: Date().addingTimeInterval(7200),
        calendarID: "demo-calendar",
        calendarColor: UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1.0),
        calendarTitle: "Work",
        hasRecurrence: false, recurrenceRule: nil, travelTimeMinutes: nil, isAllDay: false
    )

    EditEventView(upcomingEvent: testEvent)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
