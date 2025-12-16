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
    @Binding var selectedGap: TimeGap?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                let segments = buildSegments()

                ZStack(alignment: .topLeading) {
                    // Segments laid on a single rail (no baseline)
                    ForEach(segments) { segment in
                        let isSelected = isSegmentSelected(segment)
                        segmentView(segment, totalWidth: geometry.size.width, isSelected: isSelected)
                            .zIndex(isSelected ? 3 : 1)
                    }

                    // Current time indicator (if today)
                    if Calendar.current.isDateInToday(analytics.date) {
                        currentTimeIndicator(totalWidth: geometry.size.width)
                            .offset(y: 4)
                    }
                }
            }
            .frame(height: 26)

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

    private func segmentView(_ segment: TimelineSegment, totalWidth: CGFloat, isSelected: Bool) -> some View {
        let position = calculatePosition(for: segment.start, end: segment.end, totalWidth: totalWidth)
        let inset: CGFloat = 2 // create a visual break between segments so it doesn't look like a single line
        let adjustedWidth = max(position.width - inset, 4)
        let adjustedOffset = position.offset + inset / 2
        let baseOpacity: Double = isSelected ? 0.9 : 0.75

        return RoundedRectangle(cornerRadius: 2)
            .fill(segment.color.opacity(baseOpacity))
            .frame(width: adjustedWidth, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(isSelected ? 0.6 : 0.12), lineWidth: isSelected ? 2 : 1)
            )
            .offset(x: adjustedOffset, y: 6)
            .contentShape(Rectangle())
            .onTapGesture {
                handleSelection(for: segment)
            }
    }

    private func currentTimeIndicator(totalWidth: CGFloat) -> some View {
        let now = Date()
        let position = calculateTimePosition(now, totalWidth: totalWidth)

        return Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .offset(x: position - 4, y: 0)
    }

    private func calculatePosition(for start: Date, end: Date, totalWidth: CGFloat) -> (offset: CGFloat, width: CGFloat) {
        let totalMinutes = analytics.totalAvailableMinutes
        let startOffset = start.timeIntervalSince(analytics.wakeTime) / 60
        let duration = Int(end.timeIntervalSince(start) / 60)

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

    // MARK: - Segment building

    private struct TimelineSegment: Identifiable {
        enum Kind {
            case gap(UUID)
            case travel(UUID)
            case event(UUID)
        }

        let id = UUID()
        let kind: Kind
        let start: Date
        let end: Date
        let color: Color
    }

    private func buildSegments() -> [TimelineSegment] {
        var segments: [TimelineSegment] = []

        // Free time segments
        for gap in analytics.gaps.sorted(by: { $0.start < $1.start }) {
            segments.append(
                TimelineSegment(
                    kind: .gap(gap.id),
                    start: gap.start,
                    end: gap.end,
                    color: Color.blue
                )
            )
        }

        // Busy segments (travel + event portions)
        for block in analytics.busyBlocks.sorted(by: { $0.start < $1.start }) {
            let travelMinutes = max(0, block.travelDurationMinutes)
            let travelEnd = Calendar.current.date(byAdding: .minute, value: travelMinutes, to: block.start) ?? block.start
            let clampedTravelEnd = min(travelEnd, block.end)

            if travelMinutes > 0, block.start < clampedTravelEnd {
                segments.append(
                    TimelineSegment(
                        kind: .travel(block.id),
                        start: block.start,
                        end: clampedTravelEnd,
                        color: Color.orange
                    )
                )
            }

            let eventStart = travelMinutes > 0 ? clampedTravelEnd : block.start
            if eventStart < block.end {
                segments.append(
                    TimelineSegment(
                        kind: .event(block.id),
                        start: eventStart,
                        end: block.end,
                        color: blockColor(for: block)
                    )
                )
            }
        }

        return segments.sorted { $0.start < $1.start }
    }

    private func handleSelection(for segment: TimelineSegment) {
        switch segment.kind {
        case .gap(let gapId):
            if selectedGap?.id == gapId {
                selectedGap = nil
            } else {
                selectedBlock = nil
                selectedGap = analytics.gaps.first(where: { $0.id == gapId })
            }
        case .travel(let blockId), .event(let blockId):
            if selectedBlock?.id == blockId {
                selectedBlock = nil
            } else {
                selectedGap = nil
                selectedBlock = analytics.busyBlocks.first(where: { $0.id == blockId })
            }
        }
    }

    private func isSegmentSelected(_ segment: TimelineSegment) -> Bool {
        switch segment.kind {
        case .gap(let gapId):
            return selectedGap?.id == gapId
        case .travel(let blockId), .event(let blockId):
            return selectedBlock?.id == blockId
        }
    }

    private func blockColor(for block: BusyBlock) -> Color {
        let baseColor = block.calendarColors.first ?? UIColor.systemGray4
        let color = Color(baseColor)
        return block.isFree ? color.opacity(0.35) : color
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
        travelMinutes: 0,
        freeMinutes: 750,
        freePercentage: 83,
        gaps: [
            TimeGap(start: wakeTime, end: event1Start, durationMinutes: 120),
            TimeGap(start: event1End, end: event2Start, durationMinutes: 240),
            TimeGap(start: event2End, end: bedTime, durationMinutes: 270)
        ],
        busyBlocks: [
            BusyBlock(start: event1Start, end: event1End, durationMinutes: 60, travelDurationMinutes: 0, eventTitles: ["Meeting"], calendarColors: [.systemBlue], isFree: false),
            BusyBlock(start: event2Start, end: event2End, durationMinutes: 90, travelDurationMinutes: 0, eventTitles: ["Lunch", "Follow-up"], calendarColors: [.systemGreen, .systemRed], isFree: false)
        ],
        longestGap: TimeGap(start: event2End, end: bedTime, durationMinutes: 270),
        wakeTime: wakeTime,
        bedTime: bedTime
    )

    TimelineVisualizationView(
        analytics: analytics,
        memberColor: .systemBlue,
        selectedBlock: .constant(nil),
        selectedGap: .constant(nil)
    )
        .padding()
}
