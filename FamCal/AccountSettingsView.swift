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
    
    @State private var showingFamilySettings = false
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    
    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FamilyMember.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)
        ]
    )
    private var familyMembers: FetchedResults<FamilyMember>
    
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
                                ForEach(familyMembers, id: \.id) { member in
                                    Button(action: { selectMember(member) }) {
                                        HStack {
                                            Text(member.name ?? "Unknown")
                                            if isSelected(member) {
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
           let member = familyMembers.first(where: { $0.id?.uuidString == linkedId }) {
            return member.name ?? "Unknown"
        }
        return "Select a member"
    }
    
    private func isSelected(_ member: FamilyMember) -> Bool {
        guard let linkedId = appSettingsManager.linkedFamilyMemberId else { return false }
        return member.id?.uuidString == linkedId
    }
    
    private func selectMember(_ member: FamilyMember) {
        guard let id = member.id?.uuidString else { return }
        
        // Update local state immediately for UI responsiveness
        appSettingsManager.linkedFamilyMemberId = id
        
        // Persist to Supabase
        Task {
            await appSettingsManager.saveSettings()
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
