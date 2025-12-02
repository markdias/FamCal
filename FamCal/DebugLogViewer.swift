//
//  DebugLogViewer.swift
//  FamCal
//
//  In-app debug log viewer
//

import SwiftUI

struct DebugLogViewer: View {
    @StateObject private var logManager = DebugLogManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var showCopiedAlert = false
    @State private var filterText = ""
    @State private var autoScroll = true

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    private var filteredLogs: [DebugLogEntry] {
        if filterText.isEmpty {
            return logManager.logs
        }
        return logManager.logs.filter { $0.message.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                theme.backgroundLayer()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with controls
                    VStack(spacing: 12) {
                        // Filter
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(secondaryTextColor)

                            TextField("Filter logs...", text: $filterText)
                                .textFieldStyle(.roundedBorder)

                            if !filterText.isEmpty {
                                Button(action: { filterText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(secondaryTextColor)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Controls
                        HStack(spacing: 12) {
                            // Auto-scroll toggle
                            HStack(spacing: 6) {
                                Image(systemName: autoScroll ? "arrow.down.to.line.alt" : "pause")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(autoScroll ? "Auto" : "Paused")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(6)
                            .onTapGesture { autoScroll.toggle() }

                            // Log count
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(filteredLogs.count)")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(secondaryTextColor)

                            Spacer()

                            // Copy button
                            Button(action: {
                                logManager.copyLogsToClipboard()
                                showCopiedAlert = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedAlert = false
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Copy")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(theme.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }

                            // Clear button
                            Button(action: { logManager.clearLogs() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Clear")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.systemGray5))
                                .foregroundColor(primaryTextColor)
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))

                    // Logs list
                    if filteredLogs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(secondaryTextColor)

                            Text(filterText.isEmpty ? "No logs yet" : "No logs match filter")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(primaryTextColor)

                            if !filterText.isEmpty {
                                Text("Try a different filter")
                                    .font(.system(size: 13))
                                    .foregroundColor(secondaryTextColor)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            List {
                                ForEach(filteredLogs) { log in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(log.formattedTime)
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundColor(secondaryTextColor)
                                                .frame(width: 60, alignment: .leading)

                                            Text(log.message)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(getLogColor(log.message))
                                                .lineLimit(nil)
                                        }
                                    }
                                    .id(log.id)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                }
                            }
                            .listStyle(.plain)
                            .onChange(of: filteredLogs.count) { _ in
                                if autoScroll, let lastLog = filteredLogs.last {
                                    withAnimation {
                                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }

                // Copied alert
                if showCopiedAlert {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)

                        Text("Logs copied!")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(16)
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(theme.accentColor)
                    }
                }
            }
        }
    }

    private func getLogColor(_ message: String) -> Color {
        if message.contains("✅") {
            return Color.green
        } else if message.contains("❌") {
            return Color.red
        } else if message.contains("⚠️") || message.contains("⏳") {
            return Color.orange
        } else if message.contains("📊") || message.contains("📡") || message.contains("💓") {
            return theme.accentColor
        } else {
            return primaryTextColor
        }
    }
}

#Preview {
    DebugLogViewer()
        .environmentObject(ThemeManager())
}
