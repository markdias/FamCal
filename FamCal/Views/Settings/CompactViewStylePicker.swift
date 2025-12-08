//
//  CompactViewStylePicker.swift
//  FamCal
//
//  Settings view for selecting compact event card style
//

import SwiftUI

// MARK: - Compact Card Components

private struct PickerCompactCardOption1: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 4)

            HStack(spacing: 8) {
                Text("\(dayOfWeek) \(day)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                Text(time)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

private struct PickerCompactCardOption3: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(height: 3)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayOfWeek)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(day)
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text(time)
                        .font(.system(size: 11, weight: .regular))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

private struct PickerCompactCardOption4: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(day)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 36, height: 36)
            .background(color)
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(time)
                    .font(.system(size: 11, weight: .regular))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Main View

struct CompactViewStylePicker: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Your Compact View Style")
                            .font(.system(size: 20, weight: .bold))

                        Text("Select how upcoming events appear when using compact view. Tap a style to preview and select it.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)

                    // Option 1: Left Bar + Inline
                    StyleOptionCard(
                        title: "Left Bar",
                        description: "Colored bar with inline date, time, and title",
                        isSelected: appSettingsManager.compactViewStyle == "option1"
                    ) {
                        appSettingsManager.compactViewStyle = "option1"
                    } preview: {
                        VStack(spacing: 8) {
                            PickerCompactCardOption1(
                                color: .blue,
                                dayOfWeek: "Mon",
                                day: "18",
                                time: "09:00",
                                title: "Morning Standup"
                            )

                            PickerCompactCardOption1(
                                color: .green,
                                dayOfWeek: "Mon",
                                day: "18",
                                time: "14:30",
                                title: "Client Meeting"
                            )

                            PickerCompactCardOption1(
                                color: .orange,
                                dayOfWeek: "Tue",
                                day: "19",
                                time: "All Day",
                                title: "Conference"
                            )
                        }
                    }

                    // Option 3: Top Border + Dense Layout
                    StyleOptionCard(
                        title: "Top Border",
                        description: "Colored top border with compact date box",
                        isSelected: appSettingsManager.compactViewStyle == "option3"
                    ) {
                        appSettingsManager.compactViewStyle = "option3"
                    } preview: {
                        VStack(spacing: 8) {
                            PickerCompactCardOption3(
                                color: .blue,
                                dayOfWeek: "Mon",
                                day: "18",
                                time: "09:00",
                                title: "Morning Standup"
                            )

                            PickerCompactCardOption3(
                                color: .green,
                                dayOfWeek: "Mon",
                                day: "18",
                                time: "14:30",
                                title: "Client Meeting"
                            )

                            PickerCompactCardOption3(
                                color: .orange,
                                dayOfWeek: "Tue",
                                day: "19",
                                time: "All Day",
                                title: "Conference"
                            )
                        }
                    }

                    // Option 4: Small Date Box + Title
                    StyleOptionCard(
                        title: "Date Box",
                        description: "Colored date box with stacked title and time",
                        isSelected: appSettingsManager.compactViewStyle == "option4"
                    ) {
                        appSettingsManager.compactViewStyle = "option4"
                    } preview: {
                        VStack(spacing: 8) {
                            PickerCompactCardOption4(
                                color: .blue,
                                dayOfWeek: "Mon",
                                day: "18",
                                time: "09:00",
                                title: "Morning Standup"
                            )

                            PickerCompactCardOption4(
                                color: .green,
                                dayOfWeek: "Mon",
                                day: "18",
                                time: "14:30",
                                title: "Client Meeting"
                            )

                            PickerCompactCardOption4(
                                color: .orange,
                                dayOfWeek: "Tue",
                                day: "19",
                                time: "All Day",
                                title: "Conference"
                            )
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .background(theme.backgroundLayer())
            .navigationTitle("Compact View Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Style Option Card

struct StyleOptionCard<Preview: View>: View {
    let title: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void
    @ViewBuilder let preview: Preview

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                }

                preview
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

