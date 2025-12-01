//
//  RealtimeFamilyActivitySubscription.swift
//  FamCal
//
//  Manages Supabase Realtime subscriptions for family activity changes
//

import Foundation
import Combine

class RealtimeFamilyActivitySubscription: ObservableObject {
    @Published var syncStatus: RealtimeSyncStatus = .disconnected
    @Published var lastUpdateAt: Date?

    var onActivityCreated: ((FamilyActivityDTO) -> Void)?
    var onSyncStatusChanged: ((RealtimeSyncStatus) -> Void)?

    private let supabaseURL: String
    private let anonKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var isSubscribed = false
    private var receiveTask: Task<Void, Never>?

    enum RealtimeSyncStatus: Equatable {
        case connected
        case disconnected
        case syncing
        case error(String)

        var description: String {
            switch self {
            case .connected:
                return "Connected"
            case .disconnected:
                return "Disconnected"
            case .syncing:
                return "Syncing"
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }

    init() {
        self.supabaseURL = SupabaseConfig.supabaseURL
        self.anonKey = SupabaseConfig.supabaseAnonKey
    }

    // MARK: - Subscription Management

    /// Subscribe to family activity changes via Realtime
    func subscribeToFamilyActivities(
        familyId: String,
        userId: String
    ) async {
        guard !familyId.isEmpty, !userId.isEmpty else {
            print("❌ Cannot subscribe: missing familyId or userId")
            return
        }

        // Disconnect existing connection
        await disconnect()

        print("ℹ️ Subscribing to family activities for family: \(familyId)")

        // Build Realtime WebSocket URL
        let wsURL = supabaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"

        guard let url = URL(string: realtimeURL) else {
            updateStatus(.error("Invalid WebSocket URL"))
            return
        }

        let request = URLRequest(url: url)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()

        print("✅ WebSocket connection initiated")
        updateStatus(.connected)

        // Start receiving messages
        receiveTask = Task {
            await receiveMessages(familyId: familyId)

            // After a brief delay to ensure connection is established, subscribe to the table
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            await subscribeToTable(familyId: familyId)
        }
    }

    /// Subscribe to family_activity_log table changes
    private func subscribeToTable(familyId: String) async {
        guard let webSocket = self.webSocket else {
            print("⚠️ WebSocket not available for subscription")
            return
        }

        // Build subscription message according to Supabase Realtime protocol
        let subscriptionMessage = """
        {
          "type": "subscribe",
          "id": 1,
          "payload": {
            "schema": "public",
            "table": "family_activity_log",
            "configs": {
              "scope": "postgres_changes"
            }
          }
        }
        """

        print("📡 Sending Realtime subscription for family_activity_log...")
        do {
            try await webSocket.send(.string(subscriptionMessage))
            print("✅ Subscribed to family_activity_log table")
        } catch {
            print("⚠️ Failed to send subscription: \(error.localizedDescription)")
        }
    }

    /// Disconnect from Realtime
    func disconnect() async {
        print("ℹ️ Disconnecting from Realtime...")
        isSubscribed = false
        receiveTask?.cancel()
        receiveTask = nil

        await MainActor.run {
            webSocket?.cancel(with: .goingAway, reason: nil)
            webSocket = nil
            updateStatus(.disconnected)
        }
    }

    // MARK: - WebSocket Message Handling

    private func receiveMessages(familyId: String) async {
        guard let webSocket = self.webSocket else {
            updateStatus(.error("WebSocket not available"))
            return
        }

        while !Task.isCancelled {
            do {
                let message = try await webSocket.receive()

                switch message {
                case .string(let text):
                    await handleMessage(text, familyId: familyId)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessage(text, familyId: familyId)
                    }
                @unknown default:
                    print("⚠️ Unknown WebSocket message type")
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ WebSocket error: \(error.localizedDescription)")
                    updateStatus(.error(error.localizedDescription))
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second retry delay
                }
            }
        }
    }

    private func handleMessage(_ message: String, familyId: String) async {
        guard let data = message.data(using: .utf8) else {
            print("⚠️ Failed to convert message to data")
            return
        }

        // Try to decode as Realtime message
        if let realtimeMessage = try? JSONDecoder().decode(RealtimeMessage.self, from: data) {
            await processRealtimeMessage(realtimeMessage, familyId: familyId)
        }
    }

    private func processRealtimeMessage(
        _ message: RealtimeMessage,
        familyId: String
    ) async {
        // Check if this is an activity change
        guard message.event == "postgres_changes" else {
            print("ℹ️ Ignoring non-postgres event: \(message.event)")
            return
        }

        // Parse the data payload
        guard let data = message.data else {
            print("⚠️ No data in Realtime message")
            return
        }

        if let eventType = data.type {
            print("ℹ️ Realtime event: \(eventType)")

            if eventType == "INSERT" {
                // New activity created - convert changes to activity
                if let changes = data.changes, !changes.isEmpty {
                    // Get the first (and typically only) change record
                    if let newRecord = changes.first {
                        // Convert AnyCodable dict to [String: Any] for decoding
                        await handleNewActivityFromChanges(newRecord)
                    }
                }
            }
        }
    }

    private func handleNewActivityFromChanges(_ changeRecord: [String: AnyCodable]) async {
        // Convert AnyCodable dictionary to standard Dictionary for JSON encoding
        var recordDict: [String: Any] = [:]
        for (key, value) in changeRecord {
            recordDict[key] = anyCodableToAny(value)
        }

        do {
            // Convert record to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: recordDict)
            let activity = try JSONDecoder().decode(FamilyActivityDTO.self, from: jsonData)

            print("🔔 New family activity: \(activity.actionSummary)")

            await MainActor.run {
                self.lastUpdateAt = Date()
                self.onActivityCreated?(activity)
            }
        } catch {
            print("⚠️ Failed to decode activity from Realtime: \(error.localizedDescription)")
        }
    }

    private func anyCodableToAny(_ value: AnyCodable) -> Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let bool):
            return bool
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .string(let string):
            return string
        case .array(let array):
            return array.map { anyCodableToAny($0) }
        case .dict(let dict):
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = anyCodableToAny(val)
            }
            return result
        }
    }

    private func handleNewActivity(_ record: [String: Any]) async {
        do {
            // Convert record to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: record)
            let activity = try JSONDecoder().decode(FamilyActivityDTO.self, from: jsonData)

            print("🔔 New family activity: \(activity.actionSummary)")

            await MainActor.run {
                self.lastUpdateAt = Date()
                self.onActivityCreated?(activity)
            }
        } catch {
            print("⚠️ Failed to decode activity from Realtime: \(error.localizedDescription)")
        }
    }

    // MARK: - Status Management

    private func updateStatus(_ status: RealtimeSyncStatus) {
        DispatchQueue.main.async {
            self.syncStatus = status
            self.onSyncStatusChanged?(status)
            print("📊 Realtime sync status: \(status.description)")
        }
    }
}

// MARK: - Realtime Message Models

struct RealtimeMessage: Codable {
    let event: String
    let data: RealtimeData?

    struct RealtimeData: Codable {
        let type: String?
        let schema: String?
        let table: String?
        let commit_timestamp: String?
        let changes: [[String: AnyCodable]]?
    }

    enum CodingKeys: String, CodingKey {
        case event
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        event = try container.decode(String.self, forKey: .event)
        data = try container.decodeIfPresent(RealtimeData.self, forKey: .data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encodeIfPresent(data, forKey: .data)
    }
}

extension RealtimeMessage.RealtimeData {
    enum CodingKeys: String, CodingKey {
        case type
        case schema
        case table
        case commit_timestamp
        case changes
    }
}
