//
//  FamilyActivityFeedView.swift
//  FamCal
//
//  Displays recent family activities in a feed format
//

import SwiftUI

struct FamilyActivityFeedView: View {
    @StateObject private var activityManager = FamilyActivityManager()
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @State private var selectedFilter: ActivityFilter = .all
    @State private var isRefreshing = false

    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case members = "Members"
        case drivers = "Drivers"
        case locations = "Locations"
        case calendars = "Calendars"

        var actionTypes: [String] {
            switch self {
            case .all:
                return []
            case .members:
                return ["member_added", "member_edited", "member_deleted", "member_linked"]
            case .drivers:
                return ["driver_created", "driver_updated", "driver_deleted"]
            case .locations:
                return ["address_added", "address_updated", "address_deleted"]
            case .calendars:
                return ["calendar_shared", "calendar_removed"]
            }
        }
    }

    var filteredActivities: [FamilyActivityDTO] {
        if selectedFilter == .all {
            return activityManager.recentActivities
        }
        return activityManager.recentActivities.filter { activity in
            selectedFilter.actionTypes.contains(activity.action_type)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ActivityFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                .border(Color(.separator), width: 1)

                // Activity List
                if activityManager.isLoading && activityManager.recentActivities.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading family activity...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else if filteredActivities.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No activity yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        if !appSettingsManager.familyActivityNotificationsEnabled {
                            Text("Family activity notifications are disabled")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(filteredActivities) { activity in
                            FamilyActivityRow(activity: activity)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshActivities()
                    }
                }
            }
            .navigationTitle("Family Activity")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await activityManager.fetchRecentActivities(
                        familyId: appSettingsManager.familyId ?? ""
                    )
                }
            }
        }
    }

    private func refreshActivities() async {
        isRefreshing = true
        await activityManager.fetchRecentActivities(
            familyId: appSettingsManager.familyId ?? ""
        )
        isRefreshing = false
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Color.blue
                        : Color(.systemGray6)
                )
                .cornerRadius(8)
        }
    }
}

// MARK: - Activity Row

struct FamilyActivityRow: View {
    let activity: FamilyActivityDTO
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: activity.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(activity.tintColor))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color(activity.tintColor).opacity(0.1)))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.actionSummary)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Timestamp
                    Text(formattedTime(activity.created_at))
                        .font(.caption)
                        .foregroundColor(.gray)

                    // Changed fields (if applicable)
                    if let changedFields = activity.action_details?["changedFields"],
                       case .array(let fields) = changedFields,
                       !fields.isEmpty {
                        Text("•")
                            .foregroundColor(.gray)
                        Text("Updated")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .opacity(0.5)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }

    private func formattedTime(_ isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return "Just now"
        }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview {
    FamilyActivityFeedView()
        .environmentObject(SupabaseDataManager())
        .environmentObject(AppSettingsManager())
}
