//
//  ChecklistItemRow.swift
//  FamCal
//
//  Created by Claude on 2025-12-09.
//

import SwiftUI

struct ChecklistItemRow: View {
    @ObservedObject var item: ChecklistItem
    let onToggle: (ChecklistItem) -> Void

    private var formattedDueDate: String? {
        guard let dueDate = item.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: { onToggle(item) }) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.completed ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "")
                    .strikethrough(item.completed)
                    .foregroundColor(item.completed ? .secondary : .primary)

                if let dueDateText = formattedDueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                        Text(dueDateText)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}
