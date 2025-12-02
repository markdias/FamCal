//
//  DebugLogManager.swift
//  FamCal
//
//  Captures console logs and makes them viewable in-app
//

import Foundation
import Combine
import UIKit

class DebugLogManager: ObservableObject {
    @Published var logs: [DebugLogEntry] = []
    @Published var isCapturing = true

    static let shared = DebugLogManager()

    private let maxLogEntries = 500
    private let queue = DispatchQueue(label: "com.famcal.debuglogs")

    private var originalStdout: Int32 = 0
    private var originalStderr: Int32 = 0
    private var pipeRead: Int32 = 0
    private var pipeWrite: Int32 = 0

    init() {
        setupPipeCapture()
    }

    private func setupPipeCapture() {
        // Create a pipe to capture stdout
        var pipeFDs: [Int32] = [0, 0]
        if pipe(&pipeFDs) == 0 {
            pipeRead = pipeFDs[0]
            pipeWrite = pipeFDs[1]

            // Duplicate stdout to preserve it
            originalStdout = dup(STDOUT_FILENO)
            originalStderr = dup(STDERR_FILENO)

            // Redirect stdout and stderr to our pipe
            dup2(pipeWrite, STDOUT_FILENO)
            dup2(pipeWrite, STDERR_FILENO)

            // Start reading from the pipe in background
            startCapturingLogs()
        }
    }

    private func startCapturingLogs() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let bufferSize = 1024
            var buffer = [CChar](repeating: 0, count: bufferSize)

            while true {
                let bytesRead = read(self?.pipeRead ?? 0, &buffer, bufferSize - 1)
                if bytesRead > 0 {
                    buffer[bytesRead] = 0
                    if let str = String(cString: buffer, encoding: .utf8) {
                        self?.addLog(str)
                    }
                }
            }
        }
    }

    func addLog(_ message: String) {
        guard isCapturing else { return }

        queue.async { [weak self] in
            let timestamp = Date()
            let logEntry = DebugLogEntry(message: message.trimmingCharacters(in: .newlines), timestamp: timestamp)

            DispatchQueue.main.async {
                self?.logs.append(logEntry)

                // Keep only the last N entries
                if (self?.logs.count ?? 0) > (self?.maxLogEntries ?? 500) {
                    self?.logs = Array(self?.logs.dropFirst(self?.logs.count ?? 0 - (self?.maxLogEntries ?? 500)) ?? [])
                }
            }
        }
    }

    func clearLogs() {
        logs.removeAll()
    }

    func exportLogs() -> String {
        logs.map { "\($0.timestamp.formatted(date: .omitted, time: .standard)) - \($0.message)" }
            .joined(separator: "\n")
    }

    func copyLogsToClipboard() {
        let logsText = exportLogs()
        UIPasteboard.general.string = logsText
    }
}

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let message: String
    let timestamp: Date

    var formattedTime: String {
        timestamp.formatted(date: .omitted, time: .standard)
    }
}
