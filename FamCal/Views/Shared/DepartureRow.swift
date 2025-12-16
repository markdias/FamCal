//
//  DepartureRow.swift
//  FamCal
//
//  Small helper to render departure (travel time) and time range consistently.
//

import SwiftUI

struct DepartureRow: View {
    let startDate: Date
    let travelMinutes: Int?
    let timeRange: String?
    var fontSize: CGFloat = 11
    var iconColor: Color = .orange
    var textColor: Color = .secondary
    /// When true, show both departure (if any) and the time range on the same row.
    var showTimeRange: Bool = true

    private var departureText: String? {
        guard let minutes = travelMinutes, minutes > 0 else { return nil }
        let departure = CalendarManager.shared.calculateDepartureTime(
            eventStartDate: startDate,
            travelTimeMinutes: minutes
        )
        return departure.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 8) {
            if let departureText {
                Label(departureText, systemImage: "car.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            if showTimeRange, let timeRange {
                Text(timeRange)
                    .font(.system(size: fontSize, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(textColor)
            } else if !showTimeRange, departureText == nil, let timeRange {
                // If no departure, still show time range when requested even if showTimeRange is false
                Text(timeRange)
                    .font(.system(size: fontSize, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(textColor)
            }
        }
    }
}

