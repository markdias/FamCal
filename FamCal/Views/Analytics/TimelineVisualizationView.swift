//
//  TimelineVisualizationView.swift
//  FamCal
//
//  Visualizes daily schedule as a horizontal timeline
//

import SwiftUI

struct TimelineVisualizationView: View {
    let analytics: TimeAnalytics
    let memberColor: UIColor
    @Binding var selectedBlock: BusyBlock?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background (full timeline)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 40)

                    // Busy blocks - color-coded
                    ForEach(analytics.busyBlocks) { block in
                        busyBlockView(block, totalWidth: geometry.size.width, isSelected: selectedBlock?.id == block.id)
                    }

                    // Current time indicator (if today)
                    if Calendar.current.isDateInToday(analytics.date) {
                        currentTimeIndicator(totalWidth: geometry.size.width)
                    }
                }
            }
            .frame(height: 40)

            // Time labels
            HStack {
                Text(timeLabel(analytics.wakeTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text(timeLabel(analytics.bedTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private func busyBlockView(_ block: BusyBlock, totalWidth: CGFloat, isSelected: Bool) -> some View {
        let position = calculatePosition(for: block, totalWidth: totalWidth)

        return RoundedRectangle(cornerRadius: 6)
            .fill(Color(memberColor))
            .opacity(isSelected ? 1.0 : 0.8)
            .frame(width: position.width, height: 36)
            .offset(x: position.offset)
            .overlay(
                isSelected ? RoundedRectangle(cornerRadius: 6).stroke(Color(memberColor), lineWidth: 3) : nil
            )
            .onTapGesture {
                selectedBlock = block
            }
    }

    private func currentTimeIndicator(totalWidth: CGFloat) -> some View {
        let now = Date()
        let position = calculateTimePosition(now, totalWidth: totalWidth)

        return Rectangle()
            .fill(Color.red)
            .frame(width: 2, height: 40)
            .offset(x: position)
    }

    private func calculatePosition(for block: BusyBlock, totalWidth: CGFloat) -> (offset: CGFloat, width: CGFloat) {
        let totalMinutes = analytics.totalAvailableMinutes
        let startOffset = block.start.timeIntervalSince(analytics.wakeTime) / 60
        let duration = block.durationMinutes

        let offsetPercentage = startOffset / Double(totalMinutes)
        let widthPercentage = Double(duration) / Double(totalMinutes)

        return (
            offset: CGFloat(offsetPercentage) * totalWidth,
            width: CGFloat(widthPercentage) * totalWidth
        )
    }

    private func calculateTimePosition(_ time: Date, totalWidth: CGFloat) -> CGFloat {
        let totalMinutes = analytics.totalAvailableMinutes
        let offset = time.timeIntervalSince(analytics.wakeTime) / 60
        let offsetPercentage = offset / Double(totalMinutes)
        return CGFloat(offsetPercentage) * totalWidth
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let startOfDay = calendar.startOfDay(for: now)

    let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay)!
    let bedTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!

    // Create sample events
    let event1Start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
    let event1End = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!

    let event2Start = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startOfDay)!
    let event2End = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: startOfDay)!

    let analytics = TimeAnalytics(
        date: now,
        memberID: UUID(),
        totalAvailableMinutes: 15 * 60,
        busyMinutes: 150,
        freeMinutes: 750,
        freePercentage: 83,
        gaps: [
            TimeGap(start: wakeTime, end: event1Start, durationMinutes: 120),
            TimeGap(start: event1End, end: event2Start, durationMinutes: 240),
            TimeGap(start: event2End, end: bedTime, durationMinutes: 270)
        ],
        busyBlocks: [
            BusyBlock(start: event1Start, end: event1End, durationMinutes: 60, eventTitles: ["Meeting"]),
            BusyBlock(start: event2Start, end: event2End, durationMinutes: 90, eventTitles: ["Lunch", "Follow-up"])
        ],
        longestGap: TimeGap(start: event2End, end: bedTime, durationMinutes: 270),
        wakeTime: wakeTime,
        bedTime: bedTime
    )

    TimelineVisualizationView(analytics: analytics, memberColor: .systemBlue, selectedBlock: .constant(nil))
        .padding()
}
