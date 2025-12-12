//
//  NextEventCompactOptionsView.swift
//  FamCal
//
//  Reference view to preview compact next-event card layouts without touching the live app UI.
//

import SwiftUI

struct NextEventCompactOptionsView: View {
    private let samples: [SampleNextEvent] = [
        SampleNextEvent(name: "Alex", title: "Math Club Presentation", dateText: "Today", timeText: "4:00–5:00 PM", status: "In 35 min", statusColor: .blue, location: "Room 204", hasMeetingLink: false, color: .blue),
        SampleNextEvent(name: "Chris", title: "Soccer Practice", dateText: "Today", timeText: "5:30–7:00 PM", status: "Starts in 2h", statusColor: .green, location: "Memorial Field", hasMeetingLink: false, color: .green),
        SampleNextEvent(name: "Dana", title: "Parent-Teacher Conference", dateText: "Tomorrow", timeText: "9:00–9:30 AM", status: "Tomorrow", statusColor: .orange, location: nil, hasMeetingLink: true, color: .orange),
        SampleNextEvent(name: "Jamie", title: "Dentist Appointment", dateText: "Fri 14 Mar", timeText: "All Day", status: "All day", statusColor: .purple, location: "Downtown Dental", hasMeetingLink: false, color: .purple)
    ]

    private let styles: [CompactNextEventStyle] = CompactNextEventStyle.allCases

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact Next Event Ideas")
                            .font(.system(size: 22, weight: .bold))
                        Text("Use these mockups to compare a few dense layouts for the per-person next event row. The live app stays unchanged until you pick one.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    ForEach(styles) { style in
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(style.title)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(style.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            VStack(spacing: 10) {
                                ForEach(samples) { sample in
                                    optionCard(style: style, event: sample)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    }
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Next Event Layouts")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func optionCard(style: CompactNextEventStyle, event: SampleNextEvent) -> some View {
        switch style {
        case .stripe:
            StripeCard(event: event)
        case .pill:
            PillCard(event: event)
        case .stacked:
            StackedBadgeCard(event: event)
        }
    }
}

// MARK: - Styles

private enum CompactNextEventStyle: String, CaseIterable, Identifiable {
    case stripe
    case pill
    case stacked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stripe: return "Option A — Stripe"
        case .pill: return "Option B — Pill"
        case .stacked: return "Option C — Stacked badge"
        }
    }

    var subtitle: String {
        switch self {
        case .stripe:
            return "Matches the compact layout wired into FamilyView: color bar + tight text stack."
        case .pill:
            return "Inline pill with calendar dot, condensed date/time, and trailing status tag."
        case .stacked:
            return "Small stacked row with colored badge and single-line metadata."
        }
    }
}

// MARK: - Sample Models

private struct SampleNextEvent: Identifiable {
    let id = UUID()
    let name: String
    let title: String
    let dateText: String
    let timeText: String?
    let status: String
    let statusColor: Color
    let location: String?
    let hasMeetingLink: Bool
    let color: Color
}

// MARK: - Cards

private struct StripeCard: View {
    let event: SampleNextEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(event.color)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    // Note: hasRecurrence not available in sample data for this preview
                }

                HStack(spacing: 8) {
                    Text(event.dateText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    if let time = event.timeText {
                        Text(time)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                if let location = event.location {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else if event.hasMeetingLink {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Meet/Zoom link")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(event.status)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(event.statusColor)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(.separator), lineWidth: 1))
    }
}

private struct PillCard: View {
    let event: SampleNextEvent

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(event.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    // Note: hasRecurrence not available in sample data for this preview
                }
                HStack(spacing: 8) {
                    Text(event.dateText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    if let time = event.timeText {
                        Text(time)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    if event.hasMeetingLink {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    } else if event.location != nil {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(event.status)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(event.statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(event.statusColor.opacity(0.12))
                .cornerRadius(10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

private struct StackedBadgeCard: View {
    let event: SampleNextEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(event.name)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(event.color.opacity(0.12))
                    .foregroundColor(event.color)
                    .cornerRadius(8)

                Text(event.status)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(event.statusColor)
            }

            HStack(spacing: 6) {
                Text(event.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(2)
                // Note: hasRecurrence not available in sample data for this preview
            }

            HStack(spacing: 8) {
                Text(event.dateText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                if let time = event.timeText {
                    Text(time)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                if event.hasMeetingLink {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                } else if let location = event.location {
                    Text(location)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

#Preview {
    NextEventCompactOptionsView()
}
