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
                    
                    .padding(.bottom, 10)
                    
                    // Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        settingsContainer {
                            HStack {
                                Text("Name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(secondaryTextColor)
                                
                                Spacer()
                                
                                Text(getDisplayName())
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
                            Menu {
                                ForEach(dataManager.familyMembers, id: \.id) { member in
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
                                    
                                    Image(systemName: "chevron.right")
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
                    
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFamilySettings) {
            FamilySettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private func getDisplayName() -> String {
        if let linkedId = appSettingsManager.linkedFamilyMemberId,
           let member = dataManager.familyMembers.first(where: { $0.id == linkedId }) {
            return member.name
        }
        // Fallback to email to avoid "Select a member" when user is linked but data not yet loaded
        return authManager.userEmail ?? "Select a member"
    }
    
    private func isSelected(_ memberId: String) -> Bool {
        guard let linkedId = appSettingsManager.linkedFamilyMemberId else { return false }
        return memberId == linkedId
    }
    
    private func selectMember(_ member: FamilyMemberDTO) {
        let id = member.id

        // Update local state immediately for UI responsiveness
        appSettingsManager.linkedFamilyMemberId = id

        // Persist to Supabase and link the member to this user
        Task {
            do {
                try await supabaseManager.linkCurrentUserToFamilyMember(id: id)
                await appSettingsManager.saveSettings()
                await dataManager.fetchUserData()
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
