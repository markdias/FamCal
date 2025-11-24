//
//  SettingsView.swift
//  FamCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authManager: SupabaseAuthManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @State private var showingFamilySettings = false
    @State private var showingAppSettings = false
    @State private var showingNotifications = false
    @State private var showingPermissions = false
    @State private var showingWidgetSettings = false
    @State private var showingHelp = false
    @State private var showingOnboarding = false
    @State private var onboardingCompletedInSettings = false
    
    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: []
    )
    private var familyMembers: FetchedResults<FamilyMember>

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                theme.backgroundLayer()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Premium Banner
                        PremiumBannerView()
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                            .padding(.vertical, 8)
                        }
                        
                        // Account Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)
                            
                            settingsContainer {
                                NavigationLink(destination: AccountSettingsView()
                                    .environment(\.managedObjectContext, viewContext)
                                    .environmentObject(themeManager)
                                    .environmentObject(authManager)
                                    .environmentObject(appSettingsManager)
                                    .environmentObject(dataManager)
                                ) {
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(theme.accentColor)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Signed in as")
                                                .font(.caption)
                                                .foregroundColor(secondaryTextColor)
                                            Text(getDisplayName())
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(primaryTextColor)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(secondaryTextColor.opacity(0.6))
                                    }
                                    .padding()
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        // Settings Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Settings")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)
                            
                            settingsContainer {
                                Button(action: { showingFamilySettings = true }) {
                                    SettingsRowView(iconName: "person.circle", title: "My Family")
                                }
                                Divider().padding(.leading, 56)
                                
                                Button(action: { showingPermissions = true }) {
                                    SettingsRowView(iconName: "lock", title: "Permissions")
                                }
                                Divider().padding(.leading, 56)
                                
                                Button(action: { showingNotifications = true }) {
                                    SettingsRowView(iconName: "bell", title: "Notifications", showChevron: true)
                                }
                                Divider().padding(.leading, 56)
                                
                                Button(action: { showingAppSettings = true }) {
                                    SettingsRowView(iconName: "gearshape", title: "App Settings")
                                }
                                Divider().padding(.leading, 56)

                                Button(action: { showingWidgetSettings = true }) {
                                    SettingsRowView(iconName: "square.grid.2x2", title: "Widgets")
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // More Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("More")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                Button(action: { /* Rate & Review Action */ }) {
                                    SettingsRowView(iconName: "star.bubble", title: "Rate & Review")
                                }
                                Divider().padding(.leading, 56)

                                Button(action: { showingHelp = true }) {
                                    SettingsRowView(iconName: "questionmark.circle", title: "Help")
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        // Testing Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Testing")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                Button(action: {
                                    onboardingCompletedInSettings = false
                                    showingOnboarding = true
                                }) {
                                    SettingsRowView(iconName: "play.circle", title: "Run Startup Workflow")
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFamilySettings) {
            FamilySettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(appSettingsManager)
                .environmentObject(themeManager)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationView {
                NotificationSettingsView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(appSettingsManager)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingPermissions) {
            NavigationView {
                PermissionsView()
            }
        }
        .sheet(isPresented: $showingWidgetSettings) {
            NavigationView {
                WidgetSettingsView()
                    .environmentObject(appSettingsManager)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(hasCompletedOnboarding: $onboardingCompletedInSettings)
                .onChange(of: onboardingCompletedInSettings) { _, newValue in
                    if newValue {
                        showingOnboarding = false
                    }
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
    
    private func getDisplayName() -> String {
        if let linkedId = appSettingsManager.linkedFamilyMemberId,
           let member = familyMembers.first(where: { $0.id?.uuidString == linkedId }) {
            return member.name ?? "Unknown"
        }
        
        if authManager.isGuest {
            return "Guest"
        }
        
        return authManager.userEmail ?? "Unknown"
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
