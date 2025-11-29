import Foundation
import CoreData

@MainActor
struct FamilyInfoStore {
    static func fetchFirst(in context: NSManagedObjectContext) throws -> FamilyInfo? {
        let request: NSFetchRequest<FamilyInfo> = FamilyInfo.fetchRequest()
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @discardableResult
    static func upsert(name: String?, familyId: String?, in context: NSManagedObjectContext) throws -> FamilyInfo? {
        guard let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedName.isEmpty else {
            // If the name was cleared, skip updating and just return the existing record if any.
            return try fetchFirst(in: context)
        }

        let info = try fetchFirst(in: context) ?? FamilyInfo(context: context)
        if info.id == nil {
            info.id = UUID()
        }
        info.name = trimmedName
        if let familyId {
            info.familyId = familyId
        }
        try context.save()

        if AppSettingsManager.shared.familyName != trimmedName {
            AppSettingsManager.shared.familyName = trimmedName
        }
        return info
    }

    static func currentName(in context: NSManagedObjectContext) -> String? {
        (try? fetchFirst(in: context))?.name
    }
}
