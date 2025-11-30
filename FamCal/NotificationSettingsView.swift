//
//  NotificationSettingsView.swift
//  FamCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import CoreData

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @State private var showingDebugView = false
    @State private var showingMorningBriefPreview = false

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    private var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { appSettingsManager.notificationsEnabled },
            set: { isOn in
                Task {
                    if isOn {
                        let granted = await notificationManager.requestNotificationPermission()
                        await MainActor.run {
                            appSettingsManager.notificationsEnabled = granted
                            notificationManager.notificationsEnabled = granted
                            notificationManager.saveSettings()
                        }
                        await appSettingsManager.saveSettings()
                        if !granted {
                            print("❌ Notifications permission denied - keeping toggle off")
                        }
                    } else {
                        await MainActor.run {
                            appSettingsManager.notificationsEnabled = false
                            notificationManager.notificationsEnabled = false
                            notificationManager.saveSettings()
                        }
                        await appSettingsManager.saveSettings()
                        notificationManager.cancelMorningBrief()
                    }
                }
            }
        )
    }

    private var morningBriefEnabledBinding: Binding<Bool> {
        Binding(
            get: { appSettingsManager.morningBriefEnabled },
            set: {
                appSettingsManager.morningBriefEnabled = $0
                Task { await appSettingsManager.saveSettings() }
                notificationManager.morningBriefEnabled = $0
                notificationManager.saveSettings()
                notificationManager.scheduleMorningBrief()
            }
        )
    }

    private var morningBriefTimeHourBinding: Binding<Int> {
        Binding(
            get: { appSettingsManager.morningBriefTimeHour },
            set: {
                appSettingsManager.morningBriefTimeHour = $0
                Task { await appSettingsManager.saveSettings() }
                notificationManager.morningBriefTime.hour = $0
                notificationManager.saveSettings()
                notificationManager.scheduleMorningBrief()
            }
        )
    }

    private var morningBriefTimeMinuteBinding: Binding<Int> {
        Binding(
            get: { appSettingsManager.morningBriefTimeMinute },
            set: {
                appSettingsManager.morningBriefTimeMinute = $0
                Task { await appSettingsManager.saveSettings() }
                notificationManager.morningBriefTime.minute = $0
                notificationManager.saveSettings()
                notificationManager.scheduleMorningBrief()
            }
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Notifications Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("General")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                notificationsToggle
                            }
                        }

                        if appSettingsManager.notificationsEnabled {
                            // Morning Brief Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Morning Brief")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(secondaryTextColor)
                                    .padding(.horizontal, 16)

                                settingsContainer {
                                    morningBriefSection
                                }
                            }

                            // Morning Brief Preview
                            if appSettingsManager.morningBriefEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Preview")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(secondaryTextColor)
                                        .padding(.horizontal, 16)

                                    settingsContainer {
                                        Button(action: { showingMorningBriefPreview = true }) {
                                            HStack(spacing: 16) {
                                                Image(systemName: "eye.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(theme.accentColor)
                                                    .frame(width: 24, height: 24)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Preview Events")
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(primaryTextColor)

                                                    Text("See what will be in your morning brief")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(secondaryTextColor)
                                                }

                                                Spacer()

                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                        }
                                    }
                                }
                            }

                            // Debug Section (Testing)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Testing")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(secondaryTextColor)
                                    .padding(.horizontal, 16)

                                settingsContainer {
                                    Button(action: { showingDebugView = true }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "wrench.and.screwdriver")
                                                .font(.system(size: 20))
                                                .foregroundColor(theme.accentColor)
                                                .frame(width: 24, height: 24)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Notification Debug")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(primaryTextColor)

                                                Text("Test notifications and view logs")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(secondaryTextColor)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Notifications")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
            .sheet(isPresented: $showingDebugView) {
                NotificationDebugView()
                    .environmentObject(appSettingsManager)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingMorningBriefPreview) {
                MorningBriefPreviewView()
                    .environmentObject(appSettingsManager)
                    .environmentObject(themeManager)
            }
        }
    }

    private var notificationsToggle: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 20))
                .foregroundColor(theme.accentColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)

                Text("Receive event notifications")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

            Toggle("", isOn: notificationsEnabledBinding)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var morningBriefSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Brief")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)

                    Text("Daily event summary")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                }

                Spacer()

                Toggle("", isOn: morningBriefEnabledBinding)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if appSettingsManager.morningBriefEnabled {
                Divider().padding(.leading, 56)
                morningBriefTimePicker
            }
        }
    }

    private var morningBriefTimePicker: some View {
        VStack(spacing: 16) {
            Text("Notification Time")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Hour")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryTextColor)

                    Picker("Hour", selection: morningBriefTimeHourBinding) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }

                VStack(spacing: 8) {
                    Text("Minute")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryTextColor)

                    Picker("Minute", selection: morningBriefTimeMinuteBinding) {
                        ForEach(Array(stride(from: 0, to: 60, by: 15)), id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
            }
        }
        .padding(16)
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
    NotificationSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
