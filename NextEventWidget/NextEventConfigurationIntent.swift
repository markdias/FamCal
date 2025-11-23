//
//  NextEventConfigurationIntent.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import AppIntents
import CoreData

@available(iOS 17.0, *)
struct NextEventConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Next Event Options"

    @Parameter(title: "Mode", default: .familyNext)
    var mode: NextEventDisplayMode?

    @Parameter(title: "Member", default: nil, optionsProvider: MemberOptionsProvider())
    var selectedMemberName: String?

    init() {}
}

/// Provides dynamic options for member selection in widget configuration
@available(iOS 17.0, *)
struct MemberOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        return fetchFamilyMemberNames()
    }

    private func fetchFamilyMemberNames() -> [String] {
        do {
            let appGroupID = "group.com.markdias.famli"
            guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return []
            }

            let storeURL = appGroupURL.appendingPathComponent("FamCal.sqlite")
            var modelURL = Bundle.main.url(forResource: "FamCal", withExtension: "momd")

            if modelURL == nil {
                if let widgetBundlePath = Bundle.main.bundlePath as NSString? {
                    let pluginsPath = widgetBundlePath.deletingLastPathComponent
                    let appPath = (pluginsPath as NSString).deletingLastPathComponent
                    modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("FamCal.momd")

                    if !FileManager.default.fileExists(atPath: modelURL!.path) {
                        modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/FamCal.momd")
                    }
                }
            }

            guard let modelURL = modelURL,
                  let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
                return []
            }

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            let storeOptions: [String: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentStoreFileProtectionKey: FileProtectionType.none,
                NSReadOnlyPersistentStoreOption: true
            ]

            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: storeOptions
            )

            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator

            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FamilyMember")
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.resultType = .dictionaryResultType
            let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]

            let results = try context.fetch(fetchRequest) as? [[String: Any]] ?? []
            let names = results.compactMap { result -> String? in
                result["name"] as? String
            }

            return names
        } catch {
            return []
        }
    }
}

/// Modes for the next event widget
enum NextEventDisplayMode: String, AppEnum, CaseIterable {
    case familyNext
    case memberNext

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display Mode")

    static var caseDisplayRepresentations: [NextEventDisplayMode: DisplayRepresentation] {
        [
            .familyNext: "Next Family Event",
            .memberNext: "Specific Member"
        ]
    }
}
