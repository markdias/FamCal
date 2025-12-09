//
//  ChecklistSectionView.swift
//  FamCal
//
//  Created by Claude on 2025-12-09.
//

import SwiftUI
import CoreData

struct ChecklistSectionView: View {
    var checklist: Checklist?
    let eventIdentifier: String
    let eventGroupId: UUID?
    let eventTitle: String
    let eventStartDate: Date
    let eventEndDate: Date

    @State private var showingAddItem = false
    @State private var showingEditItem: ChecklistItem?
    @State private var currentUserId: UUID?
    @State private var localChecklist: Checklist?
    @State private var refreshTrigger = false

    private var activeChecklist: Checklist? {
        checklist ?? localChecklist
    }

    private var sortedItems: [ChecklistItem] {
        guard let checklist = activeChecklist,
              let items = checklist.items as? Set<ChecklistItem> else { return [] }
        return items
            .filter { $0.deletedAt == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var progress: ChecklistProgress {
        guard let checklist = activeChecklist else {
            return ChecklistProgress(completed: 0, total: 0)
        }
        return ChecklistManager.shared.getProgress(for: checklist)
    }

    private func progressColor(_ percentage: Double) -> Color {
        if percentage == 1.0 {
            return .green
        } else if percentage >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header matching Calendar/Driver/Alert style
            HStack {
                Text("Checklist")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                if !progress.isEmpty {
                    progressBadge
                }
            }
            .padding(.horizontal, 20)

            // Items content in a card
            VStack(alignment: .leading, spacing: 12) {
                // Items list
                if sortedItems.isEmpty {
                    Text("No checklist items yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedItems) { item in
                        ChecklistItemRow(item: item, onToggle: toggleItem)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingEditItem = item
                            }
                    }
                }

                // Add button
                Button(action: { showingAddItem = true }) {
                    Label("Add Item", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal, 20)
        }
        .id(refreshTrigger) // Force view refresh when items change
        .sheet(isPresented: $showingAddItem) {
            // Create a temporary view that doesn't require checklist
            AddChecklistItemSheetWrapper(
                existingChecklist: checklist ?? localChecklist,
                eventTitle: eventTitle,
                eventStartDate: eventStartDate,
                eventEndDate: eventEndDate,
                onAdd: addItem
            )
        }
        .sheet(item: $showingEditItem) { item in
            EditChecklistItemSheet(item: item, onSave: { title, dueDate in
                editItem(item, title: title, dueDate: dueDate)
            })
        }
        .onAppear {
            // Get current user ID for completion tracking
            currentUserId = UUID() // TODO: Get from auth manager

            // Initialize local checklist from passed checklist
            if let checklist = checklist {
                localChecklist = checklist
            }
        }
    }

    private var progressBadge: some View {
        Text(progress.displayString)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(progressColor(progress.percentage).opacity(0.2))
            .foregroundColor(progressColor(progress.percentage))
            .cornerRadius(12)
    }

    private func addItem(title: String, dueDate: Date?) {
        do {
            // Ensure checklist exists before adding item
            let targetChecklist: Checklist
            if let existing = activeChecklist {
                targetChecklist = existing
            } else {
                // Create checklist on-demand
                targetChecklist = try ChecklistManager.shared.getOrCreateChecklist(
                    for: eventIdentifier,
                    eventGroupId: eventGroupId
                )
                localChecklist = targetChecklist
            }

            let nextSortOrder = Int16(sortedItems.count)

            _ = try ChecklistManager.shared.addItem(
                to: targetChecklist,
                title: title,
                dueDate: dueDate,
                sortOrder: nextSortOrder
            )

            // Trigger refresh
            refreshTrigger.toggle()

            // Schedule notifications if item has due date
            if dueDate != nil {
                // TODO: Get event date and title for notification scheduling
                print("ℹ️ Item created with due date, notifications will be scheduled during event sync")
            }
        } catch {
            print("❌ Error adding checklist item: \(error)")
        }
    }

    private func editItem(_ item: ChecklistItem, title: String, dueDate: Date?) {
        do {
            try ChecklistManager.shared.updateItem(
                item,
                title: title,
                dueDate: dueDate,
                completed: nil
            )
            refreshTrigger.toggle()
        } catch {
            print("❌ Error updating checklist item: \(error)")
        }
    }

    private func toggleItem(_ item: ChecklistItem) {
        guard let userId = currentUserId else { return }

        do {
            try ChecklistManager.shared.toggleItemCompletion(item, completedBy: userId)
            refreshTrigger.toggle()
        } catch {
            print("❌ Error toggling checklist item: \(error)")
        }
    }
}

// Wrapper to handle add sheet without requiring checklist
private struct AddChecklistItemSheetWrapper: View {
    @Environment(\.dismiss) var dismiss
    let existingChecklist: Checklist?
    let eventTitle: String
    let eventStartDate: Date
    let eventEndDate: Date
    let onAdd: (String, Date?) -> Void

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    private static let dateFormatter: DateFormatter = {
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

    var body: some View {
        NavigationView {
            Form {
                // Event information section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(eventTitle)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(Self.dateFormatter.string(from: eventStartDate))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Self.timeFormatter.string(from: eventStartDate)) – \(Self.timeFormatter.string(from: eventEndDate))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Item Details")) {
                    TextField("Item title", text: $title)

                    Toggle("Set due date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker(
                            "Due date",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("Add Checklist Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let finalDueDate = hasDueDate ? dueDate : nil
                        onAdd(title, finalDueDate)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
