//
//  ChecklistManager.swift
//  FamCal
//
//  Created by Claude on 2025-12-09.
//

import Foundation
import Combine
import CoreData
import UserNotifications
import CommonCrypto

class ChecklistManager: ObservableObject {
    static let shared = ChecklistManager()

    private let context = PersistenceController.shared.container.viewContext
    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Device-Independent Event Identification

    /// Generate a stable, device-independent identifier for an event
    /// Uses ONLY title and date (day only) - excludes calendar ID and time to ensure consistency across devices
    /// Calendar IDs differ per device, and times can have timezone differences
    static func generateStableEventIdentifier(title: String, startDate: Date, calendarID: String) -> String {
        // Use ONLY title and date (day only, no time or timezone)
        // This ensures the same hash on different devices with different calendar IDs
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Date only, no time or timezone
        let dateStr = dateFormatter.string(from: startDate)

        let combined = "\(title)|\(dateStr)"
        print("🔐 Generating stable ID: title=\(title), date=\(dateStr)")

        // Use SHA256 hash for stable, consistent identifier
        guard let data = combined.data(using: .utf8) else {
            return "event_unknown"
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }

        let hexStr = digest.map { String(format: "%02x", $0) }.joined()
        let result = "event_\(hexStr)"
        print("   → Generated stable ID: \(result)")
        return result
    }

    /// For backwards compatibility: try matching with old EventKit ID first, then stable ID
    static func canMatchEventIdentifier(_ checklistEventIdentifier: String,
                                       toEventKitID eventKitID: String,
                                       eventTitle: String,
                                       startDate: Date,
                                       calendarID: String) -> Bool {
        // Direct match (old format or same device)
        if checklistEventIdentifier == eventKitID {
            print("✅ Matched checklist via direct EventKit ID")
            return true
        }

        // Match with stable identifier
        let stableID = generateStableEventIdentifier(title: eventTitle, startDate: startDate, calendarID: calendarID)
        if checklistEventIdentifier == stableID {
            print("✅ Matched checklist via stable identifier")
            return true
        }

        print("❌ No match - checklist ID: \(checklistEventIdentifier), eventKit ID: \(eventKitID), stable ID: \(stableID)")
        return false
    }

    // MARK: - Checklist Operations

    @MainActor
    func getOrCreateChecklist(for eventIdentifier: String, eventGroupId: UUID?, eventTitle: String? = nil) throws -> Checklist {
        // Check if checklist already exists
        if let existing = fetchChecklist(for: eventIdentifier) {
            print("✅ Found existing checklist with eventIdentifier: \(eventIdentifier)")
            return existing
        }

        // Create new checklist
        let checklist = Checklist(context: context)
        checklist.id = UUID()
        checklist.eventIdentifier = eventIdentifier
        checklist.eventGroupId = eventGroupId
        checklist.eventTitle = eventTitle
        checklist.createdAt = Date()
        checklist.modifiedAt = Date()

        do {
            try context.save()
            print("✅ Created checklist:")
            print("   ID: \(checklist.id?.uuidString ?? "unknown")")
            print("   eventIdentifier: \(eventIdentifier)")
            print("   eventTitle: \(eventTitle ?? "nil")")
            print("   eventGroupId: \(eventGroupId?.uuidString ?? "nil")")
            return checklist
        } catch {
            print("❌ Error creating checklist: \(error)")
            throw error
        }
    }

    func fetchChecklist(for eventIdentifier: String) -> Checklist? {
        let fetchRequest: NSFetchRequest<Checklist> = Checklist.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "eventIdentifier == %@ AND deletedAt == nil",
            eventIdentifier
        )
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            if let found = results.first {
                print("✅ Found checklist with eventIdentifier: \(eventIdentifier)")
                return found
            } else {
                print("⚠️ No checklist found for eventIdentifier: \(eventIdentifier)")
                // List all checklists to debug
                let allRequest: NSFetchRequest<Checklist> = Checklist.fetchRequest()
                let allChecklists = try context.fetch(allRequest)
                print("   Available checklists:")
                for c in allChecklists {
                    print("   - ID: \(c.id?.uuidString ?? "nil"), eventIdentifier: \(c.eventIdentifier ?? "nil"), eventTitle: \(c.eventTitle ?? "nil")")
                }
                return nil
            }
        } catch {
            print("❌ Error fetching checklist: \(error)")
            return nil
        }
    }

    func deleteChecklist(_ checklist: Checklist, reason: String) {
        checklist.deletedAt = Date()
        checklist.deletionReason = reason
        checklist.modifiedAt = Date()

        // Soft delete all items
        if let items = checklist.items as? Set<ChecklistItem> {
            for item in items {
                deleteItem(item)
            }
        }

        do {
            try context.save()
            print("✅ Soft deleted checklist: \(checklist.id?.uuidString ?? "unknown")")
        } catch {
            print("❌ Error deleting checklist: \(error)")
        }
    }

    // MARK: - Item Operations

    @MainActor
    func addItem(to checklist: Checklist, title: String, dueDate: Date?, sortOrder: Int16) throws -> ChecklistItem {
        let item = ChecklistItem(context: context)
        item.id = UUID()
        item.checklist = checklist
        item.title = title
        item.dueDate = dueDate
        item.sortOrder = sortOrder
        item.completed = false
        item.createdAt = Date()
        item.modifiedAt = Date()

        checklist.modifiedAt = Date()

        do {
            try context.save()
            print("✅ Added checklist item: \(title)")
            return item
        } catch {
            print("❌ Error adding checklist item: \(error)")
            throw error
        }
    }

    @MainActor
    func updateItem(_ item: ChecklistItem, title: String?, dueDate: Date?, completed: Bool?) throws {
        if let title = title {
            item.title = title
        }
        if let dueDate = dueDate {
            item.dueDate = dueDate
        }
        if let completed = completed {
            item.completed = completed
            if completed {
                item.completedAt = Date()
            } else {
                item.completedAt = nil
                item.completedBy = nil
            }
        }
        item.modifiedAt = Date()
        item.checklist?.modifiedAt = Date()

        do {
            try context.save()
            print("✅ Updated checklist item")
        } catch {
            print("❌ Error updating checklist item: \(error)")
            throw error
        }
    }

    @MainActor
    func toggleItemCompletion(_ item: ChecklistItem, completedBy: UUID) throws {
        item.completed.toggle()

        if item.completed {
            item.completedAt = Date()
            item.completedBy = completedBy

            // Cancel notifications for this item
            Task {
                await cancelNotificationsForItem(item)
            }
        } else {
            item.completedAt = nil
            item.completedBy = nil
        }

        item.modifiedAt = Date()
        item.checklist?.modifiedAt = Date()

        do {
            try context.save()
            print("✅ Toggled item completion: \(item.title ?? "unknown")")
        } catch {
            print("❌ Error toggling item completion: \(error)")
            throw error
        }
    }

    func deleteItem(_ item: ChecklistItem) {
        item.deletedAt = Date()
        item.modifiedAt = Date()
        item.checklist?.modifiedAt = Date()

        // Cancel notifications
        Task {
            await cancelNotificationsForItem(item)
        }

        do {
            try context.save()
            print("✅ Soft deleted checklist item")
        } catch {
            print("❌ Error deleting checklist item: \(error)")
        }
    }

    func reorderItems(_ items: [ChecklistItem]) {
        for (index, item) in items.enumerated() {
            item.sortOrder = Int16(index)
            item.modifiedAt = Date()
        }

        do {
            try context.save()
            print("✅ Reordered checklist items")
        } catch {
            print("❌ Error reordering items: \(error)")
        }
    }

    // MARK: - Notifications

    func scheduleNotificationsForItem(_ item: ChecklistItem, eventTitle: String, eventDate: Date) async throws {
        guard let dueDate = item.dueDate, !item.completed else { return }

        // Don't schedule separate notification if due date matches event date
        let calendar = Calendar.current
        if calendar.isDate(dueDate, inSameDayAs: eventDate) {
            print("ℹ️ Item due date matches event date, skipping separate notification")
            return
        }

        let now = Date()
        var notificationIds: [String] = []

        // 1. Due date notification (exact time)
        if dueDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Checklist Item Due"
            content.body = "\(item.title ?? "") - \(eventTitle)"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
                repeats: false
            )

            let notificationId = "\(item.id!.uuidString)_due"
            let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

            try await notificationCenter.add(request)
            notificationIds.append(notificationId)
            print("✅ Scheduled due date notification for item at \(dueDate)")
        }

        // 2. Exactly 24 hours before notification
        let exactDayBefore = dueDate.addingTimeInterval(-24 * 60 * 60)
        if exactDayBefore > now {
            let content = UNMutableNotificationContent()
            content.title = "Checklist Reminder"
            content.body = "\(item.title ?? "") due in 24 hours - \(eventTitle)"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: exactDayBefore),
                repeats: false
            )

            let notificationId = "\(item.id!.uuidString)_24hrbefore"
            let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

            try await notificationCenter.add(request)
            notificationIds.append(notificationId)
            print("✅ Scheduled 24hr reminder notification for item")
        }

        // Store notification IDs
        await MainActor.run {
            item.notificationId = notificationIds.joined(separator: ",")
            try? context.save()
        }
    }

    func cancelNotificationsForItem(_ item: ChecklistItem) async {
        guard let notificationIdString = item.notificationId else { return }

        let notificationIds = notificationIdString.split(separator: ",").map(String.init)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: notificationIds)

        print("✅ Cancelled \(notificationIds.count) notifications for item")

        await MainActor.run {
            item.notificationId = nil
            try? context.save()
        }
    }

    // MARK: - Progress

    func getProgress(for checklist: Checklist) -> ChecklistProgress {
        guard let items = checklist.items as? Set<ChecklistItem> else {
            return ChecklistProgress(completed: 0, total: 0)
        }

        let activeItems = items.filter { $0.deletedAt == nil }
        let completedCount = activeItems.filter { $0.completed }.count

        return ChecklistProgress(completed: completedCount, total: activeItems.count)
    }

    // MARK: - Sync

    /// Sync checklists to Supabase (called after local changes)
    func syncChecklistsToSupabase() async {
        await SupabaseDataManager.shared.syncChecklistsToSupabase()
    }

    /// Sync a single item deletion to Supabase (targeted operation)
    func syncItemDeletion(_ item: ChecklistItem) async {
        guard let itemId = item.id?.uuidString else {
            print("❌ Cannot sync deletion: item has no ID")
            return
        }

        // Validate that item has a valid parent checklist
        guard let parentChecklist = item.checklist, let checklistId = parentChecklist.id else {
            print("⚠️ Cannot sync deletion: item has no valid parent checklist relationship")
            return
        }

        // Don't try to sync deletion if parent checklist is deleted
        // When checklist is deleted, all items cascade-delete automatically
        if parentChecklist.deletedAt != nil {
            print("⏭️ Skipping item deletion sync: parent checklist is already deleted (cascade delete)")
            return
        }

        do {
            print("🗑️ Syncing item deletion to Supabase: \(item.title ?? "untitled")")
            print("   Parent checklist ID: \(checklistId.uuidString)")
            try await SupabaseDataManager.shared.supabaseManager.deleteChecklistItem(id: itemId)
            print("✅ Item deletion synced to Supabase")
        } catch {
            print("❌ Error syncing item deletion: \(error)")
        }
    }

    /// Sync a single item update to Supabase (targeted operation)
    func syncItemUpdate(_ item: ChecklistItem) async {
        guard let itemId = item.id?.uuidString else {
            print("❌ Cannot sync update: item has no ID")
            return
        }

        // Validate that item has a valid parent checklist
        guard let parentChecklist = item.checklist, let checklistId = parentChecklist.id else {
            print("⚠️ Cannot sync update: item has no valid parent checklist relationship")
            return
        }

        // Don't sync if parent checklist is deleted
        if parentChecklist.deletedAt != nil {
            print("⏭️ Skipping item update sync: parent checklist is deleted")
            return
        }

        // Convert item to DTO and sync
        let formatter = ISO8601DateFormatter()
        let dto = ChecklistItemDTO(
            id: itemId,
            checklist_id: checklistId.uuidString,
            title: item.title ?? "",
            due_date: item.dueDate.map { formatter.string(from: $0) },
            completed: item.completed,
            completed_at: item.completedAt.map { formatter.string(from: $0) },
            completed_by: item.completedBy?.uuidString,
            sort_order: Int(item.sortOrder),
            created_at: item.createdAt.map { formatter.string(from: $0) },
            modified_at: formatter.string(from: Date()),
            deleted_at: item.deletedAt.map { formatter.string(from: $0) },
            notification_id: item.notificationId
        )

        do {
            print("📤 Syncing item update to Supabase: \(item.title ?? "untitled")")
            _ = try await SupabaseDataManager.shared.supabaseManager.upsertChecklistItem(dto)
            print("✅ Item update synced to Supabase")
        } catch {
            print("❌ Error syncing item update: \(error)")
        }
    }
}
