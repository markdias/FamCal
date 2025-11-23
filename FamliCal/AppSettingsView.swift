//
//  AppSettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import CoreData

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Int = 5
    @AppStorage("defaultMapsApp") private var defaultMapsApp: String = "Apple Maps"
    @AppStorage("defaultHomeScreen") private var defaultHomeScreenRawValue: String = DefaultHomeScreen.family.rawValue

    @AppStorage("eventsPerPerson") private var eventsPerPerson: Int = 3
    @AppStorage("spotlightEventsPerPerson") private var spotlightEventsPerPerson: Int = 5
    @AppStorage("nextEventColumns") private var nextEventColumns: Int = 2
    @AppStorage("eventsPastDays") private var eventsPastDays: Int = 90
    @AppStorage("eventsFutureDays") private var eventsFutureDays: Int = 180
    @AppStorage("defaultAlertOption") private var defaultAlertOptionRawValue: String = AlertOption.none.rawValue

    private let mapsAppOptions = ["Apple Maps", "Google Maps", "Waze"]
    private let refreshIntervalOptions: [Int] = [1, 5, 10, 15, 30, 60]

    private var defaultHomeScreenBinding: Binding<DefaultHomeScreen> {
        Binding(
            get: { DefaultHomeScreen(rawValue: defaultHomeScreenRawValue) ?? .family },
            set: { defaultHomeScreenRawValue = $0.rawValue }
        )
    }

    private var defaultAlertBinding: Binding<AlertOption> {
        Binding(
            get: { AlertOption(rawValue: defaultAlertOptionRawValue) ?? .none },
            set: { defaultAlertOptionRawValue = $0.rawValue }
        )
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { themeManager.isDarkModeEnabled },
            set: { themeManager.setDarkMode($0) }
        )
    }
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    private var toggleColor: Color { theme.accentGradient?.colors.first ?? theme.accentColor }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - General Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("General")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                settingCard(
                                    title: "Default screen",
                                    subtitle: "Choose where the app opens",
                                    picker: AnyView(
                                        Picker("Default Screen", selection: defaultHomeScreenBinding) {
                                            ForEach(DefaultHomeScreen.allCases) { option in
                                                Text(option.displayName).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                                
                                Divider().padding(.leading, 16)
                                
                                settingCard(
                                    title: "Auto refresh interval",
                                    subtitle: "Minutes between auto-refresh",
                                    picker: AnyView(
                                        Picker("Refresh Interval", selection: $autoRefreshInterval) {
                                            ForEach(refreshIntervalOptions, id: \.self) { option in
                                                Text(option == 1 ? "1 minute" : "\(option) minutes")
                                                    .tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                                
                                Divider().padding(.leading, 16)
                                
                                settingCard(
                                    title: "Default maps app",
                                    subtitle: "App to use for location links",
                                    picker: AnyView(
                                        Picker("Maps App", selection: $defaultMapsApp) {
                                            ForEach(mapsAppOptions, id: \.self) { app in
                                                Text(app).tag(app)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                                

                            }
                        }

                        // MARK: - Display Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                NavigationLink(destination: ThemeSettingsView()) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Theme")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)

                                            Text(themeManager.selectedTheme.displayName)
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(secondaryTextColor.opacity(0.6))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                
                                Divider().padding(.leading, 16)
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Dark mode")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(primaryTextColor)

                                        Text("Apply dark colors to current theme")
                                            .font(.system(size: 13))
                                            .foregroundColor(secondaryTextColor)
                                    }

                                    Spacer()

                                    Toggle("", isOn: darkModeBinding)
                                        .tint(toggleColor)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }

                        // MARK: - Event Settings Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event Settings")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                settingCard(
                                    title: "Events per person",
                                    subtitle: "How many upcoming events to show",
                                    picker: AnyView(
                                        Picker("Events", selection: $eventsPerPerson) {
                                            ForEach(1...10, id: \.self) { number in
                                                Text("\(number)").tag(number)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                                
                                Divider().padding(.leading, 16)
                                
                                settingCard(
                                    title: "Spotlight events",
                                    subtitle: "Events to show in spotlight view",
                                    picker: AnyView(
                                        Picker("Spotlight", selection: $spotlightEventsPerPerson) {
                                            ForEach(1...15, id: \.self) { number in
                                                Text("\(number)").tag(number)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                                
                                Divider().padding(.leading, 16)
                                
                                settingCard(
                                    title: "Next event columns",
                                    subtitle: "Number of panels per row",
                                    picker: AnyView(
                                        Picker("Columns", selection: $nextEventColumns) {
                                            Text("2").tag(2)
                                            Text("3").tag(3)
                                            Text("4").tag(4)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 120)
                                    )
                                )
                                
                                Divider().padding(.leading, 16)
                                
                                settingCard(
                                    title: "Default alert",
                                    subtitle: "Alert time for new events",
                                    picker: AnyView(
                                        Picker("Default Alert", selection: defaultAlertBinding) {
                                            ForEach(AlertOption.allCases, id: \.self) { option in
                                                Text(option.rawValue).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                                
                                Divider().padding(.leading, 16)
                                
                                settingCard(
                                    title: "Show past events",
                                    subtitle: "Days to look back",
                                    picker: AnyView(
                                        Picker("Past Days", selection: $eventsPastDays) {
                                            Text("None").tag(0)
                                            Text("1 Month").tag(30)
                                            Text("2 Months").tag(60)
                                            Text("3 Months").tag(90)
                                            Text("6 Months").tag(180)
                                            Text("1 Year").tag(365)
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                                
                                Divider().padding(.leading, 16)
                                
                                settingCard(
                                    title: "Look ahead",
                                    subtitle: "Days to look forward",
                                    picker: AnyView(
                                        Picker("Future Days", selection: $eventsFutureDays) {
                                            Text("1 Month").tag(30)
                                            Text("3 Months").tag(90)
                                            Text("6 Months").tag(180)
                                            Text("1 Year").tag(365)
                                            Text("2 Years").tag(730)
                                        }
                                        .pickerStyle(.menu)
                                        .tint(theme.accentColor)
                                    )
                                )
                            }
                        }

                        // MARK: - Calendar Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                NavigationLink(destination: SharedCalendarsView().environment(\.managedObjectContext, viewContext)) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Shared calendars")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)

                                            Text("Calendars shared with all members")
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(secondaryTextColor.opacity(0.6))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                
                                Divider().padding(.leading, 16)
                                
                                NavigationLink(destination: SavedAddressesSettingsView().environment(\.managedObjectContext, viewContext)) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Saved places")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)

                                            Text("Manage favorite locations")
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(secondaryTextColor.opacity(0.6))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                
                                Divider().padding(.leading, 16)
                                
                                NavigationLink(destination: DriversListView().environment(\.managedObjectContext, viewContext)) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Drivers")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(primaryTextColor)

                                            Text("Manage drivers for events")
                                                .font(.system(size: 13))
                                                .foregroundColor(secondaryTextColor)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(secondaryTextColor.opacity(0.6))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("App Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
        }
    }

    private func settingCard<V: View>(title: String, subtitle: String, picker: V) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

            picker
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
    AppSettingsView()
        .environmentObject(ThemeManager())
}
