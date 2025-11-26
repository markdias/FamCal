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
// import GoogleSignIn - Enable in Xcode GUI after uncommenting GoogleSignIn pod

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
    @State private var calendarCheckStatus: CalendarCheckStatus = .unknown
    @State private var hasLoadedCalendarCheckStatus = false

    /// Load persisted calendar check status on app launch
    private func loadCalendarCheckStatus() {
        // Only load once per session
        guard !hasLoadedCalendarCheckStatus else { return }
        hasLoadedCalendarCheckStatus = true

        // If user is authenticated and previously passed the check, skip showing gate
        if authManager.isAuthenticated && !authManager.isGuest {
            // Use user-specific key to differentiate between different accounts
            let userKey = "hasPassedCalendarCheck_\(authManager.userEmail ?? "unknown")"
            if UserDefaults.standard.bool(forKey: userKey) {
                calendarCheckStatus = .ready
                print("✅ Calendar check previously passed for \(authManager.userEmail ?? "user") - skipping gate")
            }
        }
    }

    /// Persist calendar check status when it becomes ready
    private func saveCalendarCheckStatus() {
        if case .ready = calendarCheckStatus {
            // Use user-specific key to store per-account
            let userKey = "hasPassedCalendarCheck_\(authManager.userEmail ?? "unknown")"
            UserDefaults.standard.set(true, forKey: userKey)
            print("💾 Saved calendar check status: passed for \(authManager.userEmail ?? "user")")
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

        // Initialize Google Mobile Ads SDK
        // Commented out due to pod configuration issues - will be initialized separately
        // MobileAds.initialize()
        // print("📱 Google Mobile Ads SDK initialized")

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
        guard case .ready = calendarCheckStatus else {
            return false
        }
        return true
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
                    // If authenticated (non-guest) but calendars/family setup needed, block until ready
                    if authManager.isAuthenticated && !authManager.isGuest && !isCalendarCheckReady {
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

                            // Load persisted calendar check status on first appearance of gate
                            if !hasLoadedCalendarCheckStatus {
                                loadCalendarCheckStatus()
                            }

                            Task {
                                await appSettingsManager.loadSettings()
                                await dataManager.fetchUserData()
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
            .preferredColorScheme(themeManager.selectedTheme.prefersDarkInterface ? .dark : .light)
            .onOpenURL(perform: handleDeepLink(_:))
            .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
                // Only handle actual state changes, not first load
                // Keep onboarding completion sticky; only reset on logout
                if !isFirstLoad && oldValue != newValue {
                    if newValue {
                        // User just logged in - reset check status and flag (check will run in gate view)
                        calendarCheckStatus = .unknown
                        hasLoadedCalendarCheckStatus = false
                    } else {
                        // User just logged out - clear persisted calendar check status for this user
                        calendarCheckStatus = .unknown
                        hasLoadedCalendarCheckStatus = false
                        if let email = authManager.userEmail {
                            let userKey = "hasPassedCalendarCheck_\(email)"
                            UserDefaults.standard.set(false, forKey: userKey)
                            print("🔄 User \(email) logged out - reset calendar check status")
                        }
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
                if authManager.isGuest {
                    calendarCheckStatus = .ready
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

                        // Check each linked calendar by NAME (not ID)
                        // Find calendars whose names DON'T exist on this device
                        var missingCalendarNamesDeduped: [String] = []
                        var newCalendarIdsToUpdate: [(calendarName: String, newCalendarId: String)] = []

                        for linkedCalendar in memberCalendars {
                            if let matchingCalendar = availableCalendars.first(where: { $0.title == linkedCalendar.calendar_name }) {
                                // Calendar name exists on this device!
                                // Check if calendar_id is different (device-specific)
                                if matchingCalendar.id != linkedCalendar.calendar_id {
                                    print("  → \(member.name): Found '\(linkedCalendar.calendar_name)' on device with different ID. Updating: \(linkedCalendar.calendar_id) → \(matchingCalendar.id)")
                                    newCalendarIdsToUpdate.append((calendarName: linkedCalendar.calendar_name, newCalendarId: matchingCalendar.id))
                                } else {
                                    print("  → \(member.name): Calendar '\(linkedCalendar.calendar_name)' found with matching ID")
                                }
                            } else {
                                // Calendar name NOT found on this device
                                if !missingCalendarNamesDeduped.contains(linkedCalendar.calendar_name) {
                                    missingCalendarNamesDeduped.append(linkedCalendar.calendar_name)
                                }
                            }
                        }

                        // Update Supabase with new calendar IDs if any found
                        // Capture the array before the Task closure to avoid mutation issues
                        if !newCalendarIdsToUpdate.isEmpty {
                            let updatesToProcess = newCalendarIdsToUpdate
                            let memberId = member.id
                            Task {
                                for (calendarName, newId) in updatesToProcess {
                                    await dataManager.updateFamilyMemberCalendarId(
                                        memberId: memberId,
                                        calendarName: calendarName,
                                        newCalendarId: newId
                                    )
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
