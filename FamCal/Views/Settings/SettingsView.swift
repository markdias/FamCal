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
    @State private var showingThemeSettings = false
    @State private var showingSharedCalendars = false
    @State private var showingPersonalCalendars = false
    @State private var showingSavedPlaces = false
    @State private var showingDrivers = false
    @State private var showingHelp = false
    @State private var showingOnboarding = false
    @State private var onboardingCompletedInSettings = false
    @State private var showingProSheet = false
    @State private var showingDonate = false
    @State private var showingFeedback = false
    private var proToggleBinding: Binding<Bool> {
        Binding(
            get: { appSettingsManager.isProUser },
            set: {
                appSettingsManager.isProUser = $0
                if !$0 {
                    themeManager.select(theme: .classic)
                }
                Task { await appSettingsManager.saveSettings() }
            }
        )
    }
    
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
                        PremiumBannerView(isPro: appSettingsManager.isProUser) {
                            showingProSheet = true
                        }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        

                        
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

                                        Image(systemName: "pencil")
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
                                Button(action: { showingNotifications = true }) {
                                    SettingsRowView(iconName: "bell", title: "Notifications", showChevron: true)
                                }
                                Divider().padding(.leading, 56)

                                Button(action: { showingAppSettings = true }) {
                                    SettingsRowView(iconName: "gearshape", title: "App Settings", showChevron: true)
                                }
                                Divider().padding(.leading, 56)

                                Button(action: { showingPersonalCalendars = true }) {
                                    SettingsRowView(iconName: "calendar", title: "Personal Calendars", showChevron: true)
                                }
                                Divider().padding(.leading, 56)

                                Button(action: { showingSharedCalendars = true }) {
                                    SettingsRowView(iconName: "calendar.badge.plus", title: "Shared Calendars", showChevron: true)
                                }
                                if !appSettingsManager.isProUser {
                                    HStack {
                                        Text("Currently limited to 1")
                                            .font(.system(size: 13))
                                            .foregroundColor(secondaryTextColor)
                                        Spacer()
                                    }
                                    .padding(.leading, 56)
                                    .padding(.trailing, 16)
                                    .padding(.top, -8)
                                    .padding(.bottom, 12)
                                }
                                Divider().padding(.leading, 56)

                                if appSettingsManager.isProUser {
                                    Button(action: { showingThemeSettings = true }) {
                                        SettingsRowView(iconName: "paintpalette", title: "Themes", showChevron: true)
                                    }
                                } else {
                                    HStack(spacing: 16) {
                                        Image(systemName: "paintpalette")
                                            .font(.system(size: 20))
                                            .foregroundColor(theme.accentColor)
                                            .frame(width: 24, height: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Themes")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)
                                            Text("Premium color themes")
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }

                                        Spacer()

                                        Text("Pro")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(theme.accentColor)
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                Divider().padding(.leading, 56)

                                if appSettingsManager.isProUser {
                                    Button(action: { showingSavedPlaces = true }) {
                                        SettingsRowView(iconName: "mappin.circle", title: "Saved Places", showChevron: true)
                                    }
                                } else {
                                    HStack(spacing: 16) {
                                        Image(systemName: "mappin.circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(theme.accentColor)
                                            .frame(width: 24, height: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Saved Places")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)
                                            Text("Store favorite places")
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }

                                        Spacer()

                                        Text("Pro")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(theme.accentColor)
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                Divider().padding(.leading, 56)

                                if appSettingsManager.isProUser {
                                    Button(action: { showingDrivers = true }) {
                                        SettingsRowView(iconName: "car.fill", title: "Drivers", showChevron: true)
                                    }
                                } else {
                                    HStack(spacing: 16) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(theme.accentColor)
                                            .frame(width: 24, height: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Drivers")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)
                                            Text("Pickup planning")
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }

                                        Spacer()

                                        Text("Pro")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(theme.accentColor)
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                Divider().padding(.leading, 56)

                                if appSettingsManager.isProUser {
                                    Button(action: { showingWidgetSettings = true }) {
                                        SettingsRowView(iconName: "sparkles", title: "Widgets", showChevron: true)
                                    }
                                } else {
                                    HStack(spacing: 16) {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.system(size: 20))
                                            .foregroundColor(theme.accentColor)
                                            .frame(width: 24, height: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Widgets")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)
                                            Text("Add home widgets")
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }

                                        Spacer()

                                        Text("Pro")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(theme.accentColor)
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
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
                                Button(action: { showingFeedback = true }) {
                                    SettingsRowView(iconName: "bubbles.and.sparkles", title: "Feedback")
                                }
                                Divider().padding(.leading, 56)

                                Button(action: { showingPermissions = true }) {
                                    SettingsRowView(iconName: "lock", title: "Permissions")
                                }
                                Divider().padding(.leading, 56)

                                Button(action: { showingDonate = true }) {
                                    SettingsRowView(iconName: "heart.fill", title: "Donate")
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
                            Text("Test Only")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                HStack(spacing: 16) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(theme.accentColor)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Enable FamCal Pro")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(primaryTextColor)
                                        Text("Test unlocks for membership-only features")
                                            .font(.system(size: 13))
                                            .foregroundColor(secondaryTextColor)
                                    }

                                    Spacer()

                                    Toggle("", isOn: proToggleBinding)
                                        .labelsHidden()
                                        .tint(theme.accentColor)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                Divider().padding(.leading, 56)

                                Button(action: {
                                    onboardingCompletedInSettings = false
                                    showingOnboarding = true
                                }) {
                                    SettingsRowView(iconName: "play.circle", title: "Run Startup Workflow")
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        // App Footer
                        VStack(spacing: 12) {
                            if let uiImage = UIImage(named: "outline-icon") {
                                Image(uiImage: uiImage)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(secondaryTextColor)
                                    .frame(width: 48, height: 48)
                            } else if let image = UIImage(contentsOfFile: Bundle.main.path(forResource: "outline-icon", ofType: "png") ?? "") {
                                Image(uiImage: image)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(secondaryTextColor)
                                    .frame(width: 48, height: 48)
                            }

                            Text("FamCal \(getAppVersion())")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
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
        .sheet(isPresented: $showingThemeSettings) {
            NavigationView {
                ThemeSettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
        }
        .sheet(isPresented: $showingSharedCalendars) {
            NavigationView {
                SharedCalendarsView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(appSettingsManager)
                    .environmentObject(themeManager)
                    .environmentObject(dataManager)
            }
        }
        .sheet(isPresented: $showingPersonalCalendars) {
            NavigationView {
                PersonalCalendarsView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(appSettingsManager)
                    .environmentObject(themeManager)
                    .environmentObject(dataManager)
            }
        }
        .sheet(isPresented: $showingSavedPlaces) {
            NavigationView {
                SavedAddressesSettingsView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(themeManager)
                    .environmentObject(dataManager)
            }
        }
        .sheet(isPresented: $showingDrivers) {
            DriversListView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(themeManager)
                .environmentObject(dataManager)
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
        .sheet(isPresented: $showingFeedback) {
            FeedbackView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingDonate) {
            DonateView()
                .environmentObject(themeManager)
        }
        .fullScreenCover(isPresented: $showingProSheet) {
            FamCalProView()
                .environmentObject(appSettingsManager)
                .environmentObject(themeManager)
                .environmentObject(authManager)
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
           let member = dataManager.familyMembers.first(where: { $0.id == linkedId }) {
            return member.name
        }

        if authManager.isGuest {
            return "Guest"
        }

        return authManager.userEmail ?? "Unknown"
    }

    private func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0"
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
        .environmentObject(AppSettingsManager())
        .environmentObject(SupabaseAuthManager.shared)
        .environmentObject(SupabaseDataManager.shared)
}
