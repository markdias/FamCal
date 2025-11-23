//
//  FamCalApp.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import WidgetKit

@main
struct FamCalApp: App {
    let persistenceController = PersistenceController.shared
    @State private var hasCompletedOnboarding: Bool?
    @StateObject private var themeManager = ThemeManager()
    @State private var deepLinkEventTitle: String?
    @State private var deepLinkMemberId: UUID?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "eventsPastDays": 90,
            "eventsFutureDays": 180
        ])

        if defaults.integer(forKey: "eventsPastDays") == 0 {
            defaults.set(90, forKey: "eventsPastDays")
        }

        if defaults.integer(forKey: "eventsFutureDays") == 0 {
            defaults.set(180, forKey: "eventsFutureDays")
        }

        // Load onboarding state on first access
        _hasCompletedOnboarding = State(initialValue: nil)

        // Move diagnostics off main thread to prevent blocking UI
        DispatchQueue.global(qos: .utility).async {
            PersistenceController.printStoreDiagnostics()
            print("🚀 FamCal app launched")
        }

        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { _ in
            // Nudge widgets to reload quickly after data changes
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let completed = hasCompletedOnboarding {
                    if completed {
                        MainTabView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                    } else {
                        OnboardingView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                    }
                } else {
                    OnboardingView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(themeManager)
                        .onAppear {
                            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                        }
                }
            }
            .preferredColorScheme(themeManager.selectedTheme.prefersDarkInterface ? .dark : .light)
            .onOpenURL(perform: handleDeepLink(_:))
        }
    }

    /// Handle deep links from widget
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }

        if components.scheme == "famli" && components.host == "event" {
            if let title = components.queryItems?.first(where: { $0.name == "title" })?.value {
                deepLinkEventTitle = title
            }
            if let memberIdString = components.queryItems?.first(where: { $0.name == "memberId" })?.value,
               let memberId = UUID(uuidString: memberIdString) {
                deepLinkMemberId = memberId
            }
        }
    }
}
