//
//  ChecklistEditorView.swift
//  FamCal
//
//  Created by Claude on 2025-12-09.
//

import SwiftUI

struct AddChecklistItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var checklist: Checklist

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    let onAdd: (String, Date?) -> Void

    var body: some View {
        NavigationView {
            Form {
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

struct EditChecklistItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var item: ChecklistItem

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    let onSave: (String, Date?) -> Void

    init(item: ChecklistItem, onSave: @escaping (String, Date?) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title ?? "")
        _hasDueDate = State(initialValue: item.dueDate != nil)
        _dueDate = State(initialValue: item.dueDate ?? Date())
    }

    var body: some View {
        NavigationView {
            Form {
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
            .navigationTitle("Edit Checklist Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalDueDate = hasDueDate ? dueDate : nil
                        onSave(title, finalDueDate)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
