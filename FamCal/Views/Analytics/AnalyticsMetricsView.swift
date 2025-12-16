//
//  AnalyticsMetricsView.swift
//  FamCal
//
//  Displays key metrics for daily time analytics
//

import SwiftUI

struct AnalyticsMetricsView: View {
    let analytics: TimeAnalytics

    var body: some View {
        let cards = metricCards()

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(cards, id: \.title) { card in
                metricCard(
                    title: card.title,
                    value: card.value,
                    subtitle: card.subtitle,
                    color: card.color,
                    footer: card.footer
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color, footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private struct MetricCardData {
        let title: String
        let value: String
        let subtitle: String
        let footer: String?
        let color: Color
    }

    private func metricCards() -> [MetricCardData] {
        var cards: [MetricCardData] = [
            MetricCardData(
                title: "Free Time",
                value: formatMinutes(analytics.freeMinutes),
                subtitle: "\(analytics.freePercentage)% of day",
                footer: nil,
                color: .green
            ),
            MetricCardData(
                title: "Busy Time",
                value: formatMinutes(analytics.busyMinutes),
                subtitle: "\(100 - analytics.freePercentage)% of day",
                footer: nil,
                color: .orange
            ),
            MetricCardData(
                title: "Travel Time",
                value: formatMinutes(analytics.travelMinutes),
                subtitle: analytics.travelMinutes > 0 ? "Counted as busy" : "No travel today",
                footer: nil,
                color: .orange.opacity(0.85)
            )
        ]

        if let longestGap = analytics.longestGap {
            cards.append(
                MetricCardData(
                    title: "Longest Gap",
                    value: longestGap.formattedDuration,
                    subtitle: longestGap.formattedTimeRange,
                    footer: nil,
                    color: .blue
                )
            )
        }

        cards.append(
            MetricCardData(
                title: "Free Blocks",
                value: "\(analytics.gaps.count)",
                subtitle: analytics.gaps.count == 1 ? "gap" : "gaps",
                footer: nil,
                color: .purple
            )
        )

        return cards
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let startOfDay = calendar.startOfDay(for: now)

    let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay)!
    let bedTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!

    let analytics = TimeAnalytics(
        date: now,
        memberID: UUID(),
        totalAvailableMinutes: 900,
        busyMinutes: 150,
        travelMinutes: 0,
        freeMinutes: 750,
        freePercentage: 83,
        gaps: [
            TimeGap(start: wakeTime, end: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!, durationMinutes: 120),
            TimeGap(start: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!, end: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startOfDay)!, durationMinutes: 240),
            TimeGap(start: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: startOfDay)!, end: bedTime, durationMinutes: 270)
        ],
        busyBlocks: [
            BusyBlock(start: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!, end: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!, durationMinutes: 60, travelDurationMinutes: 0, eventTitles: ["Meeting"], calendarColors: [.systemBlue], isFree: false),
            BusyBlock(start: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startOfDay)!, end: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: startOfDay)!, durationMinutes: 90, travelDurationMinutes: 0, eventTitles: ["Lunch"], calendarColors: [.systemGreen], isFree: false)
        ],
        longestGap: TimeGap(start: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: startOfDay)!, end: bedTime, durationMinutes: 270),
        wakeTime: wakeTime,
        bedTime: bedTime
    )

    AnalyticsMetricsView(analytics: analytics)
        .padding()
}
