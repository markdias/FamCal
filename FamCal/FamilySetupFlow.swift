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
    @StateObject private var appSettingsManager = AppSettingsManager.shared
    @StateObject private var dataManager = SupabaseDataManager.shared
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

            // Mark family setup as complete
            await MainActor.run {
                appSettingsManager.familyName = familyName
                appSettingsManager.hasCompletedFamilySetup = true
                appSettingsManager.linkedFamilyMemberId = selectedMemberId?.uuidString
                UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")

                let context = viewContext
                do {
                    try FamilyInfoStore.upsert(name: familyName, familyId: nil as String?, in: context)
                } catch {
                    print("⚠️ Failed to persist family name locally: \(error)")
                }
            }

            // Save settings to Supabase if authenticated
            if !SupabaseAuthManager.shared.isGuest {
                await appSettingsManager.saveSettings()
            }

            // Sync family setup to cloud
            await dataManager.syncFamilySetup()

            print("✅ Family setup completed successfully")
        }
    }
}

#Preview {
    FamilySetupFlow()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
