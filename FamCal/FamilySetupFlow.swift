//
//  FamilySetupFlow.swift
//  FamCal
//
//  Orchestrates the family setup wizard for new users
//

import SwiftUI
import CoreData

struct FamilySetupFlow: View {
    enum SetupStep {
        case familyName
        case addMembers
        case sharedCalendars
        case selectMember
        case complete
    }

    @Environment(\.managedObjectContext) var viewContext
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @State private var currentStep: SetupStep = .familyName
    @State private var familyName: String = ""
    @State private var familyMembers: [FamilyMember] = []
    @State private var selectedMemberId: UUID?
    @State private var sharedCalendars: [SharedCalendar] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VStack {
                switch currentStep {
                case .familyName:
                    FamilyNameSetupView(
                        familyName: $familyName,
                        onNext: advanceToAddMembers
                    )

                case .addMembers:
                    AddMembersSetupView(
                        familyMembers: $familyMembers,
                        onNext: advanceToSharedCalendars,
                        onBack: goToFamilyName
                    )

                case .sharedCalendars:
                    SharedCalendarsSetupView(
                        sharedCalendars: $sharedCalendars,
                        onNext: advanceToSelectMember,
                        onBack: goToAddMembers
                    )

                case .selectMember:
                    SelectYourMemberSetupView(
                        familyMembers: familyMembers,
                        selectedMemberId: $selectedMemberId,
                        onNext: advanceToComplete,
                        onBack: goToSharedCalendars
                    )

                case .complete:
                    FamilySetupCompleteView(
                        familyName: familyName,
                        memberCount: familyMembers.count,
                        onStart: completeSetup
                    )
                }
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .disabled(isLoading)
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Navigation Handlers

    private func advanceToAddMembers() {
        withAnimation {
            currentStep = .addMembers
        }
    }

    private func advanceToSharedCalendars() {
        withAnimation {
            currentStep = .sharedCalendars
        }
    }

    private func advanceToSelectMember() {
        withAnimation {
            currentStep = .selectMember
        }
    }

    private func advanceToComplete() {
        withAnimation {
            currentStep = .complete
        }
    }

    private func goToFamilyName() {
        withAnimation {
            currentStep = .familyName
        }
    }

    private func goToAddMembers() {
        withAnimation {
            currentStep = .addMembers
        }
    }

    private func goToSharedCalendars() {
        withAnimation {
            currentStep = .sharedCalendars
        }
    }

    private func completeSetup() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let isGuest = SupabaseAuthManager.shared.isGuest
                var familyId: String

                if isGuest {
                    // For guest users: generate a local family_id and store everything locally
                    print("👤 Guest mode - creating local family...")
                    familyId = UUID().uuidString
                    print("✅ Local family created with ID: \(familyId)")

                    // Store family info locally
                    await MainActor.run {
                        appSettingsManager.familyId = familyId
                        appSettingsManager.familyName = familyName
                        appSettingsManager.hasCompletedFamilySetup = true
                        appSettingsManager.linkedFamilyMemberId = selectedMemberId?.uuidString

                        UserDefaults.standard.set(familyId, forKey: "com.famcal.familyId")
                        UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")

                        let context = viewContext
                        do {
                            try FamilyInfoStore.upsert(name: familyName, familyId: familyId, in: context)
                        } catch {
                            print("⚠️ Failed to persist family info locally: \(error)")
                        }
                    }

                    print("✅ Guest family setup completed locally")
                } else {
                    // For authenticated users: create family in Supabase
                    guard let userId = SupabaseAuthManager.shared.userId else {
                        await MainActor.run {
                            errorMessage = "User ID not available. Please sign in again."
                        }
                        return
                    }

                    print("📤 Creating family in Supabase...")
                    let createdFamily = try await SupabaseManager.shared.createFamily(
                        ownerUserId: userId,
                        familyName: familyName
                    )
                    familyId = createdFamily.id
                    print("✅ Family created with ID: \(familyId)")

                    // Step 2: Update profile.family_id
                    print("📤 Updating profile with family_id...")
                    try await SupabaseManager.shared.updateProfileFamilyId(familyId: familyId)
                    print("✅ Profile updated with family_id")

                    // Step 3: Create family members in Supabase with family_id
                    print("📤 Creating \(familyMembers.count) family members...")
                    var selectedMemberSupabaseId: String?
                    for member in familyMembers {
                        let createdMember = try await SupabaseManager.shared.createFamilyMember(
                            userId: userId,
                            name: member.name ?? "",
                            colorHex: member.colorHex ?? "#007AFF",
                            token: SupabaseAuthManager.shared.accessToken
                        )
                        // If this is the selected member, store their Supabase ID for linking
                        if member.id == selectedMemberId {
                            selectedMemberSupabaseId = createdMember.id
                        }
                    }
                    print("✅ All family members created")

                    // Step 3b: Link authenticated user to their selected family member
                    if let memberSupabaseId = selectedMemberSupabaseId {
                        print("📤 Linking user to family member: \(memberSupabaseId)...")
                        try await SupabaseManager.shared.linkCurrentUserToFamilyMember(
                            id: memberSupabaseId,
                            token: SupabaseAuthManager.shared.accessToken
                        )
                        print("✅ User linked to family member")

                        // Update AppSettingsManager with the Supabase member ID for future reference
                        await MainActor.run {
                            appSettingsManager.linkedFamilyMemberId = memberSupabaseId
                        }
                    }

                    // Step 4: Create shared calendars in Supabase with family_id
                    if !sharedCalendars.isEmpty {
                        print("📤 Creating \(sharedCalendars.count) shared calendars...")
                        for calendar in sharedCalendars {
                            _ = try await SupabaseManager.shared.createSharedCalendar(
                                familyId: familyId,
                                calendarId: calendar.calendarID ?? "",
                                calendarName: calendar.calendarName ?? "",
                                calendarColorHex: calendar.calendarColorHex ?? "#007AFF",
                                token: SupabaseAuthManager.shared.accessToken
                            )
                        }
                        print("✅ All shared calendars created")
                    }

                    // Step 5: Store family_id and setup info locally
                    await MainActor.run {
                        appSettingsManager.familyId = familyId
                        appSettingsManager.familyName = familyName
                        appSettingsManager.hasCompletedFamilySetup = true
                        // linkedFamilyMemberId is already set in step 3b with the Supabase member ID

                        UserDefaults.standard.set(familyId, forKey: "com.famcal.familyId")
                        UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")

                        let context = viewContext
                        do {
                            try FamilyInfoStore.upsert(name: familyName, familyId: familyId, in: context)
                        } catch {
                            print("⚠️ Failed to persist family info locally: \(error)")
                        }
                    }

                    // Step 6: Save settings to Supabase
                    await appSettingsManager.saveSettings()

                    if !isGuest {
                        print("🔄 Refreshing Supabase data after setup...")
                        await dataManager.fetchUserData()
                    }
                }

                print("✅ Family setup completed successfully with family_id: \(familyId)")

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to complete setup: \(error.localizedDescription)"
                    print("❌ Setup error: \(error)")
                }
            }
        }
    }
}

#Preview {
    FamilySetupFlow()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
