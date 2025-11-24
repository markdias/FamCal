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
    
    @State private var showingAddMemberSheet = false
    
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
                    
                    // "Who are you?" Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHO ARE YOU?")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 16)
                        
                        settingsContainer {
                            if familyMembers.isEmpty {
                                Button(action: { showingAddMemberSheet = true }) {
                                    HStack {
                                        Text("Create a Profile")
                                            .foregroundColor(primaryTextColor)
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(theme.accentColor)
                                    }
                                    .padding()
                                }
                            } else {
                                ForEach(Array(familyMembers.enumerated()), id: \.element.id) { index, member in
                                    Button(action: { selectMember(member) }) {
                                        HStack {
                                            // Avatar/Color
                                            Circle()
                                                .fill(Color.fromHex(member.colorHex ?? "#808080"))
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Text(member.avatarInitials ?? "")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                            
                                            Text(member.name ?? "Unknown")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)
                                            
                                            Spacer()
                                            
                                            if isSelected(member) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(theme.accentColor)
                                            }
                                        }
                                        .padding()
                                    }
                                    
                                    if index < familyMembers.count - 1 {
                                        Divider().padding(.leading, 64)
                                    }
                                }
                                
                                Divider().padding(.leading, 16)
                                
                                Button(action: { showingAddMemberSheet = true }) {
                                    HStack {
                                        Text("Add Another Person")
                                            .font(.system(size: 16))
                                            .foregroundColor(theme.accentColor)
                                        Spacer()
                                        Image(systemName: "plus")
                                            .font(.system(size: 14))
                                            .foregroundColor(theme.accentColor)
                                    }
                                    .padding()
                                }
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
        .sheet(isPresented: $showingAddMemberSheet) {
            AddFamilyMemberView()
                .environment(\.managedObjectContext, viewContext)
        }
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
