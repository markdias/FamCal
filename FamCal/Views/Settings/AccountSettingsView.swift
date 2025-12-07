//
//  AccountSettingsView.swift
//  FamCal
//
//  Created by Mark Dias on 24/11/2025.
//

import SwiftUI
import CoreData

struct AccountSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authManager: SupabaseAuthManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    private let supabaseManager = SupabaseManager.shared

    @State private var showingFamilySettings = false
    @State private var refreshKey = UUID()
    @FetchRequest(entity: FamilyMember.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)])
    private var localFamilyMembers: FetchedResults<FamilyMember>

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    
    // Use in-memory Supabase data for names/emails instead of CoreData
    
    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Account Info Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(theme.accentColor)
                            .padding(.top, 20)
                        
                        VStack(spacing: 4) {
                            Text(authManager.userEmail ?? "Guest User")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(primaryTextColor)
                            
                            if authManager.isGuest {
                                Text("Not signed in")
                                    .font(.system(size: 14))
                                    .foregroundColor(secondaryTextColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)

                    // Family Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 16)

                        settingsContainer {
                            HStack {
                                Text("Family Name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(secondaryTextColor)

                                Spacer()

                                Text(appSettingsManager.familyName.isEmpty ? "Not set" : appSettingsManager.familyName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(primaryTextColor)
                            }
                            .padding()
                        }
                    }

                    // "Which family member are you?" Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Which family member are you?")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 16)

                        settingsContainer {
                            if authManager.isGuest {
                                // Guest users - show local member selection (always editable)
                                Menu {
                                    ForEach(localFamilyMembers, id: \.id) { member in
                                        Button(action: { selectMemberLocal(member) }) {
                                            HStack {
                                                Text(member.name ?? "Unknown")
                                                if isSelectedLocal(member.id) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(getDisplayName())
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(primaryTextColor)

                                        Spacer()

                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    .padding()
                                }
                            } else if appSettingsManager.linkedFamilyMemberId != nil {
                                // Authenticated user with linked member - show locked view
                                HStack {
                                    Text(getDisplayName())
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)

                                    Spacer()

                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.orange)
                                }
                                .padding()
                            } else {
                                // Authenticated user without linked member - show menu to select
                                Menu {
                                    ForEach(dataManager.familyMembers.filter { $0.linked_user_id == nil }, id: \.id) { member in
                                        Button(action: { selectMember(member) }) {
                                            HStack {
                                                Text(member.name)
                                                if isSelected(member.id) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(getDisplayName())
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(primaryTextColor)

                                        Spacer()

                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                    
                    // Family Management Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family Management")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 16)
                        
                        settingsContainer {
                            Button(action: { showingFamilySettings = true }) {
                                HStack {
                                    Image(systemName: "person.3.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(theme.accentColor)
                                    
                                    Text("My Family")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)
                                    
                                    Spacer()

                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(secondaryTextColor.opacity(0.6))
                                }
                                .padding()
                            }
                        }
                    }

                    // Sign Out Section
                    VStack(alignment: .leading, spacing: 8) {
                        settingsContainer {
                            Button(role: .destructive) {
                                Task {
                                    try? await authManager.signOut()
                                    // Reset onboarding state on logout
                                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text("Sign Out")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                    Spacer()
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                                .padding()
                            }
                        }
                    }

                    // Delete Account Section (authenticated users only)
                    if !authManager.isGuest {
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationLink(destination: AccountDeletionView()) {
                                settingsContainer {
                                    HStack {
                                        Text("Delete Account")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.red)
                                        Spacer()
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Refresh CoreData to ensure latest member data is loaded
            do {
                _ = try viewContext.fetch(FamilyMember.fetchRequest())
            } catch {
                print("⚠️ Error refreshing family members: \(error)")
            }
        }
        .sheet(isPresented: $showingFamilySettings) {
            FamilySettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private func getDisplayName() -> String {
        if let linkedId = appSettingsManager.linkedFamilyMemberId {
            // For guests, check local CoreData members
            if authManager.isGuest {
                if let uuid = UUID(uuidString: linkedId),
                   let member = localFamilyMembers.first(where: { $0.id == uuid }) {
                    return member.name ?? "Unknown"
                }
            } else {
                // For authenticated users, check both Supabase in-memory data AND CoreData
                // This ensures we show the name even if Supabase data hasn't loaded yet
                if let member = dataManager.familyMembers.first(where: { $0.id == linkedId }) {
                    return member.name
                }

                // Fallback to CoreData if Supabase data not yet loaded
                if let uuid = UUID(uuidString: linkedId),
                   let member = localFamilyMembers.first(where: { $0.id == uuid }) {
                    return member.name ?? "Unknown"
                }
            }
        }
        // Last resort: show email or selection prompt
        if authManager.isAuthenticated {
            return authManager.userEmail ?? "Select a member"
        }
        return "Select a member"
    }

    private func isSelected(_ memberId: String) -> Bool {
        guard let linkedId = appSettingsManager.linkedFamilyMemberId else { return false }
        return memberId == linkedId
    }

    private func isSelectedLocal(_ memberId: UUID?) -> Bool {
        guard let linkedIdString = appSettingsManager.linkedFamilyMemberId,
              let linkedId = UUID(uuidString: linkedIdString),
              let memberId = memberId else { return false }
        return memberId == linkedId
    }

    private func selectMemberLocal(_ member: FamilyMember) {
        guard let memberId = member.id else { return }

        // Update local state immediately for UI responsiveness
        appSettingsManager.linkedFamilyMemberId = memberId.uuidString

        // Save to AppSettingsManager (persists to UserDefaults)
        Task {
            await appSettingsManager.saveSettings()
            print("✅ Linked guest user to family member \(member.name ?? "Unknown")")
        }
    }

    private func selectMember(_ member: FamilyMemberDTO) {
        let id = member.id

        // Update local state immediately for UI responsiveness
        appSettingsManager.linkedFamilyMemberId = id

        // Only attempt Supabase sync for authenticated users
        guard !authManager.isGuest else {
            print("⚠️ Skipping Supabase sync for guest user")
            Task {
                await appSettingsManager.saveSettings()
            }
            return
        }

        // Persist to Supabase and link the member to this user
        Task {
            do {
                // Clear links, then link to the selected member
                try await supabaseManager.relinkCurrentUser(to: id, familyId: member.family_id)
                await appSettingsManager.saveSettings()
                await dataManager.fetchUserDataIfNeeded()
                print("✅ Linked user to family member \(member.name)")
            } catch {
                print("❌ Failed to link user to family member: \(error)")
            }
        }
    }
    
    private func settingsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
        .padding(.horizontal, 16)
    }
}
