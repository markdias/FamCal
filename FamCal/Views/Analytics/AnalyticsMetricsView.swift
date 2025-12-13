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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(
                    title: "Free Time",
                    value: formatMinutes(analytics.freeMinutes),
                    subtitle: "\(analytics.freePercentage)% of day",
                    color: .green
                )

                metricCard(
                    title: "Busy Time",
                    value: formatMinutes(analytics.busyMinutes),
                    subtitle: "\(100 - analytics.freePercentage)% of day",
                    color: .orange
                )
            }

            HStack(spacing: 12) {
                if let longestGap = analytics.longestGap {
                    metricCard(
                        title: "Longest Gap",
                        value: longestGap.formattedDuration,
                        subtitle: longestGap.formattedTimeRange,
                        color: .blue
                    )
                }

                metricCard(
                    title: "Free Blocks",
                    value: "\(analytics.gaps.count)",
                    subtitle: analytics.gaps.count == 1 ? "gap" : "gaps",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
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
        freeMinutes: 750,
        freePercentage: 83,
        gaps: [
            TimeGap(start: wakeTime, end: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!, durationMinutes: 120),
            TimeGap(start: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!, end: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startOfDay)!, durationMinutes: 240),
            TimeGap(start: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: startOfDay)!, end: bedTime, durationMinutes: 270)
        ],
        busyBlocks: [
            BusyBlock(start: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!, end: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!, durationMinutes: 60, eventTitles: ["Meeting"], calendarColors: [.systemBlue]),
            BusyBlock(start: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startOfDay)!, end: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: startOfDay)!, durationMinutes: 90, eventTitles: ["Lunch"], calendarColors: [.systemGreen])
        ],
        longestGap: TimeGap(start: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: startOfDay)!, end: bedTime, durationMinutes: 270),
        wakeTime: wakeTime,
        bedTime: bedTime
    )

    AnalyticsMetricsView(analytics: analytics)
        .padding()
}
