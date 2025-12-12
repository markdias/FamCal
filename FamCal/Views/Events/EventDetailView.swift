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
    @State private var checklistRefresh = false
    @State private var showingAddChecklistItem = false
    @State private var newChecklistTitle: String = ""
    @State private var newChecklistHasDueDate = false
    @State private var newChecklistDueDate = Date()
    @State private var showingChecklistRecurringDialog = false
    @State private var pendingChecklistItem: (title: String, dueDate: Date?)? = nil

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
        sortDescriptors: [NSSortDescriptor(keyPath: \Checklist.createdAt, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil")
    )
    private var allChecklists: FetchedResults<Checklist>

    private var eventChecklist: Checklist? {
        let eventId = event.id
        print("🔍 Looking for checklist for event: \(event.title), allChecklists count: \(allChecklists.count)")

        let result = allChecklists.first { checklist in
            guard let checklistEventId = checklist.eventIdentifier else { return false }
            let match = ChecklistManager.canMatchEventIdentifier(
                checklistEventId,
                toEventKitID: eventId,
                eventTitle: event.title,
                startDate: event.startDate,
                calendarID: event.calendarID
            )
            return match
        }

        if let result = result {
            print("✅ Found checklist with \(result.items?.count ?? 0) items")
        } else {
            print("❌ No checklist found for event")
        }
        return result
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

    // MARK: - Compact Layout Pieces

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                Label {
                    Text(Self.fullDateFormatter.string(from: event.startDate))
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }

                Label {
                    Text("\(Self.timeFormatter.string(from: event.startDate)) – \(Self.timeFormatter.string(from: event.endDate))")
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                }
            }
            .font(.subheadline)

            if let location = event.location, !location.isEmpty {
                Label {
                    Text(location)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundColor(.red)
                }
                .font(.subheadline)
                .onTapGesture {
                    MapsUtility.openLocation(location, in: defaultMapsApp)
                }
            }

            if event.hasRecurrence {
                Label {
                    Text(event.recurrenceRule.map { formatRecurrenceRule($0) } ?? "Repeats")
                } icon: {
                    Image(systemName: "repeat")
                        .foregroundColor(.purple)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .contextMenu {
            Button(action: { duplicateEvent(event) }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

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
    }

    private var quickActionsCard: some View {
        VStack(spacing: 0) {
            calendarRow
            Divider().padding(.leading, 44)
            driverRow
            Divider().padding(.leading, 44)
            alertRow
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var calendarRow: some View {
        quickRow(icon: "calendar.badge.clock", title: "Calendar", showsChevron: false) {
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
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(uiColor: event.calendarColor))
                        .frame(width: 10, height: 10)
                    Text(event.calendarTitle)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var driverRow: some View {
        quickRow(icon: "car.fill", title: "Driver", showsChevron: false) {
            Menu {
                Button(action: { selectedDriver = nil }) {
                    HStack {
                        Text("None")
                        if selectedDriver == nil { Image(systemName: "checkmark") }
                    }
                }

                if !allAvailableDrivers.isEmpty {
                    Divider()
                    ForEach(allAvailableDrivers, id: \.id) { driverWrapper in
                        Button(action: {
                            selectedDriver = driverWrapper
                            if case .familyMember(_) = driverWrapper {
                                driverToCreateEventFor = driverWrapper
                                showingCreateEventForDriverAlert = true
                            }
                        }) {
                            HStack {
                                Text(driverWrapper.name)
                                if selectedDriver?.id == driverWrapper.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedDriver?.name ?? "None")
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onChange(of: selectedDriver) { _, _ in
            saveDriver()
        }
    }

    private var alertRow: some View {
        quickRow(icon: "bell.fill", title: "Alert", showsChevron: false, verticalPadding: 8) {
            AlertMenuButton(
                currentAlert: alerts.first,
                onSelect: { updateAlert(minutes: $0) }
            )
        }
    }

    private func quickRow<Content: View>(
        icon: String,
        title: String,
        showsChevron: Bool = true,
        verticalPadding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            content()
                .font(.subheadline)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle())
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Checklist")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if checklistProgress.total > 0 {
                    Text("\(checklistProgress.completed)/\(checklistProgress.total)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }

            if checklistItems.isEmpty {
                Text("No checklist items yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(checklistItems, id: \.objectID) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.completed ? .green : .gray)
                                .onTapGesture {
                                    toggleChecklistItem(item)
                                }
                            Text(item.title ?? "")
                                .strikethrough(item.completed)
                                .foregroundColor(item.completed ? .secondary : .primary)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            if let due = item.dueDate {
                                Text(dueDateFormatter.string(from: due))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Button(action: {
                                deleteChecklistItem(item)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleChecklistItem(item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteChecklistItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Button(action: { showingAddChecklistItem = true }) {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .id(checklistRefresh)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var linkedCalendarsCompact: some View {
        Group {
            if let calendars = getLinkedCalendars(for: event), calendars.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Linked calendars")
                        .font(.subheadline.weight(.semibold))
                    Text("Copies on other family calendars")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(calendars, id: \.self) { name in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: 10, height: 10)
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }

    private var mapSection: some View {
        Group {
            if locationCoordinates != nil || isLoadingLocation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)

                    if locationCoordinates != nil {
                        Map(position: .constant(.region(mapRegion)))
                            .frame(height: 150)
                            .cornerRadius(12)
                    } else if isLoadingLocation {
                        HStack {
                            ProgressView()
                                .tint(Color(red: 0.33, green: 0.33, blue: 0.33))
                            Text("Loading map...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var deleteButton: some View {
        Button(action: handleDeleteTap) {
            Text("Delete Event")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(10)
        }
    }

    private var checklistItems: [ChecklistItem] {
        guard let checklist = eventChecklist,
              let items = checklist.items as? Set<ChecklistItem> else {
            return []
        }
        let filtered = items
            .filter { $0.deletedAt == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
        return filtered
    }

    private var checklistProgress: (completed: Int, total: Int) {
        let total = checklistItems.count
        let completed = checklistItems.filter { $0.completed }.count
        print("📊 checklistProgress calculated: \(completed)/\(total) items")
        return (completed, total)
    }

    private func toggleChecklistItem(_ item: ChecklistItem) {
        do {
            try ChecklistManager.shared.toggleItemCompletion(item, completedBy: UUID())

            // Trigger view refresh to update UI
            checklistRefresh.toggle()

            // Sync only this item's update to Supabase (targeted operation)
            Task {
                await ChecklistManager.shared.syncItemUpdate(item)
            }
        } catch {
            print("❌ Error toggling checklist item: \(error)")
        }
    }

    private func deleteChecklistItem(_ item: ChecklistItem) {
        ChecklistManager.shared.deleteItem(item)

        // Trigger view refresh to update UI
        checklistRefresh.toggle()

        // Sync only this item's deletion to Supabase (targeted operation)
        Task {
            await ChecklistManager.shared.syncItemDeletion(item)
        }
    }

    private func addChecklistItem() {
        let trimmed = newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let dueDate: Date? = newChecklistHasDueDate ? newChecklistDueDate : nil

        // Check if this is a recurring event
        if event.hasRecurrence {
            // Store pending item and show dialog
            pendingChecklistItem = (title: trimmed, dueDate: dueDate)
            showingChecklistRecurringDialog = true
        } else {
            // Single event - add directly
            performAddChecklistItem(title: trimmed, dueDate: dueDate, toAllFuture: false)
        }
    }

    private func performAddChecklistItem(title: String, dueDate: Date?, toAllFuture: Bool) {
        do {
            // Ensure checklist exists
            let targetChecklist: Checklist
            if let existing = eventChecklist {
                targetChecklist = existing
            } else {
                // For recurring events: use eventGroupId (created once per recurrence group)
                // For single events: use stable identifier based on title+date+calendar (works cross-device)
                let eventIdentifier: String
                if event.hasRecurrence {
                    // Recurring events use device-specific ID + UUID group
                    eventIdentifier = event.id
                } else {
                    // Single events use stable hash-based ID for cross-device compatibility
                    eventIdentifier = ChecklistManager.generateStableEventIdentifier(
                        title: event.title,
                        startDate: event.startDate,
                        calendarID: event.calendarID
                    )
                }
                let groupId = event.hasRecurrence ? UUID() : nil
                targetChecklist = try ChecklistManager.shared.getOrCreateChecklist(for: eventIdentifier, eventGroupId: groupId, eventTitle: event.title)
            }

            let nextSortOrder = Int16((targetChecklist.items as? Set<ChecklistItem>)?.count ?? 0)

            _ = try ChecklistManager.shared.addItem(
                to: targetChecklist,
                title: title,
                dueDate: dueDate,
                sortOrder: nextSortOrder
            )

            newChecklistTitle = ""
            newChecklistHasDueDate = false
            showingAddChecklistItem = false

            // Refresh the Core Data context to ensure FetchRequest updates
            // This forces the FetchRequest to re-evaluate and display the new item
            viewContext.refresh(targetChecklist, mergeChanges: true)

            // Small delay to allow Core Data to propagate changes to FetchRequest
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Trigger view refresh to update UI
                checklistRefresh.toggle()
            }

            // For new items, sync the entire checklist to ensure parent exists in Supabase first
            Task {
                await ChecklistManager.shared.syncChecklistsToSupabase()
            }

            // Apply to all future occurrences if requested
            if toAllFuture {
                applyChecklistItemToFutureOccurrences(title: title, dueDate: dueDate)
            }
        } catch {
            print("❌ Error adding checklist item: \(error)")
        }
    }

    private func applyChecklistItemToFutureOccurrences(title: String, dueDate: Date?) {
        // Find all future occurrences of this recurring event
        let eventStore = EKEventStore()

        guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
            return
        }

        guard ekEvent.hasRecurrenceRules else {
            return
        }

        // Get all occurrences of this recurring event that are STRICTLY AFTER the current event
        // Start from tomorrow to exclude today's event
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate) ?? event.startDate
        let occurrences = eventStore.events(matching: eventStore.predicateForEvents(
            withStart: tomorrow,
            end: Calendar.current.date(byAdding: .year, value: 2, to: event.startDate) ?? Date.distantFuture,
            calendars: nil
        ))

        // For each future occurrence, find or create its checklist and add the item
        for occurrence in occurrences {
            do {
                // Get or create checklist for this occurrence
                let targetChecklist = try ChecklistManager.shared.getOrCreateChecklist(
                    for: occurrence.eventIdentifier,
                    eventGroupId: eventChecklist?.eventGroupId,
                    eventTitle: occurrence.title
                )

                let nextSortOrder = Int16((targetChecklist.items as? Set<ChecklistItem>)?.count ?? 0)

                // Add the same item to this occurrence
                _ = try ChecklistManager.shared.addItem(
                    to: targetChecklist,
                    title: title,
                    dueDate: dueDate,
                    sortOrder: nextSortOrder
                )
            } catch {
                print("❌ Error adding checklist item to future occurrence: \(error)")
            }
        }

        // Sync all checklists to Supabase
        Task {
            await ChecklistManager.shared.syncChecklistsToSupabase()
        }
    }

    private var dueDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    private var addChecklistSheet: some View {
        NavigationView {
            Form {
                // Event information section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(dueDateFormatter.string(from: event.startDate))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Item Details")) {
                    TextField("Title", text: $newChecklistTitle)
                    Toggle("Set due date", isOn: $newChecklistHasDueDate)
                    if newChecklistHasDueDate {
                        DatePicker("Due", selection: $newChecklistDueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Add Checklist Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddChecklistItem = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addChecklistItem()
                        showingAddChecklistItem = false
                    }
                    .disabled(newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    titleCard
                    quickActionsCard
                    checklistSection
                    linkedCalendarsCompact
                    mapSection
                    deleteButton
                }
                .padding(.horizontal, 14)
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
                loadAvailableCalendars()
                fetchEventDetails()

                if let location = event.location, !location.isEmpty {
                    geocodeLocation(location, zoom: 0.002)
                }

                fetchDriver()

                // Sync checklists from Supabase
                Task {
                    await SupabaseDataManager.shared.syncChecklistsFromSupabase(for: [event.id])
                    // Refresh the view to pick up newly synced checklist items
                    await MainActor.run {
                        checklistRefresh.toggle()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                fetchEventDetails()
            }
            .onDisappear {
                geocodeTask?.cancel()
            }
            .confirmationDialog("Add Checklist Item", isPresented: $showingChecklistRecurringDialog, titleVisibility: .visible) {
                Button("This Event Only") {
                    if let item = pendingChecklistItem {
                        performAddChecklistItem(title: item.title, dueDate: item.dueDate, toAllFuture: false)
                        pendingChecklistItem = nil
                    }
                }
                Button("All Future Events") {
                    if let item = pendingChecklistItem {
                        performAddChecklistItem(title: item.title, dueDate: item.dueDate, toAllFuture: true)
                        pendingChecklistItem = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingChecklistItem = nil
                }
            } message: {
                Text("Would you like to add this checklist item to just this event or all future occurrences?")
            }
            .sheet(isPresented: $showingAddChecklistItem) {
                addChecklistSheet
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
            var results = try viewContext.fetch(fetchRequest)

            if let current = results.first, let groupId = current.eventGroupId {
                let groupFetch = FamilyEvent.fetchRequest()
                groupFetch.predicate = NSPredicate(format: "eventGroupId == %@", groupId as CVarArg)
                let groupResults = try viewContext.fetch(groupFetch)
                results.append(contentsOf: groupResults)
            } else if results.isEmpty, let groupUUID = UUID(uuidString: eventId) {
                // Fallback: if the incoming ID is actually the group ID, fetch by group
                let groupFetch = FamilyEvent.fetchRequest()
                groupFetch.predicate = NSPredicate(format: "eventGroupId == %@", groupUUID as CVarArg)
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
            HStack(spacing: 6) {
                Text(currentAlertText)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .cornerRadius(8)
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
