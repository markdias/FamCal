//
//  SyncMetadataManager.swift
//  FamCal
//
//  Manages sync timestamps and change tracking for offline-first architecture
//

import Foundation
import CoreData

class SyncMetadataManager {
    static let shared = SyncMetadataManager()

    /// Entity types that need sync tracking
    enum EntityType: String, CaseIterable {
        case familyMembers = "FamilyMembers"
        case familyMemberCalendars = "FamilyMemberCalendars"
        case sharedCalendars = "SharedCalendars"
        case personalCalendars = "PersonalCalendars"
        case drivers = "Drivers"
        case savedAddresses = "SavedAddresses"
        case calendarEventMetadata = "CalendarEventMetadata"
    }

    /// Check if we should fetch data for an entity type based on sync age
    /// Returns false if: last sync < syncIntervalMinutes ago AND no pending changes
    /// Returns true if: > syncIntervalMinutes since last sync OR pending changes OR first sync
    func shouldFetchData(entityType: EntityType, syncIntervalMinutes: Int, context: NSManagedObjectContext) -> Bool {
        guard let metadata = fetchMetadata(entityType: entityType, context: context) else {
            print("ℹ️ SyncMetadata: First sync for \(entityType.rawValue) - will fetch")
            return true
        }

        // If there are pending changes, always sync to upload them
        if metadata.hasPendingChanges {
            print("ℹ️ SyncMetadata: Pending changes for \(entityType.rawValue) - will fetch to sync")
            return true
        }

        // Check if last sync is older than the sync interval
        let timeSinceLastSync = Date().timeIntervalSince(metadata.lastSyncTime ?? .distantPast)
        let syncIntervalSeconds = TimeInterval(syncIntervalMinutes * 60)

        if timeSinceLastSync >= syncIntervalSeconds {
            print("ℹ️ SyncMetadata: \(entityType.rawValue) is stale (\(Int(timeSinceLastSync / 60))m old) - will fetch")
            return true
        }

        print("✅ SyncMetadata: \(entityType.rawValue) is fresh (\(Int(timeSinceLastSync / 60))m old) - skipping fetch")
        return false
    }

    /// Update sync metadata after successful fetch
    func recordSync(entityType: EntityType, context: NSManagedObjectContext) {
        let metadata = fetchOrCreateMetadata(entityType: entityType, context: context)
        metadata.lastSyncTime = Date()
        metadata.hasPendingChanges = false
        metadata.syncStatus = "synced"

        do {
            try context.save()
            print("✅ SyncMetadata: Recorded sync for \(entityType.rawValue) at \(metadata.lastSyncTime?.formatted() ?? "unknown")")
        } catch {
            print("❌ SyncMetadata: Failed to record sync for \(entityType.rawValue): \(error)")
        }
    }

    /// Mark an entity type as having pending changes that need to be synced
    func markPending(entityType: EntityType, context: NSManagedObjectContext) {
        let metadata = fetchOrCreateMetadata(entityType: entityType, context: context)
        metadata.hasPendingChanges = true
        metadata.syncStatus = "pending"

        do {
            try context.save()
            print("⚠️ SyncMetadata: Marked \(entityType.rawValue) as pending")
        } catch {
            print("❌ SyncMetadata: Failed to mark \(entityType.rawValue) as pending: \(error)")
        }
    }

    /// Detect and mark changes for an entity type by checking for unsync'd modifications
    /// Compares last sync time with entity modification times
    func detectAndMarkChanges(entityType: EntityType, context: NSManagedObjectContext) {
        guard let metadata = fetchMetadata(entityType: entityType, context: context) else {
            print("ℹ️ SyncMetadata: No metadata for \(entityType.rawValue) - skipping change detection")
            return
        }

        let lastSyncTime = metadata.lastSyncTime ?? .distantPast
        var hasChanges = false
        var changedCount = 0

        do {
            switch entityType {
            case .familyMembers:
                let fetch: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
                fetch.predicate = NSPredicate(format: "modifiedAt > %@", lastSyncTime as NSDate)
                let changed = try context.fetch(fetch)
                changedCount = changed.count
                hasChanges = !changed.isEmpty

            case .drivers:
                let fetch: NSFetchRequest<Driver> = Driver.fetchRequest()
                fetch.predicate = NSPredicate(format: "modifiedAt > %@", lastSyncTime as NSDate)
                let changed = try context.fetch(fetch)
                changedCount = changed.count
                hasChanges = !changed.isEmpty

            case .savedAddresses:
                let fetch: NSFetchRequest<SavedAddress> = SavedAddress.fetchRequest()
                fetch.predicate = NSPredicate(format: "modifiedAt > %@", lastSyncTime as NSDate)
                let changed = try context.fetch(fetch)
                changedCount = changed.count
                hasChanges = !changed.isEmpty

            case .personalCalendars:
                let fetch: NSFetchRequest<PersonalCalendar> = PersonalCalendar.fetchRequest()
                fetch.predicate = NSPredicate(format: "modifiedAt > %@", lastSyncTime as NSDate)
                let changed = try context.fetch(fetch)
                changedCount = changed.count
                hasChanges = !changed.isEmpty

            default:
                print("ℹ️ SyncMetadata: Change detection not implemented for \(entityType.rawValue)")
                return
            }

            if hasChanges {
                print("🔍 SyncMetadata: Detected \(changedCount) changes in \(entityType.rawValue) since last sync")
                markPending(entityType: entityType, context: context)
            } else {
                print("✅ SyncMetadata: No changes detected in \(entityType.rawValue)")
            }
        } catch {
            print("❌ SyncMetadata: Error detecting changes for \(entityType.rawValue): \(error)")
        }
    }

    /// Mark sync as failed (for retry logic)
    func recordSyncFailure(entityType: EntityType, context: NSManagedObjectContext) {
        let metadata = fetchOrCreateMetadata(entityType: entityType, context: context)
        metadata.syncStatus = "failed"
        metadata.hasPendingChanges = true  // Keep pending to retry

        do {
            try context.save()
            print("⚠️ SyncMetadata: Recorded sync failure for \(entityType.rawValue)")
        } catch {
            print("❌ SyncMetadata: Failed to record sync failure: \(error)")
        }
    }

    /// Get the last sync time for an entity type
    func getLastSyncTime(entityType: EntityType, context: NSManagedObjectContext) -> Date? {
        return fetchMetadata(entityType: entityType, context: context)?.lastSyncTime
    }

    /// Clear all sync metadata (for debugging or when user logs out)
    func clearAllMetadata(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<SyncMetadata> = SyncMetadata.fetchRequest()
        do {
            let allMetadata = try context.fetch(fetchRequest)
            for metadata in allMetadata {
                context.delete(metadata)
            }
            try context.save()
            print("✅ SyncMetadata: Cleared all sync metadata")
        } catch {
            print("❌ SyncMetadata: Failed to clear sync metadata: \(error)")
        }
    }

    // MARK: - Private Helpers

    func fetchMetadata(entityType: EntityType, context: NSManagedObjectContext) -> SyncMetadata? {
        let fetchRequest: NSFetchRequest<SyncMetadata> = SyncMetadata.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "entityType == %@", entityType.rawValue)

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("❌ SyncMetadata: Error fetching metadata for \(entityType.rawValue): \(error)")
            return nil
        }
    }

    private func fetchOrCreateMetadata(entityType: EntityType, context: NSManagedObjectContext) -> SyncMetadata {
        if let existing = fetchMetadata(entityType: entityType, context: context) {
            return existing
        }

        let metadata = SyncMetadata(context: context)
        metadata.id = UUID()
        metadata.entityType = entityType.rawValue
        metadata.lastSyncTime = .distantPast  // Force first sync
        metadata.hasPendingChanges = false
        metadata.syncStatus = "synced"

        return metadata
    }
}
