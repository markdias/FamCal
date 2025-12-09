//
//  FamCalApp.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import WidgetKit
import EventKit
import GoogleMobileAds
import UIKit
// import GoogleSignIn - Enable in Xcode GUI after uncommenting GoogleSignIn pod

// MARK: - AppDelegate for Quick Actions
class AppDelegate: NSObject, UIApplicationDelegate {
    private static var pendingShortcutItem: UIApplicationShortcutItem?
    static var quickActionHandler: ((UIApplicationShortcutItem) -> Void)? {
        didSet {
            deliverPendingQuickActionIfNeeded()
        }
    }

    private static func deliverPendingQuickActionIfNeeded() {
        guard let handler = quickActionHandler,
              let pendingItem = pendingShortcutItem else {
            return
        }

        pendingShortcutItem = nil
        DispatchQueue.main.async {
            handler(pendingItem)
        }
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        print("🔔 AppDelegate.performActionFor called for: \(shortcutItem.type)")

        // Call the handler set up by FamCalApp
        if let handler = AppDelegate.quickActionHandler {
            DispatchQueue.main.async {
                handler(shortcutItem)
            }
        } else {
            AppDelegate.pendingShortcutItem = shortcutItem
        }
        completionHandler(true)
    }
}

@main
struct FamCalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = SupabaseAuthManager.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var dataManager = SupabaseDataManager.shared
    @StateObject private var appSettingsManager = AppSettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCompletedOnboarding: Bool = false
    @State private var deepLinkEventTitle: String?
    @State private var deepLinkMemberId: UUID?
    @State private var isFirstLoad = true
    @State private var previousAuthState: (isAuthenticated: Bool, isGuest: Bool)?
    @State private var isCheckingSession = true
    @State private var calendarCheckStatus: CalendarCheckStatus = .unknown
    @State private var showResetPasswordSheet = false
    @State private var resetPasswordEmail: String?
    @State private var needsFamilySetup: Bool = false
    @State private var isCheckingFamilySetup: Bool = false

    /// Persist calendar check status when it becomes ready
    /// Uses device-level flag - calendar check runs only once per device
    private func saveCalendarCheckStatus() {
        if case .ready = calendarCheckStatus {
            UserDefaults.standard.set(true, forKey: "hasPassedCalendarCheckOnce")
            print("💾 Saved calendar check status: completed on this device")
        }
    }

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

        // Load calendar check status from UserDefaults on app init
        // This prevents showing gate view if already completed on this device
        if defaults.bool(forKey: "hasPassedCalendarCheckOnce") {
            _calendarCheckStatus = State(initialValue: .ready)
        }

        // Initialize Google Mobile Ads SDK
        MobileAds.initialize()
        print("📱 Google Mobile Ads SDK initialized")

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

    private var isCalendarCheckReady: Bool {
        // Calendar check is ready if status is .ready OR if user has existing data (completed setup)
        if case .ready = calendarCheckStatus {
            return true
        }
        // Also consider ready if user has existing data (they've set up before)
        if userHasExistingData(persistenceController) {
            print("✅ Calendar check considered ready: user has existing data")
            return true
        }
        return false
    }

    var body: some Scene {
        WindowGroup {
            SystemColorSchemeUpdater(themeManager: themeManager) {
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
                    // Check if family setup is needed for new users
                    if isCheckingFamilySetup {
                        ZStack {
                            Color(.systemBackground)
                                .ignoresSafeArea()
                            ProgressView()
                        }
                    }
                    // Show family setup flow for new users
                    else if needsFamilySetup {
                        FamilySetupFlow()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(authManager)
                            .environmentObject(dataManager)
                            .environmentObject(appSettingsManager)
                            .onAppear {
                                dataManager.setManagedObjectContext(persistenceController.container.viewContext)
                                Task {
                                    await appSettingsManager.loadSettings()
                                    // Smart sync in background
                                    await dataManager.fetchUserDataIfNeeded()
                                }
                            }
                    }
                    // If authenticated (non-guest) but calendars/family setup needed, block until ready
                    // However, skip this if we already have data (offline case where user has completed setup)
                    else if authManager.isAuthenticated && !authManager.isGuest && !isCalendarCheckReady && !userHasExistingData(persistenceController) {
                        NavigationView {
                            CalendarGateView(
                                status: $calendarCheckStatus,
                                onRetry: { runCalendarCheck() },
                                onLogout: { Task { try? await authManager.signOut() } },
                                theme: themeManager.selectedTheme,
                                familyMembers: dataManager.familyMembers
                            )
                        }
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(themeManager)
                        .environmentObject(authManager)
                        .environmentObject(dataManager)
                        .environmentObject(appSettingsManager)
                        .onAppear {
                            print("📱 Calendar Gate View appearing")
                            dataManager.setManagedObjectContext(persistenceController.container.viewContext)

                            Task {
                                await appSettingsManager.loadSettings()
                                // Use smart fetch that checks for changes before fetching
                                await dataManager.fetchUserDataIfNeeded()
                                print("✅ User data fetched. Family members: \(dataManager.familyMembers.count), Calendars: \(dataManager.familyMemberCalendars.count)")
                                // Only run calendar check if not already in ready state (avoid re-running on app resume)
                                await MainActor.run {
                                    if case .unknown = calendarCheckStatus {
                                        runCalendarCheck()
                                        print("📊 Calendar check status: running check")
                                    } else {
                                        print("📊 Calendar check already completed or loaded - skipping re-check")
                                    }
                                }
                            }
                        }
                    }
                    // For authenticated users or returning guests with completed onboarding, go straight to main app
                    // Skip onboarding entirely if data exists (family members or shared calendars)
                    else if hasCompletedOnboarding || userHasExistingData(persistenceController) {
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
                                    // Smart sync in background - skips if data is fresh
                                    await dataManager.fetchUserDataIfNeeded()
                                }
                            }
                    } else {
                        // Only show onboarding for brand new users with no existing data
                        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(authManager)
                            .environmentObject(dataManager)
                            .environmentObject(appSettingsManager)
                            .onAppear {
                                dataManager.setManagedObjectContext(persistenceController.container.viewContext)
                                Task {
                                    await appSettingsManager.loadSettings()
                                    // Smart sync in background
                                    await dataManager.fetchUserDataIfNeeded()
                                }
                            }
                    }
                } else {
                    // User not authenticated and not guest
                    if hasCompletedOnboarding {
                        // Show login after onboarding is completed
                        LoginView()
                            .environmentObject(authManager)
                            .environmentObject(themeManager)
                    } else {
                        // Always show startup flow first on fresh installs
                        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(authManager)
                            .environmentObject(dataManager)
                            .environmentObject(appSettingsManager)
                    }
                }
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
            .sheet(isPresented: $showResetPasswordSheet) {
                ResetPasswordSheet(email: resetPasswordEmail)
                    .environmentObject(authManager)
                    .environmentObject(themeManager)
            }
            .onOpenURL(perform: handleDeepLink(_:))
            .onChange(of: scenePhase) { _, phase in
                print("📱 ScenePhase changed to: \(phase)")
                if phase == .active {
                    print("🔄 App became active - calling resetStore()")
                    CalendarManager.shared.resetStore()
                    // NOTE: We only reset the EventKit store here. Data syncing happens via:
                    // 1. Automatic refresh timer (set by AppSettingsManager)
                    // 2. Manual pull-to-refresh in calendar views
                    // 3. Initial app load and after user actions (adding/editing calendars)
                    // This avoids unnecessary Supabase fetches on every app resume.

                    // Sync calendar notifications when app becomes active
                    Task {
                        await NotificationManager.shared.syncCalendarNotifications()
                    }
                }
            }
            .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
                // Only handle actual state changes, not first load
                if !isFirstLoad && oldValue != newValue {
                    if newValue {
                        // User just logged in
                        // If transitioning from guest to authenticated, clear guest family setup
                        if previousAuthState?.isGuest == true && !authManager.isGuest {
                            print("🔄 Transitioning from guest to authenticated user - resetting family setup")
                            UserDefaults.standard.set(false, forKey: "hasCompletedFamilySetup")
                            UserDefaults.standard.removeObject(forKey: "com.famcal.familyId")
                            needsFamilySetup = true
                            // Note: Guest CoreData family members will be overwritten by auth user's data
                        }
                        previousAuthState = (authManager.isAuthenticated, authManager.isGuest)
                    } else {
                        // User just logged out - only reset state variables, not the device-level flag
                        // (calendar check should only run once per device)
                        calendarCheckStatus = .unknown
                        previousAuthState = (authManager.isAuthenticated, authManager.isGuest)
                    }
                }
            }
            .onChange(of: authManager.isGuest) { oldValue, newValue in
                // Only handle actual state changes, not first load
                if !isFirstLoad && oldValue != newValue {
                    hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                    print("ℹ️ Guest mode change - onboarding flag: \(hasCompletedOnboarding)")
                }
            }
            .onChange(of: calendarCheckStatus) { _, _ in
                // Persist calendar check status when it changes
                saveCalendarCheckStatus()
            }
            .onAppear {
                // Set up quick action handler
                AppDelegate.quickActionHandler = { shortcutItem in
                    self.handleQuickAction(shortcutItem)
                }

                // Mark first load as complete after initial render
                isFirstLoad = false
                previousAuthState = (authManager.isAuthenticated, authManager.isGuest)

                // Ensure morning brief is scheduled on app launch
                NotificationManager.shared.ensureMorningBriefScheduled()

                // Sync calendar notifications on app launch
                Task {
                    await NotificationManager.shared.syncCalendarNotifications()
                }

                // Validate session on app launch if user is authenticated
                if authManager.isAuthenticated && !authManager.isGuest {
                    Task {
                        let isValid = await authManager.validateSessionOnAppLaunch()
                        if !isValid {
                            print("⚠️ Session validation failed on app launch - user may need to re-authenticate")
                        }
                    }
                }

                // Stop showing loading screen after a short delay to allow session check to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCheckingSession = false
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                // Session changed, stop loading
                isCheckingSession = false
                // Check family setup when user authenticates
                if newValue {
                    checkFamilySetupNeeded()
                } else {
                    needsFamilySetup = false
                }
            }
            .onChange(of: authManager.isGuest) { _, newValue in
                // Session changed, stop loading
                isCheckingSession = false
                if newValue {
                    calendarCheckStatus = .ready
                    // Check family setup for guest users
                    checkFamilySetupNeeded()
                } else {
                    needsFamilySetup = false
                }
            }
            .onChange(of: appSettingsManager.hasCompletedFamilySetup) { _, newValue in
                // When family setup completes, dismiss the setup flow
                if newValue {
                    print("✅ Family setup completion detected - dismissing setup flow")
                    needsFamilySetup = false
                }
            }
            }
        }
    }

    /// Check if family setup is needed for new users
    private func checkFamilySetupNeeded() {
        Task { @MainActor in
            isCheckingFamilySetup = true
            defer { isCheckingFamilySetup = false }

            // Check if any family data exists in CoreData
            let hasExistingData = userHasExistingData(persistenceController)

            // If CoreData was cleared (no existing data), reset the setup flag
            // This ensures family setup runs again when user logs back in after data loss
            if !hasExistingData && appSettingsManager.hasCompletedFamilySetup {
                print("⚠️ CoreData cleared but setup flag was true - resetting setup flag")
                appSettingsManager.hasCompletedFamilySetup = false
                UserDefaults.standard.set(false, forKey: "hasCompletedFamilySetup")
            }

            // If we have existing data in CoreData, skip setup regardless of network status
            // This prevents showing setup flow when offline with cached data
            if hasExistingData {
                print("✅ User has existing family data in CoreData - skipping setup")
                needsFamilySetup = false
                return
            }

            // Check if user is an invited member (doesn't need to create a family)
            if authManager.isAuthenticated && !authManager.isGuest {
                let isInvited = await dataManager.isCurrentUserInvitedMember()
                if isInvited {
                    print("ℹ️ User is an invited member - skipping family setup")
                    needsFamilySetup = false
                    return
                }
            }

            // If authenticated and NOT an invited member, check if they have a valid family
                if authManager.isAuthenticated && !authManager.isGuest {
                    // Check if user has a valid family in Supabase (familyId might be stale from previous user)
                    if let familyId = appSettingsManager.familyId {
                        print("ℹ️ Local familyId found: \(familyId), verifying in Supabase...")
                        // Verify the family actually exists and belongs to this user
                        if let _ = try? await SupabaseManager.shared.getFamilyForOwner(userId: authManager.userId ?? "") {
                            print("ℹ️ Authenticated user with valid family - skipping setup")
                            needsFamilySetup = false
                            return
                        } else {
                            // The local familyId may belong to another owner (invited member)
                            if let userId = authManager.userId,
                               (try? await SupabaseManager.shared.isUserLinkedToFamily(userId: userId, familyId: familyId)) == true {
                                print("ℹ️ Authenticated user is linked to familyId \(familyId) - skipping setup")
                                needsFamilySetup = false
                                return
                            }
                            print("⚠️ Family not found in Supabase, clearing stale familyId")
                            await MainActor.run {
                                appSettingsManager.familyId = nil
                                UserDefaults.standard.removeObject(forKey: "com.famcal.familyId")
                            }
                        }
                    }

                // No valid family found, show setup
                print("ℹ️ Authenticated user with no valid family - showing family setup")
                needsFamilySetup = true
                return
            }

            // Show setup if no family data exists (guest or new user)
            if !hasExistingData {
                print("ℹ️ New user detected - showing family setup")
                needsFamilySetup = true
            } else {
                print("ℹ️ User has existing family data - skipping setup")
                needsFamilySetup = false
            }
        }
    }

    /// Handle quick action from app icon
    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        print("🔔 Quick action handled in onContinueUserActivity: \(shortcutItem.type)")
        if shortcutItem.type == "mdias.famcal.logout" {
            print("🔔 Sign Out quick action detected")
            Task { @MainActor in
                do {
                    try await authManager.signOut()
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    print("✅ Sign out completed successfully from quick action")
                } catch {
                    print("❌ Sign out failed: \(error)")
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

        // Handle Google Sign-In redirect (commented out - enable in Xcode GUI with GoogleSignIn pod)
        // if GIDSignIn.sharedInstance.handle(url) {
        //     print("✅ Handled Google Sign-In redirect")
        //     return
        // }

        print("ℹ️ Received deep link: \(url.absoluteString)")
        print("ℹ️ Scheme: \(components.scheme ?? "nil"), Host: \(components.host ?? "nil")")
        if let query = components.query { print("🔎 Query: \(query)") }
        if let fragment = components.fragment { print("🔎 Fragment: \(fragment)") }

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
            let queryItems = components.queryItems ?? []
            let fragmentItems = parseFragmentItems(components.fragment)

            // Authenticate via access_token in query or fragment
            let accessToken = (queryItems.first { $0.name == "access_token" }?.value) ?? fragmentItems["access_token"]
            let refreshToken = (queryItems.first { $0.name == "refresh_token" }?.value) ?? fragmentItems["refresh_token"]
            // Supabase also uses "token" in some flows; prefer invite_token to avoid collisions
            let inviteToken = (queryItems.first { $0.name == "invite_token" }?.value)
                ?? fragmentItems["invite_token"]
                ?? (queryItems.first { $0.name == "token" }?.value)
                ?? fragmentItems["token"]
            let linkType = fragmentItems["type"] ?? queryItems.first(where: { $0.name == "type" })?.value
            let email = (queryItems.first { $0.name == "email" }?.value) ?? fragmentItems["email"]

            print("🔑 Deep link tokens - access: \(accessToken != nil), refresh: \(refreshToken != nil), invite: \(inviteToken ?? "nil"), type: \(linkType ?? "nil"), email: \(email ?? "nil")")

            if let accessToken {
                print("✅ Received access token from deep link")
                Task { @MainActor in
                    let userId = (queryItems.first { $0.name == "user_id" }?.value)
                        ?? fragmentItems["user_id"]
                        ?? decodeSubFromJWT(accessToken)
                    authManager.applyDeepLinkSession(
                        accessToken: accessToken,
                        refreshToken: refreshToken,
                        userId: userId,
                        email: email
                    )
                    print("✅ User automatically authenticated via deep link (invite/auth)")

                    // After auth, if invite token present, accept and refresh
                    if let inviteToken {
                        do {
                            try await SupabaseManager.shared.acceptInvitation(token: inviteToken)
                            await SupabaseDataManager.shared.fetchUserDataIfNeeded()
                            print("✅ Invitation accepted and data refreshed")
                        } catch {
                            print("❌ Failed to accept invitation: \(error)")
                        }
                    } else if linkType == "invite" {
                        // Fallback: accept by current user's email via service-role function when token is missing
                        do {
                            try await SupabaseManager.shared.acceptInvitationForCurrentUserEmail()
                            await SupabaseDataManager.shared.fetchUserDataIfNeeded()
                            print("✅ Invitation accepted via email fallback and data refreshed")
                        } catch {
                            print("❌ Failed to accept invitation via email fallback: \(error)")
                        }
                    }

                    checkFamilySetupNeeded()

                    // If this was a recovery or invite link, prompt for new password
                    if linkType == "recovery" || linkType == "invite" {
                        resetPasswordEmail = email ?? authManager.userEmail
                        showResetPasswordSheet = true
                    }
                }
            } else if let inviteToken {
                // If no access token but we have invite token (rare), attempt accept if already authenticated
                Task { @MainActor in
                    do {
                        try await SupabaseManager.shared.acceptInvitation(token: inviteToken)
                        await SupabaseDataManager.shared.fetchUserDataIfNeeded()
                        print("✅ Invitation accepted and data refreshed")

                        checkFamilySetupNeeded()
                    } catch {
                        print("❌ Failed to accept invitation: \(error)")
                    }
                }
            }
        }
    }

    private func parseFragmentItems(_ fragment: String?) -> [String: String] {
        guard let fragment, !fragment.isEmpty else { return [:] }
        var dict: [String: String] = [:]
        fragment.split(separator: "&").forEach { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, let key = parts.first?.removingPercentEncoding,
               let value = parts.last?.removingPercentEncoding {
                dict[key] = value
            }
        }
        return dict
    }

    private func decodeSubFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        var base64 = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["sub"] as? String
    }

    private func runCalendarCheck() {
        Task { @MainActor in
            calendarCheckStatus = .checking
            print("🔍 Starting calendar check...")

            let status = EKEventStore.authorizationStatus(for: .event)
            print("📋 iOS Calendar permission status: \(status)")

            if status == .denied || status == .restricted || status == .notDetermined {
                print("❌ Calendar permission not granted")
                calendarCheckStatus = .ready
                return
            }

            let available = CalendarManager.shared.fetchAvailableCalendars()
            print("📅 Available iOS calendars: \(available.count)")

            if available.isEmpty {
                print("❌ No iOS calendars found on device")
                calendarCheckStatus = .ready
                return
            }

            // Check if authenticated user has family members without calendars
            if authManager.isAuthenticated && !authManager.isGuest {
                let familyMembers = dataManager.familyMembers
                print("👥 Family members: \(familyMembers.count)")
                print("🔗 Family member calendars in database: \(dataManager.familyMemberCalendars.count)")

                // Get iOS calendars available on this device
                let availableCalendars = CalendarManager.shared.fetchAvailableCalendars()
                let availableCalendarIds = Set(availableCalendars.map { $0.id })
                print("📱 iOS calendars on this device: \(availableCalendarIds.count)")

                // If there are family members, verify they all have at least one calendar that exists on this device
                if !familyMembers.isEmpty {
                    var missingCalendarsList: [CalendarCheckMissingInfo] = []

                    for member in familyMembers {
                        // Get personal calendars linked to this member
                        let memberCalendars = dataManager.familyMemberCalendars.filter { $0.family_member_id == member.id }

                        // Get shared calendars (via CoreData relationship if available)
                        var sharedCalendarNames: [String] = []
                        if let context = persistenceController.container.viewContext as NSManagedObjectContext? {
                            let memberFetch: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
                            memberFetch.predicate = NSPredicate(format: "id == %@", member.id as CVarArg)
                            if let coreMember = try? context.fetch(memberFetch).first,
                               let sharedCalendars = coreMember.sharedCalendars as? Set<SharedCalendar> {
                                sharedCalendarNames = Array(Set(sharedCalendars.compactMap { $0.calendarName }))
                                    .sorted()
                            }
                        }

                        // Deduplicate linked calendar names
                        let linkedCalendarNamesDeduped = Array(Set(memberCalendars.map { $0.calendar_name }))
                            .sorted()

                        // Check each linked calendar by NAME
                        // Find calendars whose names DON'T exist on this device
                        var missingCalendarNamesDeduped: [String] = []

                        for linkedCalendar in memberCalendars {
                            if availableCalendars.first(where: { $0.title == linkedCalendar.calendar_name }) != nil {
                                // Calendar name exists on this device!
                                print("  → \(member.name): Calendar '\(linkedCalendar.calendar_name)' found on device")
                            } else {
                                // Calendar name NOT found on this device
                                if !missingCalendarNamesDeduped.contains(linkedCalendar.calendar_name) {
                                    missingCalendarNamesDeduped.append(linkedCalendar.calendar_name)
                                }
                            }
                        }

                        print("  - \(member.name): linked=\(memberCalendars.count), missing on device=\(missingCalendarNamesDeduped.count)")

                        // Show in modal if member has ANY missing calendars that don't exist on this device
                        if !missingCalendarNamesDeduped.isEmpty {
                            missingCalendarsList.append(CalendarCheckMissingInfo(
                                memberName: member.name,
                                linkedCalendarNames: linkedCalendarNamesDeduped,
                                sharedCalendarNames: sharedCalendarNames,
                                missingCalendarNames: missingCalendarNamesDeduped
                            ))
                            print("  → \(member.name): Added to missing calendars (missing: \(missingCalendarNamesDeduped.count), linked: \(linkedCalendarNamesDeduped.count), shared: \(sharedCalendarNames.count))")
                        } else {
                            print("  → \(member.name): All calendar names found on device ✅")
                        }
                    }

                    if !missingCalendarsList.isEmpty {
                        // Some family members need calendar setup
                        print("⚠️ \(missingCalendarsList.count) family members need calendar setup on this device")
                        calendarCheckStatus = .familyMembersNeedSetup(missingCalendars: missingCalendarsList)
                        return
                    }
                }
            }

            print("✅ All checks passed - proceeding to main app")
            calendarCheckStatus = .ready
        }
    }
}

private struct SystemColorSchemeUpdater<Content: View>: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content

    var body: some View {
        content()
            .onAppear {
                themeManager.updateSystemColorScheme(colorScheme)
            }
            .onChange(of: colorScheme) { _, newScheme in
                themeManager.updateSystemColorScheme(newScheme)
            }
    }
}

private enum CalendarCheckStatus: Equatable {
    case unknown
    case checking
    case ready
    case familyMembersNeedSetup(missingCalendars: [CalendarCheckMissingInfo])
}

private struct CalendarCheckMissingInfo: Equatable {
    let memberName: String
    let linkedCalendarNames: [String]  // All personal calendars linked to this member (deduped)
    let sharedCalendarNames: [String]  // Shared calendars (deduped)
    let missingCalendarNames: [String] // Calendars in Supabase but missing on device (deduped)
}

/// Modal showing calendars for a single family member
private struct CalendarsModalView: View {
    let calendarInfo: CalendarCheckMissingInfo
    let theme: AppTheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Linked Personal Calendars
                        if !calendarInfo.linkedCalendarNames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Linked Personal Calendars")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)

                                ForEach(calendarInfo.linkedCalendarNames, id: \.self) { calendar in
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(theme.accentColor)
                                            .font(.system(size: 14))

                                        Text(calendar)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))
                                    }
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Shared Calendars
                        if !calendarInfo.sharedCalendarNames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Shared Calendars")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)

                                ForEach(calendarInfo.sharedCalendarNames, id: \.self) { calendar in
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(theme.accentColor)
                                            .font(.system(size: 14))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(calendar)
                                                .font(.system(size: 14))
                                                .foregroundColor(.primary)

                                            Text("Shared with all members")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "person.2.fill")
                                            .foregroundColor(theme.accentColor)
                                            .font(.system(size: 14))
                                    }
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Missing Calendars
                        if !calendarInfo.missingCalendarNames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Missing Calendars")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.red)

                                ForEach(calendarInfo.missingCalendarNames, id: \.self) { calendar in
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14))

                                        Text(calendar)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14))
                                    }
                                    .padding(12)
                                    .background(Color(.systemRed).opacity(0.1))
                                    .cornerRadius(8)
                                }

                                Text("These calendars need to be shared with you or removed from the member in Family Management.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Calendars for \(calendarInfo.memberName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Calendar gate view for checking if calendars exist on device
private struct CalendarGateView: View {
    @Binding var status: CalendarCheckStatus
    let onRetry: () -> Void
    let onLogout: () -> Void
    let theme: AppTheme
    let familyMembers: [FamilyMemberDTO]
    @State private var showingCalendarsModal = false
    @State private var selectedCalendarInfo: CalendarCheckMissingInfo?
    @Environment(\.managedObjectContext) private var viewContext

    private var title: String {
        return "Setup Family Calendars"
    }

    private var message: String {
        return "Some calendars are missing on this device."
    }

    private var missingCalendars: [CalendarCheckMissingInfo] {
        guard case .familyMembersNeedSetup(let missing) = status else {
            return []
        }
        return missing
    }

    var body: some View {
        ZStack {
            theme.backgroundLayer()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 24)

                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 56))
                            .foregroundColor(.orange)

                        Text(title)
                            .font(.system(size: 28, weight: .bold))

                        instructionsSection()
                            .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .padding(.horizontal, 16)

                    if status == .checking {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(theme.accentColor)
                            Text("Checking calendars...")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    }

                    VStack(spacing: 12) {
                        // Check Again Button (Primary)
                        Button {
                            onRetry()
                        } label: {
                            if status == .checking {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Check Again")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(theme.accentFillStyle())
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(status == .checking)

                        // Family Management Button (Secondary)
                        NavigationLink(destination: FamilySettingsView()) {
                            Text("Family Management")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }

                        // Logout Button (Tertiary)
                        Button {
                            onLogout()
                        } label: {
                            Text("Logout")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(theme.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .sheet(isPresented: $showingCalendarsModal) {
                        if let calendarInfo = selectedCalendarInfo {
                            CalendarsModalView(calendarInfo: calendarInfo, theme: theme)
                        }
                    }

                    Spacer()
                        .frame(height: 24)
                }
            }
        }
    }

    @ViewBuilder
    private func instructionsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Instruction 1
            instructionStep(
                number: "1",
                title: "Login with same Apple account",
                description: "Use the same Apple account used during initial setup"
            )

            // Instruction 2
            instructionStep(
                number: "2",
                title: "Ask owner to share calendars",
                description: "Request the calendar owner to share their calendars with you"
            )

            // Instruction 3
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(theme.accentColor))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("View calendars which are missing")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Click 'Check Missing Calendars' button")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // Instruction 4
            instructionStep(
                number: "4",
                title: "Remove calendars which no longer exist",
                description: "Delete missing calendars from members in Family Management"
            )

            // Instruction 5
            instructionStep(
                number: "5",
                title: "Logout and login as guest",
                description: "Or continue as guest if shared calendars aren't available"
            )
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func instructionStep(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.accentColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}
