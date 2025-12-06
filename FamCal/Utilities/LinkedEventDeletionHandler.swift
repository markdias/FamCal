import Foundation
import CoreData
import EventKit

class LinkedEventDeletionHandler {
    static let shared = LinkedEventDeletionHandler()

    // MARK: - Main Deletion Execution

    func executeLinkedEventDeletion(
        scope: DeleteScope,
        target: DeletionTarget,
        actionType: DeleteActionType,
        primaryEvent: UpcomingCalendarEvent,
        linkedFamilyEvents: [FamilyEvent],
        affectedMember: FamilyMember?,
        deletionReason: String?,
        viewContext: NSManagedObjectContext
    ) async -> Bool {
        print("🗑️ Starting deletion: scope=\(scope), target=\(target), type=\(actionType)")

        // 1. Determine EventKit span
        let ekSpan: EKSpan = {
            switch target {
            case .singleOccurrence:
                return .thisEvent
            case .thisAndFuture:
                return .futureEvents
            case .allInSeries:
                return .thisEvent  // Will need manual handling
            }
        }()

        // 2. Get all target events
        var targets: [(id: String, calendarId: String, occurrence: Date)] = []

        switch scope {
        case .singleCalendar:
            targets.append((
                id: primaryEvent.id,
                calendarId: primaryEvent.calendarID,
                occurrence: primaryEvent.startDate
            ))

        case .allLinked:
            targets.append((
                id: primaryEvent.id,
                calendarId: primaryEvent.calendarID,
                occurrence: primaryEvent.startDate
            ))

            for linkedEvent in linkedFamilyEvents {
                guard let eid = linkedEvent.eventIdentifier,
                      let calId = linkedEvent.calendarId else { continue }

                let occurrence = CalendarManager.shared
                    .fetchEventDetails(withIdentifier: eid)?
                    .startDate ?? primaryEvent.startDate

                targets.append((id: eid, calendarId: calId, occurrence: occurrence))
            }
        }

        // 3. Execute deletion based on action type
        var successCount = 0

        switch actionType {
        case .hardDelete:
            successCount = await hardDeleteEvents(
                targets: targets,
                span: ekSpan,
                target: target,
                viewContext: viewContext
            )

        case .softDelete:
            successCount = await softDeleteEvents(
                targets: targets,
                affectedMember: affectedMember,
                deletionReason: deletionReason,
                viewContext: viewContext
            )
        }

        return successCount > 0
    }

    // MARK: - Hard Delete

    private func hardDeleteEvents(
        targets: [(id: String, calendarId: String, occurrence: Date)],
        span: EKSpan,
        target: DeletionTarget,
        viewContext: NSManagedObjectContext
    ) async -> Int {
        var successCount = 0

        for targetEvent in targets {
            // Delete from EventKit
            let deleted = CalendarManager.shared.deleteEvent(
                withIdentifier: targetEvent.id,
                occurrenceStartDate: targetEvent.occurrence,
                from: targetEvent.calendarId,
                span: span
            )

            if deleted {
                successCount += 1

                // Cancel notifications
                await NotificationManager.shared.cancelEventNotifications(for: targetEvent.id)

                // Handle CoreData based on target
                switch target {
                case .singleOccurrence:
                    // For recurring events with single occurrence deletion: mark as deleted but keep record
                    updateFamilyEventDeletion(
                        eventId: targetEvent.id,
                        isDeleted: true,
                        deletionType: .hard,
                        deletionReason: nil,
                        viewContext: viewContext
                    )

                case .thisAndFuture, .allInSeries:
                    // For all/future: delete the entire FamilyEvent record
                    deleteFamilyEventRecord(eventId: targetEvent.id, viewContext: viewContext)
                }
            } else {
                print("⚠️ Failed to delete event \(targetEvent.id) in calendar \(targetEvent.calendarId)")
            }
        }

        await MainActor.run {
            if viewContext.hasChanges {
                try? viewContext.save()
            }
        }

        return successCount
    }

    // MARK: - Soft Delete

    private func softDeleteEvents(
        targets: [(id: String, calendarId: String, occurrence: Date)],
        affectedMember: FamilyMember?,
        deletionReason: String?,
        viewContext: NSManagedObjectContext
    ) async -> Int {
        var successCount = 0

        for targetEvent in targets {
            // Don't delete from EventKit, just update CoreData
            let fetchRequest = FamilyEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", targetEvent.id)

            if let familyEvent = try? viewContext.fetch(fetchRequest).first {
                // Mark as not attending
                familyEvent.isAttending = false
                familyEvent.deletedAt = Date()
                familyEvent.deletionType = DeletionType.soft.rawValue
                familyEvent.deletionReason = deletionReason

                // If specific member is being removed, remove from attendees
                if let member = affectedMember {
                    if var attendees = familyEvent.attendees as? Set<FamilyMember> {
                        attendees.remove(member)
                        familyEvent.attendees = attendees as NSSet
                    }
                }

                successCount += 1

                // Sync soft delete to Supabase
                Task {
                    await syncSoftDeleteToSupabase(
                        eventId: targetEvent.id,
                        isAttending: false,
                        deletionType: DeletionType.soft.rawValue,
                        deletionReason: deletionReason
                    )
                }
            }
        }

        await MainActor.run {
            if viewContext.hasChanges {
                try? viewContext.save()
            }
        }

        return successCount
    }

    // MARK: - Helper Functions

    private func updateFamilyEventDeletion(
        eventId: String,
        isDeleted: Bool,
        deletionType: DeletionType,
        deletionReason: String?,
        viewContext: NSManagedObjectContext
    ) {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", eventId)

        if let familyEvent = try? viewContext.fetch(fetchRequest).first {
            if isDeleted {
                familyEvent.isAttending = false
                familyEvent.deletionType = deletionType.rawValue
                familyEvent.deletedAt = Date()
                familyEvent.deletionReason = deletionReason
            } else {
                familyEvent.isAttending = true
                familyEvent.deletionType = nil
                familyEvent.deletedAt = nil
                familyEvent.deletionReason = nil
            }
        }
    }

    private func deleteFamilyEventRecord(eventId: String, viewContext: NSManagedObjectContext) {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", eventId)

        if let familyEvent = try? viewContext.fetch(fetchRequest).first {
            viewContext.delete(familyEvent)
        }
    }

    // MARK: - Restoration

    func canRestoreEvent(_ event: FamilyEvent) -> Bool {
        return event.deletionType == DeletionType.soft.rawValue && !event.isAttending
    }

    func restoreEvent(_ event: FamilyEvent, viewContext: NSManagedObjectContext) {
        event.isAttending = true
        event.deletionType = nil
        event.deletedAt = nil
        event.deletionReason = nil

        if viewContext.hasChanges {
            try? viewContext.save()
        }
    }

    // MARK: - Utilities

    func getAffectedPeopleNames(
        scope: DeleteScope,
        linkedFamilyEvents: [FamilyEvent],
        currentMemberName: String?
    ) -> [String] {
        switch scope {
        case .singleCalendar:
            return currentMemberName.map { [$0] } ?? []

        case .allLinked:
            var names = currentMemberName.map { [$0] } ?? []
            let linkedNames = linkedFamilyEvents.compactMap { event in
                event.attendees?.compactMap { ($0 as? FamilyMember)?.name }.joined(separator: ", ")
            }
            names.append(contentsOf: linkedNames)
            return names
        }
    }

    // MARK: - Supabase Sync

    private func syncSoftDeleteToSupabase(
        eventId: String,
        isAttending: Bool,
        deletionType: String,
        deletionReason: String?
    ) async {
        do {
            let supabaseManager = SupabaseManager.shared
            let authManager = SupabaseAuthManager.shared

            guard let userId = authManager.userId else {
                print("⚠️ Cannot sync soft delete: no authenticated user")
                return
            }

            try await supabaseManager.syncSoftDeletedEvent(
                userId: userId,
                eventIdentifier: eventId,
                isAttending: isAttending,
                deletionType: deletionType,
                deletionReason: deletionReason
            )

            print("✅ Synced soft delete to Supabase for event \(eventId)")
        } catch {
            print("⚠️ Failed to sync soft delete to Supabase: \(error.localizedDescription)")
            // Don't fail the deletion if sync fails - it will retry on next sync
        }
    }

    func restoreSoftDeletedEventToSupabase(eventId: String) async {
        do {
            let supabaseManager = SupabaseManager.shared
            let authManager = SupabaseAuthManager.shared

            guard let userId = authManager.userId else {
                print("⚠️ Cannot restore soft delete: no authenticated user")
                return
            }

            try await supabaseManager.restoreSoftDeletedEvent(
                userId: userId,
                eventIdentifier: eventId
            )

            print("✅ Restored soft deleted event to Supabase: \(eventId)")
        } catch {
            print("⚠️ Failed to restore soft delete in Supabase: \(error.localizedDescription)")
        }
    }
}
