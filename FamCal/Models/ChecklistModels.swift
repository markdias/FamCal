//
//  ChecklistModels.swift
//  FamCal
//
//  Created by Claude on 2025-12-09.
//

import Foundation

// MARK: - Supabase DTOs

struct ChecklistDTO: Codable {
    let id: String
    let event_identifier: String
    let event_group_id: String?
    let created_at: String?
    let modified_at: String?
    let deleted_at: String?
    let deletion_reason: String?
}

struct ChecklistItemDTO: Codable {
    let id: String
    let checklist_id: String
    let title: String
    let due_date: String?
    let completed: Bool
    let completed_at: String?
    let completed_by: String?
    let sort_order: Int
    let created_at: String?
    let modified_at: String?
    let deleted_at: String?
    let notification_id: String?
}

// MARK: - View Models

struct ChecklistItemViewModel: Identifiable, Hashable {
    let id: UUID
    let title: String
    let dueDate: Date?
    let completed: Bool
    let completedAt: Date?
    let sortOrder: Int

    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
}

struct ChecklistProgress {
    let completed: Int
    let total: Int

    var percentage: Double {
        total > 0 ? Double(completed) / Double(total) : 0.0
    }

    var displayString: String {
        "\(completed)/\(total)"
    }

    var isEmpty: Bool {
        total == 0
    }
}
