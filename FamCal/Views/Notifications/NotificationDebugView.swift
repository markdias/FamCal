//
//  NotificationDebugView.swift
//  FamCal
//
//  Debugging and testing view for notifications
//

import SwiftUI
import UserNotifications

struct NotificationDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var deliveredNotifications: [UNNotification] = []
    @State private var refreshing = false
    @State private var testNotificationSent = false

    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status Section
                        statusSection

                        // Quick Actions Section
                        quickActionsSection

                        // Pending Notifications Section
                        pendingNotificationsSection

                        // Delivered Notifications Section
                        deliveredNotificationsSection

                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Notification Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { refreshData() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                    }
                    .disabled(refreshing)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { refreshData() }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                statusRow(
                    label: "Notifications Enabled",
                    value: appSettingsManager.notificationsEnabled ? "✅ Yes" : "❌ No",
                    valueColor: appSettingsManager.notificationsEnabled ? .green : .red
                )

                Divider().padding(.leading, 56)

                statusRow(
                    label: "Morning Brief Enabled",
                    value: appSettingsManager.morningBriefEnabled ? "✅ Yes" : "❌ No",
                    valueColor: appSettingsManager.morningBriefEnabled ? .green : .red
                )

                Divider().padding(.leading, 56)

                statusRow(
                    label: "Morning Brief Time",
                    value: String(format: "%02d:%02d", appSettingsManager.morningBriefTimeHour, appSettingsManager.morningBriefTimeMinute),
                    valueColor: .blue
                )

                Divider().padding(.leading, 56)

                statusRow(
                    label: "Pending Notifications",
                    value: "\(pendingNotifications.count)",
                    valueColor: .orange
                )

                Divider().padding(.leading, 56)

                statusRow(
                    label: "Delivered Notifications",
                    value: "\(deliveredNotifications.count)",
                    valueColor: .purple
                )
            }
            .background(theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
            .padding(.horizontal, 16)
        }
    }

    private func statusRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(theme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                Button(action: { scheduleMorningBriefTest() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(theme.accentColor)
                        Text("Schedule Morning Brief Now")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .foregroundColor(theme.textPrimary)

                Divider().padding(.leading, 56)

                Button(action: { sendTestNotification() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(theme.accentColor)
                        Text("Send Test Notification")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        if testNotificationSent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .foregroundColor(theme.textPrimary)

                Divider().padding(.leading, 56)

                Button(action: { clearAllNotifications() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                        Text("Clear All Notifications")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .foregroundColor(.red)
            }
            .background(theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
            .padding(.horizontal, 16)
        }
    }

    private var pendingNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Pending Notifications (\(pendingNotifications.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)

                Spacer()

                if pendingNotifications.isEmpty {
                    Text("None")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 16)

            if !pendingNotifications.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(pendingNotifications.enumerated()), id: \.element.identifier) { index, notification in
                        notificationCard(notification)

                        if index < pendingNotifications.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(theme.cardBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                .padding(.horizontal, 16)
            } else {
                Text("No pending notifications scheduled")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var deliveredNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Delivered Notifications (\(deliveredNotifications.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)

                Spacer()

                if deliveredNotifications.isEmpty {
                    Text("None")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 16)

            if !deliveredNotifications.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(deliveredNotifications.enumerated()), id: \.element.request.identifier) { index, notification in
                        deliveredNotificationCard(notification)

                        if index < deliveredNotifications.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(theme.cardBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                .padding(.horizontal, 16)
            } else {
                Text("No delivered notifications")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func notificationCard(_ notification: UNNotificationRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notification.content.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)

            if !notification.content.body.isEmpty {
                Text(notification.content.body)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ID")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(notification.identifier)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let calendarTrigger = notification.trigger as? UNCalendarNotificationTrigger {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Trigger")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        if let nextTriggerDate = calendarTrigger.nextTriggerDate() {
                            Text(nextTriggerDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.blue)
                        } else {
                            Text("Invalid")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(12)
    }

    private func deliveredNotificationCard(_ notification: UNNotification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notification.request.content.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)

            if !notification.request.content.body.isEmpty {
                Text(notification.request.content.body)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delivered")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(notification.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.purple)
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(12)
    }

    private func refreshData() {
        refreshing = true
        Task {
            let pending = await notificationManager.getPendingNotifications()
            let delivered = await notificationManager.getDeliveredNotifications()

            await MainActor.run {
                // Sort pending notifications by trigger date
                pendingNotifications = pending.sorted { req1, req2 in
                    guard let trigger1 = req1.trigger as? UNCalendarNotificationTrigger,
                          let trigger2 = req2.trigger as? UNCalendarNotificationTrigger,
                          let date1 = trigger1.nextTriggerDate(),
                          let date2 = trigger2.nextTriggerDate() else {
                        return false
                    }
                    return date1 < date2
                }

                // Sort delivered notifications by date (most recent first)
                deliveredNotifications = delivered.sorted { $0.date > $1.date }

                refreshing = false
                print("✅ Notification debug data refreshed: \(pending.count) pending, \(delivered.count) delivered")
            }
        }
    }

    private func scheduleMorningBriefTest() {
        print("🧪 Testing: Scheduling morning brief now...")
        NotificationManager.shared.ensureMorningBriefScheduled()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshData()
        }
    }

    private func sendTestNotification() {
        print("🧪 Testing: Sending test notification...")
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from FamCal. If you see this, notifications are working!"
        content.sound = .default

        // Schedule for 3 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send test notification: \(error)")
            } else {
                print("✅ Test notification scheduled for 3 seconds from now")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshData()
                testNotificationSent = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    testNotificationSent = false
                }
            }
        }
    }

    private func clearAllNotifications() {
        print("🧹 Clearing all notifications...")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        refreshData()
    }
}

#Preview {
    NotificationDebugView()
        .environmentObject(AppSettingsManager.shared)
        .environmentObject(ThemeManager())
}
