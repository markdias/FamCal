//
//  MorningBriefView.swift
//  FamCal
//
//  Created by Mark Dias on 24/11/2025.
//

import SwiftUI
import MapKit
import CoreLocation

struct MorningBriefView: View {
    let events: [MorningBriefEvent]
    let date: Date

    @State private var locationCoordinates: [Int: CLLocationCoordinate2D] = [:]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Schedule")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)

                Text(dateFormatter.string(from: date))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }

            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)

                    Text("No events scheduled")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        MorningBriefEventRow(
                            event: event,
                            timeFormatter: timeFormatter,
                            index: index
                        )

                        if index < events.count - 1 {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.8))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
    }
}

struct MorningBriefEvent {
    let title: String
    let startTime: Date
    let endTime: Date
    let location: String?
    let driver: String?
    let attendees: [String]
    let isAllDay: Bool

    var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }

    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        return "\(start) - \(end)"
    }
}

struct MorningBriefEventRow: View {
    let event: MorningBriefEvent
    let timeFormatter: DateFormatter
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time and Title
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)

                        if event.isAllDay {
                            Text("All day")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        } else {
                            Text(event.timeRangeString)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                // Event number badge
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))

                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .frame(width: 28, height: 28)
            }

            // Attendees
            if !event.attendees.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)

                    Text(event.attendees.joined(separator: ", "))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            }

            // Driver
            if let driver = event.driver, !driver.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)

                    Text("Driver: \(driver)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            }

            // Location
            if let location = event.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)

                    Text(location)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    MorningBriefView(
        events: [
            MorningBriefEvent(
                title: "Soccer Practice",
                startTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!,
                endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                location: "Central Park",
                driver: "John",
                attendees: ["Sarah", "Michael"],
                isAllDay: false
            ),
            MorningBriefEvent(
                title: "Family Lunch",
                startTime: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!,
                endTime: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
                location: "Downtown Restaurant",
                driver: nil,
                attendees: ["Everyone"],
                isAllDay: false
            ),
            MorningBriefEvent(
                title: "Piano Lesson",
                startTime: Calendar.current.date(byAdding: .hour, value: 5, to: Date())!,
                endTime: Calendar.current.date(byAdding: .hour, value: 6, to: Date())!,
                location: "Music Studio",
                driver: "Sarah",
                attendees: ["Emma"],
                isAllDay: false
            )
        ],
        date: Date()
    )
}
