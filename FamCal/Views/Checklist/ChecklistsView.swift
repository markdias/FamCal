//
//  ChecklistsView.swift
//  FamCal
//
//  Created by Claude on 2025-12-11.
//

import SwiftUI
import CoreData
import EventKit

struct ChecklistsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: Checklist.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Checklist.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt == nil")
    )
    private var allChecklists: FetchedResults<Checklist>

    @State private var completionFilter: CompletionFilter = .all
    @State private var showingAddItemSheet = false
    @State private var newItemTitle: String = ""
    @State private var newItemHasDueDate = false
    @State private var newItemDueDate = Date()
    @State private var editingItem: ChecklistItem?
    @State private var showingEditSheet = false

    enum CompletionFilter: String, CaseIterable, Hashable {
        case all = "All"
        case completed = "Completed"
        case uncompleted = "Uncompleted"
    }

    private var theme: AppTheme {
        themeManager.selectedTheme
    }

    // MARK: - Computed Properties

    /// Get all items from all checklists, filtered by completion status and deletion status
    private var allItems: [ChecklistItem] {
        var items: [ChecklistItem] = []
        for checklist in allChecklists {
            if let checklistItems = checklist.items as? Set<ChecklistItem> {
                items.append(contentsOf: checklistItems)
            }
        }
        let filtered = items.filter { item in
            // First, exclude deleted items
            guard item.deletedAt == nil else { return false }

            // Then filter by completion status
            switch completionFilter {
            case .all:
                return true
            case .completed:
                return item.completed
            case .uncompleted:
                return !item.completed
            }
        }
        print("🔍 ChecklistsView.allItems: \(allChecklists.count) checklists, \(items.count) total items, \(filtered.count) filtered items for filter: \(completionFilter.rawValue)")
        return filtered
    }

    /// Group items by section (Overdue, Today, Upcoming, No Due Date, Completed)
    private var itemsBySection: [(title: String, items: [ChecklistItem])] {
        let now = Date()
        let calendar = Calendar.current

        let overdue = allItems.filter { item in
            if let dueDate = item.dueDate {
                return !item.completed && dueDate < now
            }
            return false
        }.sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }

        let today = allItems.filter { item in
            if let dueDate = item.dueDate {
                return !item.completed && calendar.isDateInToday(dueDate)
            }
            return false
        }.sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }

        let upcoming = allItems.filter { item in
            if let dueDate = item.dueDate {
                return !item.completed && dueDate > now && !calendar.isDateInToday(dueDate)
            }
            return false
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        let noDueDate = allItems.filter { item in
            return !item.completed && item.dueDate == nil
        }.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }

        let completed = allItems.filter { item in
            item.completed
        }.sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

        var sections: [(title: String, items: [ChecklistItem])] = []

        if !overdue.isEmpty {
            sections.append(("Overdue", overdue))
        }
        if !today.isEmpty {
            sections.append(("Due Today", today))
        }
        if !upcoming.isEmpty {
            sections.append(("Upcoming", upcoming))
        }
        if !noDueDate.isEmpty {
            sections.append(("No Due Date", noDueDate))
        }
        if !completed.isEmpty {
            sections.append(("Completed", completed))
        }

        return sections
    }

    private var isEmptyState: Bool {
        allItems.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Checklists")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text("\(allItems.count) item\(allItems.count == 1 ? "" : "s")")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isEmptyState {
                        // Empty state
                        VStack(alignment: .center, spacing: 16) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            VStack(spacing: 8) {
                                Text("No Checklists Yet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Create your first checklist item to stay organized")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 80)
                        .padding(.horizontal, 32)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Filter buttons
                                HStack(spacing: 8) {
                                    ForEach(CompletionFilter.allCases, id: \.self) { filter in
                                        Button(action: { completionFilter = filter }) {
                                            Text(filter.rawValue)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(completionFilter == filter ? .white : .secondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(completionFilter == filter ? Color.blue : Color(.systemGray5))
                                                )
                                        }
                                    }
                                    Spacer()
                                }
                                .frame(height: 32)
                                .padding(.horizontal, 16)

                                // Sections
                                ForEach(itemsBySection, id: \.title) { section in
                                    sectionView(title: section.title, items: section.items)
                                }

                                Spacer().frame(height: 20)
                            }
                            .padding(.vertical, 16)
                        }
                    }
                }

                // Floating add button
                VStack {
                    HStack {
                        Spacer()
                        VStack {
                            Spacer()
                            addButton
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingAddItemSheet) {
            addItemSheet
        }
        .sheet(isPresented: $showingEditSheet) {
            if let item = editingItem {
                editItemSheet(item)
            }
        }
        .onAppear {
            Task {
                // Fetch all checklists from Supabase when view appears
                await SupabaseDataManager.shared.syncAllChecklistsFromSupabase()
            }
        }
    }

    // MARK: - Views

    private func sectionView(title: String, items: [ChecklistItem]) -> some View {
        print("📍 sectionView: \(title) section has \(items.count) items")
        for (index, item) in items.enumerated() {
            print("   🔹 Item \(index): \(item.title ?? "untitled")")
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]

                    VStack(alignment: .leading, spacing: 0) {
                        checklistItemView(item)

                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    private func checklistItemView(_ item: ChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row with checkbox and title
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Button(action: { toggleItem(item) }) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.completed ? .blue : .secondary)
                }
                .padding(.vertical, 10)

                // Title and event
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title ?? "Untitled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(item.completed ? .secondary : .primary)
                        .strikethrough(item.completed, color: .secondary)
                        .lineLimit(2)

                    // Event title if linked
                    if let eventId = item.checklist?.eventIdentifier, eventId != "standalone" {
                        if let eventTitle = getEventTitle(eventId) {
                            Text(eventTitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Delete button
                Button(action: { deleteItem(item) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 12)

            // Expandable due date section
            if let dueDate = item.dueDate {
                Divider()
                    .padding(.leading, 44)

                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.clear)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Due")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(formatDueDate(dueDate))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(isOverdue(dueDate) && !item.completed ? .red : .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: { editingItem = item; showingEditSheet = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else if !item.completed {
                // Add due date option for incomplete items without due date
                Divider()
                    .padding(.leading, 44)

                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.clear)
                        .frame(width: 18)

                    Button(action: { editingItem = item; showingEditSheet = true }) {
                        Text("Add due date")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private var addButton: some View {
        Button(action: { showingAddItemSheet = true }) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.blue)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 5)
        }
    }

    private var addItemSheet: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    // Title Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Checklist Item")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)

                        TextField("What needs to be done?", text: $newItemTitle)
                            .textFieldStyle(.roundedBorder)
                            .padding(.vertical, 8)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(16)

                    // Due date card
                    VStack(spacing: 0) {
                        Toggle(isOn: $newItemHasDueDate) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                                Text("Add due date")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .tint(.blue)
                        .padding(16)

                        if newItemHasDueDate {
                            Divider().padding(.leading, 16)

                            DatePicker(
                                "Due date and time",
                                selection: $newItemDueDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .tint(.blue)
                            .padding(16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    Spacer()

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: { showingAddItemSheet = false }) {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundColor(.secondary)
                                .cornerRadius(10)
                        }

                        Button(action: { addNewItem() }) {
                            Text("Add Item")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAddItemSheet = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func editItemSheet(_ item: ChecklistItem) -> some View {
        let binding = Binding(
            get: { item.dueDate ?? Date() },
            set: { item.dueDate = $0 }
        )

        return NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    // Title info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit Checklist Item")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(item.title ?? "Untitled")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(16)

                    // Due date card
                    VStack(spacing: 0) {
                        if item.dueDate != nil {
                            HStack {
                                Label(
                                    title: { Text("Due Date").font(.system(size: 14, weight: .semibold)) },
                                    icon: { Image(systemName: "calendar").foregroundColor(.red) }
                                )
                                Spacer()
                            }
                            .padding(16)

                            Divider()

                            DatePicker(
                                "Date and time",
                                selection: binding,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .tint(.blue)
                            .padding(16)

                            Divider()

                            Button(action: {
                                withAnimation {
                                    item.dueDate = nil
                                    try? viewContext.save()
                                    Task {
                                        await ChecklistManager.shared.syncChecklistsToSupabase()
                                    }
                                    showingEditSheet = false
                                }
                            }) {
                                Text("Remove Due Date")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(16)
                        } else {
                            HStack {
                                Label(
                                    title: { Text("Add Due Date").font(.system(size: 14, weight: .semibold)) },
                                    icon: { Image(systemName: "calendar").foregroundColor(.blue) }
                                )
                                Spacer()
                            }
                            .padding(16)

                            Divider()

                            DatePicker(
                                "Date and time",
                                selection: binding,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .tint(.blue)
                            .padding(16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    Spacer()

                    // Save button
                    HStack(spacing: 12) {
                        Button(action: { showingEditSheet = false }) {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundColor(.secondary)
                                .cornerRadius(10)
                        }

                        Button(action: {
                            withAnimation {
                                do {
                                    try viewContext.save()
                                    Task {
                                        await ChecklistManager.shared.syncChecklistsToSupabase()
                                    }
                                } catch {
                                    print("❌ Error saving due date: \(error)")
                                }
                                showingEditSheet = false
                            }
                        }) {
                            Text("Save")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingEditSheet = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleItem(_ item: ChecklistItem) {
        withAnimation {
            do {
                try ChecklistManager.shared.toggleItemCompletion(item, completedBy: UUID())
                try viewContext.save()
                // Sync only this item's update to Supabase (targeted operation)
                Task {
                    await ChecklistManager.shared.syncItemUpdate(item)
                }
            } catch {
                print("❌ Error toggling item: \(error)")
            }
        }
    }

    private func deleteItem(_ item: ChecklistItem) {
        withAnimation {
            do {
                print("🗑️ Deleting item: \(item.title ?? "untitled")")
                print("   Item ID: \(item.id?.uuidString ?? "unknown")")
                print("   Item deletedAt before: \(item.deletedAt?.description ?? "nil")")

                ChecklistManager.shared.deleteItem(item)

                print("   Item deletedAt after: \(item.deletedAt?.description ?? "nil")")
                print("   Saving view context...")

                try viewContext.save()

                print("✅ Item deleted and saved")

                // Sync only this item's deletion to Supabase (targeted operation)
                Task {
                    await ChecklistManager.shared.syncItemDeletion(item)
                }
            } catch {
                print("❌ Error deleting item: \(error)")
            }
        }
    }

    private func addNewItem() {
        let itemTitle = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !itemTitle.isEmpty else { return }

        // Get or create standalone checklist
        let standalonePredicate = NSPredicate(format: "eventIdentifier == %@", "standalone")
        let fetchRequest = Checklist.fetchRequest()
        fetchRequest.predicate = standalonePredicate

        let existingChecklists = (try? viewContext.fetch(fetchRequest)) ?? []
        let checklist: Checklist

        if let existing = existingChecklists.first {
            checklist = existing
        } else {
            checklist = Checklist(context: viewContext)
            checklist.id = UUID()
            checklist.eventIdentifier = "standalone"
            checklist.createdAt = Date()
        }

        // Create new item
        let item = ChecklistItem(context: viewContext)
        item.id = UUID()
        item.title = itemTitle
        item.completed = false
        item.sortOrder = Int16((checklist.items?.count) ?? 0)
        item.createdAt = Date()
        item.checklist = checklist

        if newItemHasDueDate {
            item.dueDate = newItemDueDate
        }

        do {
            try viewContext.save()
            print("✅ Added checklist item: \(itemTitle)")
            print("   Checklist ID: \(checklist.id?.uuidString ?? "nil")")
            print("   Checklist eventIdentifier: \(checklist.eventIdentifier ?? "nil")")
            print("   Item ID: \(item.id?.uuidString ?? "nil")")
            print("   Item checklist relationship: \(item.checklist?.id?.uuidString ?? "nil")")
            print("   Checklist items count: \(checklist.items?.count ?? 0)")
            // Sync only this item's creation to Supabase (targeted operation)
            Task {
                await ChecklistManager.shared.syncItemUpdate(item)
            }
            newItemTitle = ""
            newItemHasDueDate = false
            newItemDueDate = Date()
            showingAddItemSheet = false
        } catch {
            print("❌ Error adding item: \(error)")
        }
    }

    // MARK: - Helpers

    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Date() && !Calendar.current.isDateInToday(date)
    }

    private func getEventTitle(_ eventIdentifier: String) -> String? {
        let ekEventStore = EKEventStore()
        if let event = ekEventStore.event(withIdentifier: eventIdentifier) {
            return event.title
        }
        return nil
    }
}

#Preview {
    ChecklistsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
        .environmentObject(AppSettingsManager())
}
