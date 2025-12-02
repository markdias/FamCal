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
    private var currentAccessToken: String?
    private var pingTask: Task<Void, Never>?
    private var isWebSocketReadyForSubscription = false

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
        userId: String,
        accessToken: String? = nil
    ) async {
        guard !familyId.isEmpty, !userId.isEmpty else {
            print("❌ Cannot subscribe: missing familyId or userId")
            return
        }

        // Disconnect existing connection
        await disconnect()

        // Store the access token for RLS authorization
        self.currentAccessToken = accessToken

        print("ℹ️ Subscribing to family activities for family: \(familyId), user: \(userId)")
        print("🔗 Supabase URL: \(supabaseURL)")

        // Validate authentication
        if let token = accessToken {
            let tokenPreview = token.count > 20 ? "\(token.prefix(20))..." : token
            print("🔐 Access token present (\(token.count) chars): \(tokenPreview)")
        } else {
            print("⚠️ WARNING: No access token provided - RLS policies may deny access")
            print("⚠️ Ensure authManager.accessToken is not nil before subscribing")
        }

        // Build Realtime WebSocket URL with authentication
        let wsURL = supabaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        // IMPORTANT: For authenticated Realtime channels with RLS, MUST include JWT in URL
        // Not just the anonymous key. The JWT token provides the auth context for RLS policies.
        // See: https://supabase.com/docs/guides/realtime/extensions/auth

        var realtimeURL: String
        if let token = accessToken, !token.isEmpty {
            // Use authenticated connection with JWT token
            realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)&access_token=\(token)"
            print("🔐 Using authenticated Realtime connection with JWT token in URL")
            let tokenPreview = token.count > 20 ? "\(token.prefix(20))..." : token
            print("🔐 JWT token: \(tokenPreview) (\(token.count) chars)")
        } else {
            // Fallback to anonymous if no token (will fail RLS checks)
            realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"
            print("⚠️ WARNING: Using anonymous key only - RLS policies will deny access")
            print("⚠️ For authenticated channels, access_token MUST be in URL")
        }

        print("🔗 WebSocket URL: \(realtimeURL.prefix(60))...")

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

        // Test: Try a simple receive immediately to see what happens
        print("🧪 DIAGNOSTIC TEST: Attempting immediate receive to check WebSocket state...")
        Task {
            guard let ws = self.webSocket else {
                print("❌ WebSocket is nil!")
                return
            }

            print("⏱️ Attempting to receive message (with 5 second timeout)...")
            do {
                // Try to receive one message with short timeout
                let receiveTask = Task {
                    try await ws.receive()
                }

                let result = await withTimeoutSeconds(5) {
                    try await receiveTask.value
                }

                if let message = result {
                    print("✅ SUCCESS! Received message on first try!")
                    print("📨 Message: \(message)")
                } else {
                    print("❌ TIMEOUT: WebSocket did not send any message within 5 seconds")
                    print("⚠️ This means:")
                    print("   - Supabase Realtime might not be enabled (check Settings → Infrastructure)")
                    print("   - Or the table is not in the Realtime publication")
                    print("   - Or there's a network connectivity issue")
                }
            } catch {
                print("❌ ERROR: \(error.localizedDescription)")
            }
        }

        // Start receiving messages immediately to keep the WebSocket alive
        // This MUST happen before subscription or the connection won't stay open
        print("📌 Starting receiveMessages task (must run before subscription)...")
        self.receiveTask = Task {
            await self.receiveMessages(familyId: familyId)
        }

        // Subscribe to the table after initial receive is running
        // This gives the WebSocket time to handshake and be ready
        print("📌 Waiting 3 seconds for WebSocket handshake before subscribing...")
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second handshake delay
            print("✅ Calling subscribeToTable...")
            await subscribeToTable(familyId: familyId)
        }
    }

    /// Subscribe to family_activity_log table changes
    private func subscribeToTable(familyId: String) async {
        guard let webSocket = self.webSocket else {
            print("⚠️ WebSocket not available for subscription")
            return
        }

        print("🔄 Preparing subscription message...")

        // Wait until WebSocket is actually ready (received initial message)
        var waitCount = 0
        while !self.isWebSocketReadyForSubscription && waitCount < 20 {
            print("⏳ Waiting for WebSocket to be ready... (attempt \(waitCount + 1)/20)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            waitCount += 1
        }

        if !self.isWebSocketReadyForSubscription {
            print("❌ WebSocket did not become ready for subscription")
            updateStatus(.error("WebSocket failed to establish - see logs for details"))
            return
        }

        print("✅ WebSocket is ready! Sending subscription...")

        // Build subscription message according to Supabase Realtime protocol v1
        // JWT token is now in URL, but also include in payload for compatibility
        var payload: [String: Any] = [
            "schema": "public",
            "table": "family_activity_log",
            "configs": [
                "scope": "postgres_changes",
                "filter": "family_id=eq.\(familyId)"
            ]
        ]

        // Add access token to payload for RLS authorization (already in URL for connection auth)
        if let token = currentAccessToken {
            payload["access_token"] = token
            let tokenPreview = token.count > 20 ? "\(token.prefix(20))..." : token
            print("✅ Including access token in subscription payload (\(token.count) chars): \(tokenPreview)")
            print("✅ Token also present in WebSocket URL for authenticated connection")
        } else {
            print("⚠️ WARNING: No access token in subscription message")
            print("⚠️ This will cause RLS policy denials - auth.uid() will be NULL")
        }

        let subscriptionPayload: [String: Any] = [
            "type": "subscribe",
            "id": "1",
            "payload": payload
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: subscriptionPayload),
              let subscriptionMessage = String(data: jsonData, encoding: .utf8) else {
            print("❌ Failed to encode subscription message")
            updateStatus(.error("Failed to encode subscription"))
            return
        }

        print("📡 Sending Realtime subscription for family_activity_log...")
        print("📋 Subscription message: \(subscriptionMessage)")
        do {
            try await webSocket.send(.string(subscriptionMessage))
            isSubscribed = true
            print("✅ Successfully sent subscription to family_activity_log table")
            print("👂 Waiting for subscription confirmation from server...")

            // Wait a moment for the server to process the subscription
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay

            updateStatus(.connected)

            // Start sending periodic keep-alive pings to maintain connection
            print("💓 Starting keep-alive ping loop...")
            startPingLoop()
        } catch {
            isSubscribed = false
            print("❌ Failed to send subscription: \(error.localizedDescription)")
            print("🔍 Error type: \(type(of: error))")
            print("🔍 NSError details: \((error as NSError).userInfo)")
            updateStatus(.error("Subscription failed: \(error.localizedDescription)"))
        }
    }

    /// Disconnect from Realtime
    func disconnect() async {
        print("ℹ️ Disconnecting from Realtime...")
        isSubscribed = false
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil

        await MainActor.run {
            webSocket?.cancel(with: .goingAway, reason: nil)
            webSocket = nil
            urlSession?.invalidateAndCancel()
            urlSession = nil
            updateStatus(.disconnected)
        }
    }

    /// Send periodic ping messages to keep the WebSocket alive
    private func startPingLoop() {
        pingTask = Task {
            while !Task.isCancelled {
                // Wait 25 seconds before sending ping (keep-alive interval)
                try? await Task.sleep(nanoseconds: 25_000_000_000)

                guard !Task.isCancelled, let webSocket = self.webSocket else { return }

                // Send a ping message to keep connection alive
                let pingMessage = """
                {
                  "type": "ping"
                }
                """

                do {
                    try await webSocket.send(.string(pingMessage))
                    print("💓 Sent keep-alive ping to Realtime server")
                } catch {
                    print("⚠️ Failed to send keep-alive ping: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helper Functions

    /// Execute an async operation with a timeout
    private func withTimeoutSeconds<T>(_ seconds: Int, operation: @escaping () async throws -> T) async -> T? {
        try? await withThrowingTaskGroup(of: T.self) { group in
            // Start the actual operation
            group.addTask {
                try await operation()
            }

            // Start a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw URLError(.timedOut)
            }

            // Return first result (either success or timeout)
            for try await result in group {
                return result
            }
            return nil
        }
    }

    // MARK: - WebSocket Message Handling

    private func receiveMessages(familyId: String) async {
        guard let webSocket = self.webSocket else {
            print("❌ WebSocket not available when starting receiveMessages")
            updateStatus(.error("WebSocket not available"))
            return
        }

        print("✅ Starting message receive loop")
        print("📌 WebSocket state: checking if connection is open...")

        var messageCount = 0
        var isFirstConnection = true
        var consecutiveErrors = 0
        let maxInitialRetries = 10 // Give up after 10 attempts on initial connection
        var totalAttempts = 0

        while !Task.isCancelled {
            do {
                totalAttempts += 1
                print("👂 Listening for WebSocket messages... (count: \(messageCount), attempt: \(totalAttempts))")
                print("   ⏱️ About to call webSocket.receive() with timeout...")

                // Add timeout to detect hanging connections
                // Use longer timeout for WebSocket long-polling (60 seconds normal, 15 seconds for initial connection)
                let timeoutSeconds = messageCount == 0 ? 15 : 60

                let receiveTask = Task {
                    try await webSocket.receive()
                }

                // Wait with timeout per receive attempt
                let result = await withTimeoutSeconds(timeoutSeconds) {
                    try await receiveTask.value
                }

                guard let message = result else {
                    print("❌ webSocket.receive() timed out after \(timeoutSeconds) seconds")
                    throw URLError(.timedOut)
                }

                print("   ✅ webSocket.receive() returned successfully")
                messageCount += 1
                consecutiveErrors = 0 // Reset error count on successful receive
                isFirstConnection = false

                switch message {
                case .string(let text):
                    print("📨 [\(messageCount)] Received string message (\(text.count) chars)")
                    print("   Content: \(text.prefix(200))...")
                    // Mark that WebSocket is ready for subscription after first message
                    if messageCount == 1 {
                        self.isWebSocketReadyForSubscription = true
                        print("✅ WebSocket is ready for subscription (received initial message)")
                    }
                    await handleMessage(text, familyId: familyId)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📨 [\(messageCount)] Received data message (\(text.count) chars)")
                        print("   Content: \(text.prefix(200))...")
                        await handleMessage(text, familyId: familyId)
                    }
                @unknown default:
                    print("⚠️ [\(messageCount)] Unknown WebSocket message type")
                }
            } catch {
                if !Task.isCancelled {
                    let errorStr = error.localizedDescription
                    print("❌ WebSocket receive error after \(messageCount) messages: \(errorStr)")
                    print("🔍 Error type: \(type(of: error))")

                    // Check if it's a "not connected" error - these are expected during initial connection
                    if errorStr.contains("Socket is not connected") && isFirstConnection {
                        consecutiveErrors += 1

                        if consecutiveErrors > maxInitialRetries {
                            // Too many retries - likely a configuration issue
                            print("❌ ⚠️ CRITICAL: WebSocket failed to connect after \(maxInitialRetries) attempts")
                            print("⚠️ Network error - 'Socket is not connected'")
                            print("⚠️ This could mean:")
                            print("   1. Firewall or VPN blocking WebSocket connections")
                            print("   2. Network connectivity issue (try different WiFi)")
                            print("   3. DNS resolution problem")
                            print("   4. Supabase service temporarily down")
                            print("   5. Invalid Supabase URL or credentials")
                            print("⚠️ Try:")
                            print("   - Switch to different network")
                            print("   - Disable VPN if using one")
                            print("   - Run diagnostics again")
                            print("   - Check https://status.supabase.com")
                            updateStatus(.error("Network error - WebSocket connection failed"))
                            isFirstConnection = false // Stop retrying
                            break
                        }

                        // Quick retry (2, 3, 4, 5 seconds) - not exponential, keep it simple
                        let retryDelay = min(consecutiveErrors + 1, 5)
                        print("⏳ Socket not yet connected (attempt \(consecutiveErrors)/\(maxInitialRetries), network connecting...)")
                        print("⏳ Retrying in \(retryDelay) seconds...")
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay) * 1_000_000_000)
                    } else {
                        print("🔍 NSError details: \((error as NSError).userInfo)")
                        self.isWebSocketConnected = false
                        if messageCount == 0 {
                            updateStatus(.error("Failed to connect: \(errorStr)"))
                        } else {
                            updateStatus(.error("Connection lost: \(errorStr)"))
                        }

                        // Wait before retrying
                        print("⏳ Waiting 5 seconds before reconnect attempt...")
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second retry delay
                        consecutiveErrors = 0
                        isFirstConnection = true // Reset for potential reconnection
                    }
                } else {
                    print("ℹ️ WebSocket receive task cancelled after \(messageCount) messages")
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
        do {
            if let realtimeMessage = try? JSONDecoder().decode(RealtimeMessage.self, from: data) {
                print("✅ Successfully decoded Realtime message with event: \(realtimeMessage.event)")
                await processRealtimeMessage(realtimeMessage, familyId: familyId)
            } else {
                // Try to parse as generic JSON to see what structure we got
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📊 Received unknown message structure: \(json.keys)")
                    if let msgType = json["type"] as? String {
                        print("   Message type: \(msgType)")
                    }
                }
            }
        } catch {
            print("⚠️ Failed to decode message: \(error.localizedDescription)")
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
