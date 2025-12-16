//
//  MorningBriefPreviewView.swift
//  FamCal
//
//  Shows a preview of events that will be included in the morning brief
//

import SwiftUI
import CoreData
import EventKit

struct MorningBriefPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @State private var briefEvents: [MorningBriefEvent] = []
    @State private var isLoading = false

    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Time Section
                        timeSection

                        // Events Section
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(theme.accentColor)
                                Text("Loading events...")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if briefEvents.isEmpty {
                            emptyStateView
                        } else {
                            eventsSection
                        }

                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Morning Brief Preview")
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
                    Button(action: { refreshEvents() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                    }
                    .disabled(isLoading)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { refreshEvents() }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled Time")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentColor)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily at")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)

                        Text(String(format: "%02d:%02d", appSettingsManager.morningBriefTimeHour, appSettingsManager.morningBriefTimeMinute))
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.accentColor)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
            .padding(.horizontal, 16)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Events Today")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("You don't have any events scheduled for today. Your morning brief will be empty.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Events (\(briefEvents.count))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(Array(briefEvents.enumerated()), id: \.element.title) { index, event in
                    eventCard(event, index: index + 1)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func eventCard(_ event: MorningBriefEvent, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Number badge
                Text("\(index)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.accentColor))

                // Event title with recurrence icon
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                // Person indicator
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Attendees
            if !event.attendees.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(event.attendees.joined(separator: ", "))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Time
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(event.isAllDay ? "All day" : event.startTimeString)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Location
            if let location = event.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Driver
            if let driver = event.driver, !driver.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("Driver: \(driver)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func refreshEvents() {
        isLoading = true
        Task { @MainActor in
            let notificationManager = NotificationManager.shared
            let events = notificationManager.fetchMorningBriefEvents()
            briefEvents = events
            isLoading = false
            print("✅ Morning brief preview loaded: \(events.count) events")
        }
    }
}

#Preview {
    MorningBriefPreviewView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppSettingsManager.shared)
        .environmentObject(ThemeManager())
}
