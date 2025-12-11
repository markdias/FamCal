//
//  ChecklistsView.swift
//  FamCal
//
//  Created by Claude on 2025-12-11.
//

import SwiftUI
import CoreData

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

    @FetchRequest(
        entity: ChecklistItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ChecklistItem.dueDate, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil")
    )
    private var allChecklistItems: FetchedResults<ChecklistItem>

    @State private var completionFilter: CompletionFilter = .all
    @State private var showingAddItemSheet = false
    @State private var newItemTitle: String = ""
    @State private var newItemHasDueDate = false
    @State private var newItemDueDate = Date()

    enum CompletionFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case uncompleted = "Uncompleted"
    }

    private var theme: AppTheme {
        themeManager.selectedTheme
    }

    // MARK: - Computed Properties

    private var filteredItems: [ChecklistItem] {
        allChecklistItems.filter { item in
            switch completionFilter {
            case .all:
                return true
            case .completed:
                return item.completed
            case .uncompleted:
                return !item.completed
            }
        }
    }

    private var itemsBySection: [(title: String, items: [ChecklistItem])] {
        let now = Date()
        let calendar = Calendar.current

        let overdue = filteredItems.filter { item in
            if let dueDate = item.dueDate {
                return !item.completed && dueDate < now
            }
            return false
        }.sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }

        let today = filteredItems.filter { item in
            if let dueDate = item.dueDate {
                return !item.completed && calendar.isDateInToday(dueDate)
            }
            return false
        }.sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }

        let upcoming = filteredItems.filter { item in
            if let dueDate = item.dueDate {
                return !item.completed && dueDate > now && !calendar.isDateInToday(dueDate)
            }
            return false
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        let completed = filteredItems.filter { item in
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
        if !completed.isEmpty {
            sections.append(("Completed", completed))
        }

        return sections
    }

    private var isEmptyState: Bool {
        filteredItems.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    // Title Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Checklists")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text("\(filteredItems.count) item\(filteredItems.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
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
                            VStack(alignment: .leading, spacing: 12) {
                                // Filter buttons
                                HStack(spacing: 8) {
                                    ForEach(CompletionFilter.allCases, id: \.rawValue) { filter in
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
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                                // Sections
                                ForEach(itemsBySection, id: \.title) { section in
                                    sectionView(title: section.title, items: section.items)
                                }

                                Spacer().frame(height: 20)
                            }
                            .padding(.vertical, 8)
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
    }

    // MARK: - Views

    private func sectionView(title: String, items: [ChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)

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
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: { toggleItem(item) }) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(item.completed ? .blue : .secondary)
            }
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(item.title ?? "Untitled")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(item.completed ? .secondary : .primary)
                    .strikethrough(item.completed, color: .secondary)
                    .lineLimit(2)

                // Event and due date info
                HStack(spacing: 8) {
                    if let eventId = item.checklist?.eventIdentifier, eventId != "standalone" {
                        // Event badge
                        Label(
                            title: { Text("Event").font(.system(size: 11, weight: .regular)) },
                            icon: { Image(systemName: "calendar").font(.system(size: 10)) }
                        )
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    }

                    if let dueDate = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isOverdue(dueDate) && !item.completed ? .red : .secondary)

                            Text(formatDueDate(dueDate))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(isOverdue(dueDate) && !item.completed ? .red : .secondary)
                        }
                    }
                }
            }

            Spacer()

            // Delete button
            Button(action: { deleteItem(item) }) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
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

                    // Due date toggle
                    Toggle(isOn: $newItemHasDueDate) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add due date")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .tint(.blue)
                    .padding(.horizontal, 16)

                    if newItemHasDueDate {
                        DatePicker(
                            "Due date and time",
                            selection: $newItemDueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .tint(.blue)
                        .padding(.horizontal, 16)
                    }

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
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Actions

    private func toggleItem(_ item: ChecklistItem) {
        withAnimation {
            do {
                try ChecklistManager.shared.toggleItemCompletion(item, completedBy: UUID())
                try viewContext.save()
                Task {
                    await ChecklistManager.shared.syncChecklistsToSupabase()
                }
            } catch {
                print("❌ Error toggling item: \(error)")
            }
        }
    }

    private func deleteItem(_ item: ChecklistItem) {
        withAnimation {
            do {
                ChecklistManager.shared.deleteItem(item)
                try viewContext.save()
                Task {
                    await ChecklistManager.shared.syncChecklistsToSupabase()
                }
            } catch {
                print("❌ Error deleting item: \(error)")
            }
        }
    }

    private func addNewItem() {
        let checklist = Checklist(context: viewContext)
        checklist.id = UUID()
        checklist.eventIdentifier = "standalone"
        checklist.createdAt = Date()

        let item = ChecklistItem(context: viewContext)
        item.id = UUID()
        item.title = newItemTitle.trimmingCharacters(in: .whitespaces)
        item.completed = false
        item.sortOrder = Int16(allChecklistItems.count)
        item.createdAt = Date()
        item.checklist = checklist

        if newItemHasDueDate {
            item.dueDate = newItemDueDate
        }

        do {
            try viewContext.save()
            Task {
                await ChecklistManager.shared.syncChecklistsToSupabase()
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
}

#Preview {
    ChecklistsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
        .environmentObject(AppSettingsManager())
}
