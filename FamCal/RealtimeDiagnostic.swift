//
//  RealtimeDiagnostic.swift
//  FamCal
//
//  Diagnostic utility to test Supabase Realtime connectivity and configuration
//

import Foundation

class RealtimeDiagnostic {
    private let supabaseURL: String
    private let anonKey: String

    init() {
        self.supabaseURL = SupabaseConfig.supabaseURL
        self.anonKey = SupabaseConfig.supabaseAnonKey
    }

    /// Run all diagnostics and return a comprehensive report
    func runDiagnostics() async -> DiagnosticReport {
        var report = DiagnosticReport()

        print("\n" + String(repeating: "=", count: 60))
        print("🔍 REALTIME DIAGNOSTIC TEST")
        print(String(repeating: "=", count: 60) + "\n")

        // Test 1: Basic URL construction
        report.urlConstructionTest = testURLConstruction()

        // Test 2: WebSocket connection attempt
        report.websocketConnectionTest = await testWebSocketConnection()

        // Test 3: Connection state detection
        report.connectionStateTest = await testConnectionState()

        // Test 4: Initial message reception
        report.messageReceptionTest = await testInitialMessageReception()

        // Print summary
        printSummary(report)

        return report
    }

    // MARK: - Diagnostic Tests

    private func testURLConstruction() -> TestResult {
        let wsURL = supabaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"

        print("✅ Test 1: URL Construction")
        print("   Original: \(supabaseURL)")
        print("   WebSocket: \(realtimeURL.prefix(50))...apikey=***")

        if let url = URL(string: realtimeURL) {
            print("   ✅ Valid URL created\n")
            return TestResult(name: "URL Construction", passed: true, message: "Valid WebSocket URL")
        } else {
            print("   ❌ Failed to create URL\n")
            return TestResult(name: "URL Construction", passed: false, message: "Invalid URL format")
        }
    }

    private func testWebSocketConnection() async -> TestResult {
        print("✅ Test 2: WebSocket Connection")

        let wsURL = supabaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"

        guard let url = URL(string: realtimeURL) else {
            print("   ❌ Cannot create URL\n")
            return TestResult(name: "WebSocket Connection", passed: false, message: "Invalid URL")
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.waitsForConnectivity = true

        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: delegateQueue)

        var request = URLRequest(url: url)
        request.setValue("websocket", forHTTPHeaderField: "Connection")

        let webSocket = session.webSocketTask(with: request)
        webSocket.resume()

        print("   ⏳ Attempting to establish WebSocket connection...")

        // Give connection 5 seconds to establish
        do {
            let receiveTask = Task {
                try await webSocket.receive()
            }

            let result = await withTimeout(seconds: 5) {
                try await receiveTask.value
            }

            if result != nil {
                print("   ✅ WebSocket connected and received initial message!\n")
                webSocket.cancel()
                session.invalidateAndCancel()
                return TestResult(name: "WebSocket Connection", passed: true, message: "Successfully connected and received data")
            } else {
                print("   ❌ WebSocket connected but no data received within 5 seconds\n")
                webSocket.cancel()
                session.invalidateAndCancel()
                return TestResult(name: "WebSocket Connection", passed: false, message: "No data received (Realtime may not be enabled)")
            }
        } catch {
            print("   ❌ WebSocket connection failed: \(error.localizedDescription)\n")
            webSocket.cancel()
            session.invalidateAndCancel()
            return TestResult(name: "WebSocket Connection", passed: false, message: "Connection error: \(error.localizedDescription)")
        }
    }

    private func testConnectionState() async -> TestResult {
        print("✅ Test 3: Connection State Detection")

        let wsURL = supabaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"

        guard let url = URL(string: realtimeURL) else {
            print("   ⚠️ Invalid URL\n")
            return TestResult(name: "Connection State", passed: false, message: "Invalid URL")
        }

        let session = URLSession(configuration: .default)
        let webSocket = session.webSocketTask(with: url)

        print("   ⏳ Creating WebSocket and checking state...")
        webSocket.resume()

        // Give it a moment then try immediate receive
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        do {
            let receiveTask = Task {
                try await webSocket.receive()
            }

            let result = await withTimeout(seconds: 3) {
                try await receiveTask.value
            }

            if result != nil {
                print("   ✅ Socket received data immediately\n")
                webSocket.cancel()
                session.invalidateAndCancel()
                return TestResult(name: "Connection State", passed: true, message: "Socket responsive")
            } else {
                print("   ⚠️ Socket not responsive (timeout)\n")
                webSocket.cancel()
                session.invalidateAndCancel()
                return TestResult(name: "Connection State", passed: false, message: "Socket not responding within 3 seconds")
            }
        } catch {
            print("   ❌ Error: \(error.localizedDescription)\n")
            webSocket.cancel()
            session.invalidateAndCancel()
            return TestResult(name: "Connection State", passed: false, message: "Connection error")
        }
    }

    private func testInitialMessageReception() async -> TestResult {
        print("✅ Test 4: Initial Message Reception")

        let wsURL = supabaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"

        guard let url = URL(string: realtimeURL) else {
            print("   ⚠️ Invalid URL\n")
            return TestResult(name: "Message Reception", passed: false, message: "Invalid URL")
        }

        let session = URLSession(configuration: .default)
        let webSocket = session.webSocketTask(with: url)
        webSocket.resume()

        print("   ⏳ Waiting 2 seconds for TLS handshake...")
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        print("   ⏳ Attempting to receive initial message...")
        do {
            let receiveTask = Task {
                try await webSocket.receive()
            }

            let result = await withTimeout(seconds: 5) {
                try await receiveTask.value
            }

            if let message = result {
                switch message {
                case .string(let text):
                    print("   ✅ Received string message (\(text.count) chars)")
                    print("   Content: \(text.prefix(100))...\n")
                    webSocket.cancel()
                    session.invalidateAndCancel()
                    return TestResult(name: "Message Reception", passed: true, message: "Received initial message")
                case .data(let data):
                    print("   ✅ Received data message (\(data.count) bytes)\n")
                    webSocket.cancel()
                    session.invalidateAndCancel()
                    return TestResult(name: "Message Reception", passed: true, message: "Received initial message (binary)")
                @unknown default:
                    print("   ⚠️ Received unknown message type\n")
                    webSocket.cancel()
                    session.invalidateAndCancel()
                    return TestResult(name: "Message Reception", passed: false, message: "Unknown message type")
                }
            } else {
                print("   ❌ No initial message received (timeout)\n")
                webSocket.cancel()
                session.invalidateAndCancel()
                return TestResult(name: "Message Reception", passed: false, message: "Timeout - no initial handshake message")
            }
        } catch {
            print("   ❌ Error: \(error.localizedDescription)\n")
            webSocket.cancel()
            session.invalidateAndCancel()
            return TestResult(name: "Message Reception", passed: false, message: "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Functions

    private func withTimeout<T>(seconds: Int, operation: @escaping () async throws -> T) async -> T? {
        try? await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw URLError(.timedOut)
            }
            for try await result in group {
                return result
            }
            return nil
        }
    }

    private func printSummary(_ report: DiagnosticReport) {
        print("\n" + String(repeating: "=", count: 60))
        print("📋 DIAGNOSTIC SUMMARY")
        print(String(repeating: "=", count: 60) + "\n")

        let results = [
            report.urlConstructionTest,
            report.websocketConnectionTest,
            report.connectionStateTest,
            report.messageReceptionTest
        ].compactMap { $0 }

        for result in results {
            let icon = result.passed ? "✅" : "❌"
            print("\(icon) \(result.name)")
            print("   \(result.message)\n")
        }

        let passedCount = results.filter { $0.passed }.count
        let totalCount = results.count

        print(String(repeating: "=", count: 60))
        if passedCount == totalCount {
            print("✅ ALL TESTS PASSED - Realtime should work!")
            print("\nNext steps:")
            print("1. Rebuild and run the app")
            print("2. Check console for 'Realtime sync status: Connected'")
            print("3. Test by adding an activity from one user")
            print("4. Should receive notification on other user\n")
        } else if passedCount >= 2 {
            print("⚠️ PARTIAL SUCCESS (\(passedCount)/\(totalCount) tests passed)")
            print("\nLikely issue: Realtime not enabled on the table")
            print("\nFix:")
            print("1. Open Supabase dashboard")
            print("2. SQL Editor → Run: ALTER PUBLICATION supabase_realtime ADD TABLE public.family_activity_log;")
            print("3. Or run: supabase db push")
            print("4. Rebuild the app\n")
        } else {
            print("❌ REALTIME NOT WORKING (\(passedCount)/\(totalCount) tests passed)")
            print("\nLikely issues:")
            print("1. Realtime not enabled at project level (Settings → Extensions → Realtime)")
            print("2. Network connectivity issue")
            print("3. Invalid Supabase URL or API key\n")
            print("Quick check:")
            print("- Verify Supabase URL: \(supabaseURL)")
            print("- Check network connectivity")
            print("- Enable Realtime in Supabase dashboard if not enabled\n")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Models

struct TestResult {
    let name: String
    let passed: Bool
    let message: String
}

struct DiagnosticReport {
    var urlConstructionTest: TestResult?
    var websocketConnectionTest: TestResult?
    var connectionStateTest: TestResult?
    var messageReceptionTest: TestResult?

    var allPassed: Bool {
        let results = [urlConstructionTest, websocketConnectionTest, connectionStateTest, messageReceptionTest]
        return results.allSatisfy { $0?.passed == true }
    }
}
