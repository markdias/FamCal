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
    @StateObject private var authManager = SupabaseAuthManager.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var dataManager = SupabaseDataManager.shared
    @State private var hasCompletedOnboarding: Bool?
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
                // Authentication check first
                if authManager.isAuthenticated {
                    // User is authenticated, check onboarding status
                    if let completed = hasCompletedOnboarding {
                        if completed {
                            MainTabView()
                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                                .environmentObject(themeManager)
                                .environmentObject(authManager)
                                .environmentObject(dataManager)
                                .onAppear {
                                    dataManager.setManagedObjectContext(persistenceController.container.viewContext)
                                }
                        } else {
                            OnboardingView()
                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                                .environmentObject(themeManager)
                                .environmentObject(authManager)
                                .environmentObject(dataManager)
                                .onAppear {
                                    dataManager.setManagedObjectContext(persistenceController.container.viewContext)
                                }
                        }
                    } else {
                        // Loading onboarding state
                        OnboardingView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(authManager)
                            .environmentObject(dataManager)
                            .onAppear {
                                hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                                dataManager.setManagedObjectContext(persistenceController.container.viewContext)
                            }
                    }
                } else {
                    // User not authenticated, show login
                    LoginView()
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                        .onAppear {
                            // Reset onboarding state when logged out
                            hasCompletedOnboarding = nil
                        }
                }
            }
            .preferredColorScheme(themeManager.selectedTheme.prefersDarkInterface ? .dark : .light)
            .onOpenURL(perform: handleDeepLink(_:))
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                // When authentication state changes, reload onboarding status
                if isAuth {
                    hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                } else {
                    hasCompletedOnboarding = nil
                }
            }
        }
    }

    /// Handle deep links from widget and email confirmation
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("❌ Failed to parse deep link URL: \(url.absoluteString)")
            return
        }

        print("ℹ️ Received deep link: \(url.absoluteString)")
        print("ℹ️ Scheme: \(components.scheme ?? "nil"), Host: \(components.host ?? "nil")")

        // Handle widget event links (famli://event?...)
        if components.scheme == "famli" && components.host == "event" {
            if let title = components.queryItems?.first(where: { $0.name == "title" })?.value {
                deepLinkEventTitle = title
            }
            if let memberIdString = components.queryItems?.first(where: { $0.name == "memberId" })?.value,
               let memberId = UUID(uuidString: memberIdString) {
                deepLinkMemberId = memberId
            }
        }

        // Handle Supabase email confirmation links (famcal://auth/confirm?access_token=...)
        if components.scheme == "famcal" {
            if let accessToken = components.queryItems?.first(where: { $0.name == "access_token" })?.value {
                print("✅ Received email confirmation token")
                Task { @MainActor in
                    // Supabase has already confirmed the email and returned an access token
                    // We can use this token to log the user in automatically
                    authManager.userId = components.queryItems?.first(where: { $0.name == "user_id" })?.value
                    authManager.accessToken = accessToken
                    authManager.userEmail = components.queryItems?.first(where: { $0.name == "email" })?.value
                    authManager.isAuthenticated = true
                    authManager.saveSession()
                    print("✅ User automatically authenticated via email confirmation link")
                }
            }
        }
    }
}
