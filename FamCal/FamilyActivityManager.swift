//
//  FamilyActivityManager.swift
//  FamCal
//
//  Manages family activity log fetching and real-time subscriptions
//

import Foundation
import Combine

@MainActor
class FamilyActivityManager: ObservableObject {
    static let shared = FamilyActivityManager()

    @Published var recentActivities: [FamilyActivityDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastFetchedAt: Date?

    let supabaseManager: SupabaseManager
    let authManager: SupabaseAuthManager
    private var cancellables = Set<AnyCancellable>()

    init(supabaseManager: SupabaseManager? = nil, authManager: SupabaseAuthManager? = nil) {
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
        self.authManager = authManager ?? SupabaseAuthManager.shared
    }

    // MARK: - Fetch Methods

    /// Fetch recent family activities
    func fetchRecentActivities(
        familyId: String,
        limit: Int = 20
    ) async {
        guard authManager.isAuthenticated, !familyId.isEmpty else {
            errorMessage = "Not authenticated or family ID missing"
            print("❌ Cannot fetch activities: user not authenticated or family ID missing")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("ℹ️ Fetching recent family activities...")
            let activities = try await supabaseManager.getFamilyActivityLog(
                familyId: familyId,
                limit: limit
            )
            self.recentActivities = activities
            self.lastFetchedAt = Date()
            print("✅ Fetched \(activities.count) family activities")
        } catch {
            errorMessage = "Failed to fetch activities: \(error.localizedDescription)"
            print("❌ Error fetching activities: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Fetch activities for a specific type (e.g., "member_added")
    func fetchActivitiesByType(
        familyId: String,
        actionType: String,
        limit: Int = 20
    ) async {
        guard authManager.isAuthenticated, !familyId.isEmpty else {
            errorMessage = "Not authenticated or family ID missing"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("ℹ️ Fetching \(actionType) activities...")
            let activities = try await supabaseManager.getFamilyActivitiesByType(
                familyId: familyId,
                actionType: actionType,
                limit: limit
            )
            self.recentActivities = activities
            self.lastFetchedAt = Date()
            print("✅ Fetched \(activities.count) \(actionType) activities")
        } catch {
            errorMessage = "Failed to fetch activities: \(error.localizedDescription)"
            print("❌ Error fetching activities: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Fetch activities within a date range
    func fetchActivitiesInRange(
        familyId: String,
        startDate: Date,
        endDate: Date
    ) async {
        guard authManager.isAuthenticated, !familyId.isEmpty else {
            errorMessage = "Not authenticated or family ID missing"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("ℹ️ Fetching activities between \(startDate) and \(endDate)...")
            let activities = try await supabaseManager.getFamilyActivityLogInRange(
                familyId: familyId,
                startDate: startDate,
                endDate: endDate
            )
            self.recentActivities = activities
            self.lastFetchedAt = Date()
            print("✅ Fetched \(activities.count) activities in date range")
        } catch {
            errorMessage = "Failed to fetch activities: \(error.localizedDescription)"
            print("❌ Error fetching activities: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Activity Processing

    /// Handle new activity received from Realtime
    func handleNewActivity(_ activity: FamilyActivityDTO) {
        // Add to beginning of list (newest first)
        recentActivities.insert(activity, at: 0)

        // Keep list at reasonable size
        if recentActivities.count > 100 {
            recentActivities.removeLast()
        }

        // Log the activity
        print("🔔 New family activity: \(activity.actionSummary)")

        // Schedule notification if user wants to be notified
        scheduleNotificationIfNeeded(activity)
    }

    /// Schedule notification for activity if user preferences allow
    private func scheduleNotificationIfNeeded(_ activity: FamilyActivityDTO) {
        let notificationManager = NotificationManager.shared

        // Check if user wants to be notified for this type of activity
        guard notificationManager.shouldNotifyForActivity(activity) else {
            print("ℹ️ Skipping notification for \(activity.action_type) (disabled by user)")
            return
        }

        // Schedule the notification
        notificationManager.scheduleFamilyActivityNotification(activity: activity)
    }

    /// Clear all cached activities
    func clearActivities() {
        recentActivities.removeAll()
        lastFetchedAt = nil
        errorMessage = nil
    }

    // MARK: - Grouping & Filtering

    /// Group activities by type
    func activitiesByType() -> [String: [FamilyActivityDTO]] {
        Dictionary(grouping: recentActivities) { $0.action_type }
    }

    /// Group activities by date
    func activitiesByDate() -> [String: [FamilyActivityDTO]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return Dictionary(grouping: recentActivities) { activity in
            guard let date = ISO8601DateFormatter().date(from: activity.created_at) else {
                return "Unknown"
            }
            return formatter.string(from: date)
        }
    }

    /// Filter activities by action type
    func filter(by actionType: String) -> [FamilyActivityDTO] {
        recentActivities.filter { $0.action_type == actionType }
    }

    /// Filter activities after a certain date
    func filterAfter(_ date: Date) -> [FamilyActivityDTO] {
        let dateStr = ISO8601DateFormatter().string(from: date)
        return recentActivities.filter { $0.created_at > dateStr }
    }

    // MARK: - Activity Summaries

    /// Get a summary of recent activity
    var activitySummary: String {
        guard !recentActivities.isEmpty else {
            return "No recent activity"
        }

        let typeGroups = activitiesByType()
        var summaries: [String] = []

        for (type, activities) in typeGroups.sorted(by: { $0.key < $1.key }) {
            summaries.append("\(activities.count) \(type.replacingOccurrences(of: "_", with: " "))")
        }

        return summaries.joined(separator: ", ")
    }

    /// Get count of activities by type
    func countByType(_ actionType: String) -> Int {
        recentActivities.filter { $0.action_type == actionType }.count
    }

    /// Get most recent activity
    var mostRecentActivity: FamilyActivityDTO? {
        recentActivities.first
    }

    /// Get most recent activity of a specific type
    func mostRecentActivity(ofType actionType: String) -> FamilyActivityDTO? {
        recentActivities.first { $0.action_type == actionType }
    }
}
