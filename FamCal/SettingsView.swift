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
    @State private var showingFamilySettings = false
    @State private var showingAppSettings = false
    @State private var showingNotifications = false
    @State private var showingPermissions = false
    @State private var showingWidgetSettings = false
    @State private var showingHelp = false
    
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
                        
                        Spacer(minLength: 40)
                        
                        // Log out
                        Button(action: {
                            // Log out action
                        }) {
                            HStack {
                                Image(systemName: "arrow.left.square")
                                Text("Log out")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                        }
                        .padding(.bottom, 20)
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
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationView {
                NotificationSettingsView()
                    .environment(\.managedObjectContext, viewContext)
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
            }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
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

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
