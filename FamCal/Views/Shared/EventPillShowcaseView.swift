//
//  EventPillShowcaseView.swift
//  FamCal
//
//  Visual playground to align travel-time placement across all pill styles.
//

import SwiftUI

private struct ShowcaseSampleEvent: Identifiable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date
    let travelMinutes: Int?
    let timeRange: String
    let memberName: String
    let calendarColor: UIColor
    let location: String?
    let isAllDay: Bool
}

struct EventPillShowcaseView: View {
    private let sample: ShowcaseSampleEvent = {
        let start = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date()) ?? Date()
        let end = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
        return ShowcaseSampleEvent(
            title: "Team Strategy Session",
            start: start,
            end: end,
            travelMinutes: 30,
            timeRange: "15:00 – 17:00",
            memberName: "Jordan",
            calendarColor: UIColor.systemBlue,
            location: "HQ — Room 4",
            isAllDay: false
        )
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Next Event (Standard)")
                nextEventCard(sample)

                sectionTitle("Next Event (Compact)")
                compactNextEventCard(sample)

                sectionTitle("Upcoming Detailed / Spotlight / Monthly Pill")
                detailedPill(sample)

                sectionTitle("Compact Event Card")
                compactPill(sample)

                sectionTitle("Spotlight Scheduled Row")
                spotlightScheduleRow(sample)

                sectionTitle("Calendar Day/Timeline Row")
                timelineRow(sample)

                sectionTitle("Morning Brief Row")
                briefRow(sample)

                sectionTitle("Widget Style")
                widgetStyle(sample)

                sectionTitle("Event Search Row")
                searchRow(sample)

                sectionTitle("Event Detail Header")
                detailHeader(sample)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Pills

    private func nextEventCard(_ event: ShowcaseSampleEvent) -> some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.memberName)
                    .font(.system(size: 14, weight: .semibold))
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                DepartureRow(
                    startDate: event.start,
                    travelMinutes: event.travelMinutes,
                    timeRange: event.timeRange,
                    fontSize: 12,
                    iconColor: .orange,
                    textColor: .secondary
                )

                Text(formatRelativeDate(event.start))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func compactNextEventCard(_ event: ShowcaseSampleEvent) -> some View {
        card {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color(event.calendarColor))
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.memberName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)

                    Text(event.timeRange)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    DepartureRow(
                        startDate: event.start,
                        travelMinutes: event.travelMinutes,
                        timeRange: nil,
                        fontSize: 11,
                        iconColor: .orange,
                        textColor: .secondary,
                        showTimeRange: false
                    )

                    Text(formatRelativeDate(event.start))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    private func detailedPill(_ event: ShowcaseSampleEvent) -> some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                DepartureRow(
                    startDate: event.start,
                    travelMinutes: event.travelMinutes,
                    timeRange: event.timeRange,
                    fontSize: 11,
                    iconColor: .orange,
                    textColor: .secondary
                )

                if let location = event.location {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func compactPill(_ event: ShowcaseSampleEvent) -> some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Sun 14")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(event.timeRange.split(separator: "–").first ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }

                DepartureRow(
                    startDate: event.start,
                    travelMinutes: event.travelMinutes,
                    timeRange: nil,
                    fontSize: 11,
                    iconColor: .orange,
                    textColor: .secondary,
                    showTimeRange: false
                )
            }
        }
    }

    private func spotlightScheduleRow(_ event: ShowcaseSampleEvent) -> some View {
        card {
            HStack(spacing: 12) {
                Text(event.timeRange.split(separator: "–").first ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)

                    DepartureRow(
                        startDate: event.start,
                        travelMinutes: event.travelMinutes,
                        timeRange: nil,
                        fontSize: 11,
                        iconColor: .orange,
                        textColor: .secondary,
                        showTimeRange: false
                    )
                }
                Spacer()

                Text(event.timeRange)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
    }

    private func timelineRow(_ event: ShowcaseSampleEvent) -> some View {
        card {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(event.calendarColor))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                    DepartureRow(
                        startDate: event.start,
                        travelMinutes: event.travelMinutes,
                        timeRange: event.timeRange,
                        fontSize: 11,
                        iconColor: .orange,
                        textColor: .secondary
                    )
                }
                Spacer()
            }
        }
    }

    private func briefRow(_ event: ShowcaseSampleEvent) -> some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(event.timeRange)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                DepartureRow(
                    startDate: event.start,
                    travelMinutes: event.travelMinutes,
                    timeRange: nil,
                    fontSize: 11,
                    iconColor: .orange,
                    textColor: .secondary,
                    showTimeRange: false
                )
            }
        }
    }

    private func widgetStyle(_ event: ShowcaseSampleEvent) -> some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                DepartureRow(
                    startDate: event.start,
                    travelMinutes: event.travelMinutes,
                    timeRange: event.timeRange,
                    fontSize: 11,
                    iconColor: .orange,
                    textColor: .secondary
                )
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func searchRow(_ event: ShowcaseSampleEvent) -> some View {
        card {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(event.calendarColor))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                    DepartureRow(
                        startDate: event.start,
                        travelMinutes: event.travelMinutes,
                        timeRange: event.timeRange,
                        fontSize: 11,
                        iconColor: .orange,
                        textColor: .secondary
                    )
                }
                Spacer()
            }
        }
    }

    private func detailHeader(_ event: ShowcaseSampleEvent) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))
                DepartureRow(
                    startDate: event.start,
                    travelMinutes: event.travelMinutes,
                    timeRange: event.timeRange,
                    fontSize: 12,
                    iconColor: .orange,
                    textColor: .secondary
                )
                Text("Location: \(event.location ?? "N/A")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<Content: View>(_ content: () -> Content) -> some View {
        VStack {
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.tertiarySystemFill), lineWidth: 1)
        )
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    EventPillShowcaseView()
}
