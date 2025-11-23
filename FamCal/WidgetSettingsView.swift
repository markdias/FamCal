//
//  WidgetSettingsView.swift
//  FamCal
//
//  Created by Claude Code
//

import SwiftUI

struct WidgetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("widgetShowTime", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showTime: Bool = true
    @AppStorage("widgetShowLocation", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showLocation: Bool = true
    @AppStorage("widgetShowAttendees", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showAttendees: Bool = true
    @AppStorage("widgetShowDrivers", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showDrivers: Bool = true
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    private var toggleColor: Color { theme.accentGradient?.colors.first ?? theme.accentColor }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Family Events Widget Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family Events Widget")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 16)

                        settingsContainer {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Event Time")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)

                                    Text("Show event start time")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }

                                Spacer()

                                Toggle("", isOn: $showTime)
                                    .tint(toggleColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)

                                    Text("Show event location")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }

                                Spacer()

                                Toggle("", isOn: $showLocation)
                                    .tint(toggleColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Attendees")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)

                                    Text("Show family members attending")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }

                                Spacer()

                                Toggle("", isOn: $showAttendees)
                                    .tint(toggleColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Drivers")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)

                                    Text("Show assigned drivers")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }

                                Spacer()

                                Toggle("", isOn: $showDrivers)
                                    .tint(toggleColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
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
                Text("Widget Settings")
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
}

private extension WidgetSettingsView {
    func settingsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
    WidgetSettingsView()
        .environmentObject(ThemeManager())
}
