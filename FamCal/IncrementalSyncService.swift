//
//  IncrementalSyncService.swift
//  FamCal
//
//  Created: 2025-12-05
//  Purpose: Provides incremental sync with timestamp-based change detection
//  Prevents data loss by only syncing changed entities and never deleting unless confirmed
//

import Foundation
import CoreData

/// Service responsible for incremental sync between Supabase and CoreData
/// Uses timestamp-based change detection to minimize network traffic and prevent data loss
class IncrementalSyncService {
    static let shared = IncrementalSyncService()

    private let supabaseClient = SupabaseClientManager.shared.client

    private init() {}

    // MARK: - Change Detection

    /// Fetches only the IDs and timestamps of entities that changed since last sync
    /// Returns lightweight metadata to determine which entities need full fetch
    func fetchChangedEntityMetadata(
        entityType: String,
        lastSyncTime: Date,
        context: NSManagedObjectContext
    ) async throws -> [EntityChangeMetadata] {

        switch entityType {
        case "familyMembers":
            return try await fetchChangedMembersMetadata(since: lastSyncTime)
        case "familyMemberCalendars":
            return try await fetchChangedMemberCalendarsMetadata(since: lastSyncTime)
        case "sharedCalendars":
            return try await fetchChangedSharedCalendarsMetadata(since: lastSyncTime)
        case "personalCalendars":
            return try await fetchChangedPersonalCalendarsMetadata(since: lastSyncTime)
        case "drivers":
            return try await fetchChangedDriversMetadata(since: lastSyncTime)
        case "savedAddresses":
            return try await fetchChangedAddressesMetadata(since: lastSyncTime)
        case "familyEvents":
            return try await fetchChangedEventsMetadata(since: lastSyncTime)
        default:
            return []
        }
    }

    // MARK: - Metadata Fetchers (Lightweight Queries)

    private func fetchChangedMembersMetadata(since: Date) async throws -> [EntityChangeMetadata] {
        let postgrestResponse = try await supabaseClient
            .from("family_members")
            .select("id, updated_at")
            .gte("updated_at", value: since.ISO8601Format())
            .execute()

        let response: [FamilyMemberMetadataDTO] = try postgrestResponse.decode()
        return response.map { EntityChangeMetadata(id: $0.id, updatedAt: $0.updated_at) }
    }

    private func fetchChangedMemberCalendarsMetadata(since: Date) async throws -> [EntityChangeMetadata] {
        let postgrestResponse = try await supabaseClient
            .from("family_member_calendars")
            .select("id, updated_at")
            .gte("updated_at", value: since.ISO8601Format())
            .execute()

        let response: [FamilyMemberCalendarMetadataDTO] = try postgrestResponse.decode()
        return response.map { EntityChangeMetadata(id: $0.id, updatedAt: $0.updated_at) }
    }

    private func fetchChangedSharedCalendarsMetadata(since: Date) async throws -> [EntityChangeMetadata] {
        let postgrestResponse = try await supabaseClient
            .from("shared_calendars")
            .select("id, updated_at")
            .gte("updated_at", value: since.ISO8601Format())
            .execute()

        let response: [SharedCalendarMetadataDTO] = try postgrestResponse.decode()
        return response.map { EntityChangeMetadata(id: $0.id, updatedAt: $0.updated_at) }
    }

    private func fetchChangedPersonalCalendarsMetadata(since: Date) async throws -> [EntityChangeMetadata] {
        let postgrestResponse = try await supabaseClient
            .from("personal_calendars")
            .select("id, updated_at")
            .gte("updated_at", value: since.ISO8601Format())
            .execute()

        let response: [PersonalCalendarMetadataDTO] = try postgrestResponse.decode()
        return response.map { EntityChangeMetadata(id: $0.id, updatedAt: $0.updated_at) }
    }

    private func fetchChangedDriversMetadata(since: Date) async throws -> [EntityChangeMetadata] {
        let postgrestResponse = try await supabaseClient
            .from("drivers")
            .select("id, updated_at")
            .gte("updated_at", value: since.ISO8601Format())
            .execute()

        let response: [DriverMetadataDTO] = try postgrestResponse.decode()
        return response.map { EntityChangeMetadata(id: $0.id, updatedAt: $0.updated_at) }
    }

    private func fetchChangedAddressesMetadata(since: Date) async throws -> [EntityChangeMetadata] {
        let postgrestResponse = try await supabaseClient
            .from("saved_addresses")
            .select("id, updated_at")
            .gte("updated_at", value: since.ISO8601Format())
            .execute()

        let response: [SavedAddressMetadataDTO] = try postgrestResponse.decode()
        return response.map { EntityChangeMetadata(id: $0.id, updatedAt: $0.updated_at) }
    }

    private func fetchChangedEventsMetadata(since: Date) async throws -> [EntityChangeMetadata] {
        let postgrestResponse = try await supabaseClient
            .from("family_events")
            .select("id, updated_at")
            .gte("updated_at", value: since.ISO8601Format())
            .execute()

        let response: [FamilyEventMetadataDTO] = try postgrestResponse.decode()
        return response.map { EntityChangeMetadata(id: $0.id, updatedAt: $0.updated_at) }
    }

    // MARK: - Conflict Resolution

    /// Merges remote entity into local entity using timestamp-based conflict resolution
    /// Latest timestamp wins (automatic conflict resolution)
    func mergeEntity<T: NSManagedObject>(
        local: T,
        remoteUpdatedAt: Date?,
        applyChanges: (T) -> Void
    ) {
        guard let remoteUpdatedAt = remoteUpdatedAt else {
            // No remote timestamp, keep local
            print("⚠️ No remote timestamp for \(type(of: local)), keeping local")
            return
        }

        // Get local updatedAt via KVC (all entities now have this property)
        let localUpdatedAt = local.value(forKey: "updatedAt") as? Date

        if let localUpdatedAt = localUpdatedAt {
            // Both have timestamps - compare
            if remoteUpdatedAt > localUpdatedAt {
                // Remote is newer, apply changes
                print("🔄 Remote newer for \(type(of: local)), applying remote")
                applyChanges(local)
                local.setValue(remoteUpdatedAt, forKey: "updatedAt")
            } else {
                // Local is same or newer, keep local
                print("✅ Local up-to-date for \(type(of: local)), keeping local")
            }
        } else {
            // Local has no timestamp, apply remote
            print("🆕 Local missing timestamp for \(type(of: local)), applying remote")
            applyChanges(local)
            local.setValue(remoteUpdatedAt, forKey: "updatedAt")
        }
    }

    // MARK: - Soft Delete Handling

    /// Marks entity as deleted instead of removing from CoreData
    /// Preserves data for potential recovery and sync verification
    func softDelete<T: NSManagedObject>(_ entity: T, reason: String = "sync") {
        entity.setValue(true, forKey: "isSoftDeleted")
        entity.setValue(Date(), forKey: "deletedAt")
        print("🗑️ Soft deleted \(type(of: entity)): \(reason)")
    }

    /// Retrieves non-deleted entities of a given type
    func fetchNonDeleted<T: NSManagedObject>(
        entityName: String,
        context: NSManagedObjectContext
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = NSPredicate(format: "isSoftDeleted == NO OR isSoftDeleted == nil")
        return try context.fetch(request)
    }

    // MARK: - Response Validation

    /// Validates that a Supabase response is not suspiciously empty
    /// Prevents accidental data deletion from network errors or API issues
    func validateResponse<T>(
        entities: [T],
        entityType: String,
        existingCount: Int
    ) -> Bool {
        // If we have existing data but get empty response, flag as suspicious
        if entities.isEmpty && existingCount > 0 {
            print("⚠️ VALIDATION FAILED: Received 0 \(entityType) but have \(existingCount) locally")
            print("⚠️ Rejecting empty response to prevent data loss")
            return false
        }

        // If response is dramatically smaller than local data (>80% reduction), flag it
        if existingCount > 5 && entities.count < existingCount / 5 {
            print("⚠️ VALIDATION WARNING: Received \(entities.count) \(entityType) but have \(existingCount) locally")
            print("⚠️ This is a >80% reduction - possible data loss scenario")
            return false
        }

        return true
    }

    // MARK: - Full Entity Fetch (for changed IDs only)

    /// Fetches full entity data for specific IDs that changed
    func fetchEntitiesByIds<T: Decodable>(
        table: String,
        ids: [UUID],
        selectColumns: String = "*"
    ) async throws -> [T] {
        guard !ids.isEmpty else { return [] }

        let idStrings = ids.map { $0.uuidString }
        let postgrestResponse = try await supabaseClient
            .from(table)
            .select(selectColumns)
            .in("id", values: idStrings)
            .execute()

        return try postgrestResponse.decode()
    }
}

// MARK: - Supporting Types

/// Lightweight metadata for change detection (ID + timestamp only)
struct EntityChangeMetadata: Codable {
    let id: UUID
    let updatedAt: Date
}

// MARK: - Metadata DTOs (minimal payload for change detection)

struct FamilyMemberMetadataDTO: Codable {
    let id: UUID
    let updated_at: Date
}

struct FamilyMemberCalendarMetadataDTO: Codable {
    let id: UUID
    let updated_at: Date
}

struct SharedCalendarMetadataDTO: Codable {
    let id: UUID
    let updated_at: Date
}

struct PersonalCalendarMetadataDTO: Codable {
    let id: UUID
    let updated_at: Date
}

struct DriverMetadataDTO: Codable {
    let id: UUID
    let updated_at: Date
}

struct SavedAddressMetadataDTO: Codable {
    let id: UUID
    let updated_at: Date
}

struct FamilyEventMetadataDTO: Codable {
    let id: UUID
    let updated_at: Date
}
