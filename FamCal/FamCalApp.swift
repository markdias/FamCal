//
//  FamCalApp.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import WidgetKit
import GoogleSignIn

@main
struct FamCalApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = SupabaseAuthManager.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var dataManager = SupabaseDataManager.shared
    @StateObject private var appSettingsManager = AppSettingsManager.shared
    @State private var hasCompletedOnboarding: Bool = false
    @State private var deepLinkEventTitle: String?
    @State private var deepLinkMemberId: UUID?
    @State private var isFirstLoad = true
    @State private var previousAuthState: (isAuthenticated: Bool, isGuest: Bool)?
    @State private var isCheckingSession = true

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

        // Load onboarding completion status from UserDefaults
        // This prevents showing onboarding again for returning users
        _hasCompletedOnboarding = State(initialValue: defaults.bool(forKey: "hasCompletedOnboarding"))

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

    /// Check if user has existing data (family members or shared calendars)
    /// Returns true if any data exists, false if database is empty (brand new user)
    private func userHasExistingData(_ persistenceController: PersistenceController) -> Bool {
        let context = persistenceController.container.viewContext

        // Check for existing family members
        let familyMemberFetch = FamilyMember.fetchRequest()
        do {
            let familyMemberCount = try context.count(for: familyMemberFetch)
            if familyMemberCount > 0 {
                return true
            }
        } catch {
            print("⚠️ Error checking family members: \(error)")
        }

        // Check for existing shared calendars
        let sharedCalendarFetch = SharedCalendar.fetchRequest()
        do {
            let sharedCalendarCount = try context.count(for: sharedCalendarFetch)
            if sharedCalendarCount > 0 {
                return true
            }
        } catch {
            print("⚠️ Error checking shared calendars: \(error)")
        }

        return false
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // While session is being checked, show loading screen
                if isCheckingSession {
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        ProgressView()
                    }
                }
                // Check if user is authenticated or guest
                else if authManager.isAuthenticated || authManager.isGuest {
                    // For authenticated users or returning guests with completed onboarding, go straight to main app
                    // Skip onboarding entirely if data exists (family members or shared calendars)
                    if hasCompletedOnboarding || userHasExistingData(persistenceController) {
                        MainTabView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(authManager)
                            .environmentObject(dataManager)
                            .environmentObject(appSettingsManager)
                            .onAppear {
                                dataManager.setManagedObjectContext(persistenceController.container.viewContext)
                                Task {
                                    await appSettingsManager.loadSettings()
                                }
                            }
                    } else {
                        // Only show onboarding for brand new users with no existing data
                        OnboardingView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(authManager)
                            .environmentObject(dataManager)
                            .environmentObject(appSettingsManager)
                            .onAppear {
                                dataManager.setManagedObjectContext(persistenceController.container.viewContext)
                                Task {
                                    await appSettingsManager.loadSettings()
                                }
                            }
                    }
                } else {
                    // User not authenticated and not guest, show login
                    LoginView()
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                        .onAppear {
                            // Reset onboarding state when logged out
                            hasCompletedOnboarding = false
                        }
                }
            }
            .preferredColorScheme(themeManager.selectedTheme.prefersDarkInterface ? .dark : .light)
            .onOpenURL(perform: handleDeepLink(_:))
            .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
                // Only handle actual state changes, not first load
                if !isFirstLoad && oldValue != newValue {
                    if newValue {
                        // User just logged in - reset onboarding for fresh flow
                        hasCompletedOnboarding = false
                        print("ℹ️ Authenticated user logging in - resetting onboarding flag for fresh flow")
                    } else {
                        // User just logged out
                        hasCompletedOnboarding = false
                    }
                }
            }
            .onChange(of: authManager.isGuest) { oldValue, newValue in
                // Only handle actual state changes, not first load
                if !isFirstLoad && oldValue != newValue {
                    if newValue {
                        // User switched to guest mode - preserve saved onboarding state
                        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                        print("ℹ️ Guest mode - onboarding flag: \(hasCompletedOnboarding)")
                    } else if !authManager.isAuthenticated {
                        // User switched away from guest mode
                        hasCompletedOnboarding = false
                    }
                }
            }
            .onAppear {
                // Mark first load as complete after initial render
                isFirstLoad = false
                previousAuthState = (authManager.isAuthenticated, authManager.isGuest)

                // Stop showing loading screen after a short delay to allow session check to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCheckingSession = false
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, _ in
                // Session changed, stop loading
                isCheckingSession = false
            }
            .onChange(of: authManager.isGuest) { _, _ in
                // Session changed, stop loading
                isCheckingSession = false
            }
        }
    }

    /// Handle deep links from widget and email confirmation
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("❌ Failed to parse deep link URL: \(url.absoluteString)")
            return
        }

        // Handle Google Sign-In redirect
        if GIDSignIn.sharedInstance.handle(url) {
            print("✅ Handled Google Sign-In redirect")
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
