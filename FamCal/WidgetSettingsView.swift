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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    private var toggleColor: Color { theme.accentGradient?.colors.first ?? theme.accentColor }

    private var widgetShowEventsBinding: Binding<Int> {
        Binding(
            get: { appSettingsManager.widgetShowEventsCount },
            set: {
                appSettingsManager.widgetShowEventsCount = $0
                Task { await appSettingsManager.saveSettings() }
            }
        )
    }

    private var widgetOwnCalendarsBinding: Binding<Bool> {
        Binding(
            get: { appSettingsManager.widgetShowOwnCalendarsOnly },
            set: {
                appSettingsManager.widgetShowOwnCalendarsOnly = $0
                Task { await appSettingsManager.saveSettings() }
            }
        )
    }

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
                                    Text("Number of Events")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)

                                    Text("How many events to display")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }

                                Spacer()

                                Picker("", selection: widgetShowEventsBinding) {
                                    ForEach(1...10, id: \.self) { count in
                                        Text("\(count)").tag(count)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Own Calendars Only")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryTextColor)

                                    Text("Show only your calendars")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }

                                Spacer()

                                Toggle("", isOn: widgetOwnCalendarsBinding)
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
