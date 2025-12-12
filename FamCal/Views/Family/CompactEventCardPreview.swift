//
//  CompactEventCardPreview.swift
//  FamCal
//
//  Preview view for testing different compact event card designs
//

import SwiftUI

struct CompactEventCardPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Compact Event Card Design Options")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal)

                // Option 1: Left bar with inline layout
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 1: Left Bar + Inline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    CompactCardOption1(
                        color: .blue,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "09:00",
                        title: "Morning Standup"
                    )

                    CompactCardOption1(
                        color: .green,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "14:30",
                        title: "Client Meeting with Design Team Review"
                    )

                    CompactCardOption1(
                        color: .orange,
                        dayOfWeek: "Tue",
                        day: "19",
                        time: "All Day",
                        title: "Conference"
                    )
                }

                Divider()

                // Option 2: Colored circle + horizontal layout
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 2: Circle Indicator + Horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    CompactCardOption2(
                        color: .blue,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "09:00",
                        title: "Morning Standup"
                    )

                    CompactCardOption2(
                        color: .green,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "14:30",
                        title: "Client Meeting with Design Team Review"
                    )

                    CompactCardOption2(
                        color: .orange,
                        dayOfWeek: "Tue",
                        day: "19",
                        time: "All Day",
                        title: "Conference"
                    )
                }

                Divider()

                // Option 3: Minimal with colored top border
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 3: Top Border + Dense Layout")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    CompactCardOption3(
                        color: .blue,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "09:00",
                        title: "Morning Standup"
                    )

                    CompactCardOption3(
                        color: .green,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "14:30",
                        title: "Client Meeting with Design Team Review"
                    )

                    CompactCardOption3(
                        color: .orange,
                        dayOfWeek: "Tue",
                        day: "19",
                        time: "All Day",
                        title: "Conference"
                    )
                }

                Divider()

                // Option 4: Date box minimal + title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 4: Small Date Box + Title")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    CompactCardOption4(
                        color: .blue,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "09:00",
                        title: "Morning Standup"
                    )

                    CompactCardOption4(
                        color: .green,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "14:30",
                        title: "Client Meeting with Design Team Review"
                    )

                    CompactCardOption4(
                        color: .orange,
                        dayOfWeek: "Tue",
                        day: "19",
                        time: "All Day",
                        title: "Conference"
                    )
                }

                Divider()

                // Option 5: List style with leading icon
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 5: List Style with Icon")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    CompactCardOption5(
                        color: .blue,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "09:00",
                        title: "Morning Standup",
                        hasLocation: false
                    )

                    CompactCardOption5(
                        color: .green,
                        dayOfWeek: "Mon",
                        day: "18",
                        time: "14:30",
                        title: "Client Meeting with Design Team Review",
                        hasLocation: true
                    )

                    CompactCardOption5(
                        color: .orange,
                        dayOfWeek: "Tue",
                        day: "19",
                        time: "All Day",
                        title: "Conference",
                        hasLocation: false
                    )
                }

                Divider()

                // Current detailed view for comparison
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Detailed View (for comparison)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    DetailedEventCard(
                        color: .blue,
                        dayOfWeek: "Mon",
                        day: "18",
                        month: "Dec",
                        startTime: "09:00",
                        endTime: "09:30",
                        title: "Morning Standup",
                        location: "Conference Room A"
                    )
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Option 1: Left Bar + Inline

struct CompactCardOption1: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            // Colored left bar
            Rectangle()
                .fill(color)
                .frame(width: 4)

            HStack(spacing: 8) {
                // Date
                Text("\(dayOfWeek) \(day)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Time
                Text(time)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Title with recurrence icon placeholder
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    // Note: recurrence icon would go here if data was available
                }

                Spacer(minLength: 0)

                // Sample checklist indicator
                if title.contains("Standup") {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.square")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("2/3")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Option 2: Circle Indicator + Horizontal

struct CompactCardOption2: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            // Colored circle
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            // Date
            Text("\(dayOfWeek) \(day)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            // Separator
            Text("•")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Time
            Text(time)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundColor(.secondary)

            // Separator
            Text("•")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Title with recurrence icon placeholder
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                // Note: recurrence icon would go here if data was available
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Option 3: Top Border + Dense Layout

struct CompactCardOption3: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            // Top colored border
            Rectangle()
                .fill(color)
                .frame(height: 3)

            HStack(spacing: 10) {
                // Date
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayOfWeek)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(day)
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        // Note: recurrence icon would go here if data was available
                    }

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
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Option 4: Small Date Box + Title

struct CompactCardOption4: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            // Small colored date box
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
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    // Note: recurrence icon would go here if data was available
                }

                Text(time)
                    .font(.system(size: 11, weight: .regular))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Option 5: List Style with Icon

struct CompactCardOption5: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let time: String
    let title: String
    let hasLocation: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Calendar icon with color
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)

            // Date and time
            VStack(alignment: .leading, spacing: 1) {
                Text("\(dayOfWeek), \(day)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(time)
                    .font(.system(size: 10, weight: .regular))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .frame(width: 55, alignment: .leading)

            // Title with location and recurrence indicators
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                // Note: recurrence icon would go here if data was available

                if hasLocation {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Current Detailed View (for comparison)

struct DetailedEventCard: View {
    let color: Color
    let dayOfWeek: String
    let day: String
    let month: String
    let startTime: String
    let endTime: String
    let title: String
    let location: String?

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))

            // Colored date panel
            color
                .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .bottomLeft]))
                .frame(width: 64)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(dayOfWeek)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    Text(day)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(month)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(width: 64)
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)
                            // Note: recurrence icon would go here if data was available
                        }

                        Spacer(minLength: 0)

                        Text(startTime)
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }

                    if let location = location {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(location)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Text(endTime)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)

                Spacer(minLength: 0)
            }
        }
        .frame(height: 64)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    CompactEventCardPreview()
}
