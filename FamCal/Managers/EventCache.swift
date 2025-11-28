//
//  EventCache.swift
//  FamCal
//
//  Created by Mark Dias on 28/11/2025.
//

import Foundation

/// Thread-safe cache for storing member event groups between app launches
/// Allows showing cached events immediately while fresh data loads in background
actor EventCache {
    static let shared = EventCache()

    private let defaults = UserDefaults.standard
    private let cacheKey = "famcal_member_events_cache"
    private let cacheTimestampKey = "famcal_events_cache_timestamp"

    /// Store event groups in cache
    func save(_ memberEventGroups: [MemberEventGroupDTO]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(memberEventGroups)
            defaults.set(data, forKey: cacheKey)
            defaults.set(Date(), forKey: cacheTimestampKey)
            print("✅ Cached \(memberEventGroups.count) member event groups")
        } catch {
            print("❌ Failed to cache events: \(error.localizedDescription)")
        }
    }

    /// Retrieve cached event groups
    func load() -> [MemberEventGroupDTO]? {
        guard let data = defaults.data(forKey: cacheKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let groups = try decoder.decode([MemberEventGroupDTO].self, from: data)
            if let timestamp = defaults.object(forKey: cacheTimestampKey) as? Date {
                let secondsAgo = Date().timeIntervalSince(timestamp)
                print("📦 Loaded cached events from \(Int(secondsAgo)) seconds ago")
            }
            return groups
        } catch {
            print("⚠️ Failed to decode cached events: \(error.localizedDescription)")
            // Corrupted cache, clear it
            defaults.removeObject(forKey: cacheKey)
            defaults.removeObject(forKey: cacheTimestampKey)
            return nil
        }
    }

    /// Clear the cache
    func clear() {
        defaults.removeObject(forKey: cacheKey)
        defaults.removeObject(forKey: cacheTimestampKey)
        print("🗑️ Cleared event cache")
    }
}

/// Codable DTO versions of event models for caching
struct MemberEventGroupDTO: Codable {
    let memberName: String
    let sortOrder: Int16
    let memberColorHex: String
    let nextEvent: GroupedEventDTO?
    let upcomingEvents: [GroupedEventDTO]
}

struct GroupedEventDTO: Codable {
    let id: String
    let eventIdentifier: String
    let title: String
    let timeRange: String?
    let location: String?
    let startDate: Date
    let endDate: Date
    let memberNames: [String]
    let memberColorHex: String
    let calendarColorHex: String
    let calendarTitle: String
    let calendarID: String
    let memberColorsHex: [String]
    let hasRecurrence: Bool
    let isAllDay: Bool
    let driverName: String?
    let isImportant: Bool
}
