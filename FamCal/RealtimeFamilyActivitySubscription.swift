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
    private var urlSession: URLSession?
    private var webSocket: URLSessionWebSocketTask?
    private var isSubscribed = false
    private var receiveTask: Task<Void, Never>?
    private var isWebSocketConnected = false

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

        print("ℹ️ Subscribing to family activities for family: \(familyId), user: \(userId)")
        print("🔗 Supabase URL: \(supabaseURL)")

        // Build Realtime WebSocket URL
        let wsURL = supabaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"
        print("🔗 WebSocket URL: \(realtimeURL.prefix(50))...apikey=***")

        guard let url = URL(string: realtimeURL) else {
            print("❌ Failed to create URL from: \(realtimeURL)")
            updateStatus(.error("Invalid WebSocket URL"))
            return
        }

        // Create a URLSession that will persist for the lifetime of this connection
        print("🔧 Creating URLSession with custom configuration...")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true

        // Use a delegate queue to keep the session alive
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        self.urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: delegateQueue)

        var request = URLRequest(url: url)
        // Add necessary headers for Supabase Realtime
        request.setValue("websocket", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")

        print("🚀 Creating WebSocket task...")
        webSocket = self.urlSession?.webSocketTask(with: request)
        print("🚀 Calling webSocket.resume()...")
        webSocket?.resume()

        print("⏳ WebSocket connection initiated (resuming)")
        updateStatus(.syncing)

        // Start receiving messages (this runs indefinitely)
        print("📌 Starting receiveMessages task...")
        receiveTask = Task {
            await receiveMessages(familyId: familyId)
        }

        // Subscribe to the table after connection is verified
        print("📌 Scheduling subscription task with 2 second delay...")
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay for handshake
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

        print("📡 Sending Realtime subscription for family_activity_log (id: 1)...")
        print("📋 Message: \(subscriptionMessage)")
        do {
            try await webSocket.send(.string(subscriptionMessage))
            isSubscribed = true
            print("✅ Successfully sent subscription to family_activity_log table")
            updateStatus(.connected)
        } catch {
            isSubscribed = false
            print("❌ Failed to send subscription: \(error.localizedDescription)")
            print("🔍 Error type: \(type(of: error))")
            updateStatus(.error("Subscription failed: \(error.localizedDescription)"))
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
            urlSession?.invalidateAndCancel()
            urlSession = nil
            updateStatus(.disconnected)
        }
    }

    // MARK: - WebSocket Message Handling

    private func receiveMessages(familyId: String) async {
        guard let webSocket = self.webSocket else {
            print("❌ WebSocket not available when starting receiveMessages")
            updateStatus(.error("WebSocket not available"))
            return
        }

        // Try sending a ping to verify connection is active
        print("⏳ Testing WebSocket connection with initial message...")
        do {
            let testMessage = """
            {
              "type": "ping"
            }
            """
            try await webSocket.send(.string(testMessage))
            print("✅ WebSocket connection is active (ping sent)")
        } catch {
            print("❌ WebSocket connection failed on test message: \(error.localizedDescription)")
            updateStatus(.error("WebSocket connection failed: \(error.localizedDescription)"))
            return
        }

        print("✅ Starting message receive loop")
        self.isWebSocketConnected = true
        updateStatus(.syncing)

        while !Task.isCancelled {
            do {
                print("👂 Listening for WebSocket messages...")
                let message = try await webSocket.receive()

                switch message {
                case .string(let text):
                    print("📨 Received string message: \(text.prefix(100))...")
                    await handleMessage(text, familyId: familyId)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📨 Received data message: \(text.prefix(100))...")
                        await handleMessage(text, familyId: familyId)
                    }
                @unknown default:
                    print("⚠️ Unknown WebSocket message type")
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ WebSocket receive error: \(error.localizedDescription)")
                    print("🔍 Error type: \(type(of: error))")
                    self.isWebSocketConnected = false
                    updateStatus(.error("Connection lost: \(error.localizedDescription)"))

                    // Wait before retrying
                    print("⏳ Waiting 5 seconds before reconnect attempt...")
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second retry delay
                } else {
                    print("ℹ️ WebSocket receive task cancelled")
                    break
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
