//
//  NextEventWidgetView.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import SwiftUI
import WidgetKit

/// Condensed widget UI for displaying next upcoming event
struct NextEventWidgetView: View {
    let entry: NextEventProvider.Entry

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    var body: some View {
        ZStack {
            if !entry.isAuthenticated {
                // Login required state
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)

                    Text("Login Required")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Open FamCal and sign in to view events")
                        .font(.system(size: 12, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineLimit(3)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(16)
            } else if let event = entry.event, let member = entry.familyMember {
                // Content with event - expands edge-to-edge
                eventCardContent(event: event, member: member)
            } else if let error = entry.errorMessage {
                // Error state
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineLimit(3)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // Loading/placeholder state
                VStack(alignment: .center, spacing: 8) {
                    ProgressView()
                        .tint(.blue)

                    Text("Loading events...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(deepLinkURL)
        .widgetBackground()
    }

    // Event card matching FamilyView design - expanded to fill widget edge-to-edge
    private func eventCardContent(event: WidgetEventData, member: FamilyMemberData) -> some View {
        let resolvedUIColor = UIColor(hex: event.colorHex, fallback: UIColor(hex: member.colorHex))
        let barColor = Color(resolvedUIColor)
        let barWidth: CGFloat = 10
        let (statusText, statusColor) = getEventStatus(event)
        let dayOfWeek = Self.dayOfWeekFormatter.string(from: event.startDate)
        let dateStr = Self.dateFormatter.string(from: event.startDate)
        let timeRange = timeRangeFormatter(startDate: event.startDate, endDate: event.endDate)

        return ZStack(alignment: .topLeading) {
            // Card background - fills entire widget
            Color(UIColor.secondarySystemBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Card content
            HStack(alignment: .top, spacing: 0) {
                // Left side bar
                barColor
                    .frame(width: barWidth)

                VStack(alignment: .leading, spacing: 6) {
                    // Member name
                    Text(member.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Event title
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    // Day name and date
                    Text("\(dayOfWeek), \(dateStr)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    // Time on its own line with time of day indicator
                    HStack(spacing: 4) {
                        let timeOfDay = timeOfDaySymbol(for: event.startDate)
                        Image(systemName: timeOfDay.symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(timeOfDay.color)
                        Text(timeRange)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    // Status
                    Text(statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) {
            if let bubble = timeBubble(for: event) {
                Text(bubble.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(bubble.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bubble.background)
                    .clipShape(Capsule())
                    .padding(10)
            }
        }
        .edgesIgnoringSafeArea(.all) // Ensure it ignores safe area if needed for full bleed
    }

    private func getEventStatus(_ event: WidgetEventData) -> (status: String, color: Color) {
        let now = Date()

        // Check if event is in progress
        if event.startDate <= now && now < event.endDate {
            return ("In Progress", .orange)
        }

        // Check if event is upcoming soon (within 1 hour)
        let oneHourFromNow = now.addingTimeInterval(3600)
        if event.startDate > now && event.startDate <= oneHourFromNow {
            return ("Starting Soon", Color(red: 0.33, green: 0.33, blue: 0.33))
        }

        // Default to upcoming
        return ("Upcoming", .gray)
    }

    private func timeBubble(for event: WidgetEventData) -> (text: String, background: Color, foreground: Color)? {
        let now = Date()
        let calendar = Calendar.current

        if now < event.startDate {
            let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: event.startDate)
            guard let text = bubbleText(from: components) else { return nil }
            let color = Color.blue
            return (text, color.opacity(0.16), color)
        } else if now < event.endDate {
            let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: event.endDate)
            guard let text = bubbleText(from: components) else { return nil }
            let color = Color.green
            return (text, color.opacity(0.16), color)
        }

        return nil
    }

    private func bubbleText(from components: DateComponents) -> String? {
        if let days = components.day, days > 0 {
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    private func timeRangeFormatter(startDate: Date, endDate: Date) -> String {
        let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter
        }()

        let start = timeFormatter.string(from: startDate)
        let end = timeFormatter.string(from: endDate)
        return "\(start) – \(end)"
    }

    private func timeOfDaySymbol(for date: Date) -> (symbol: String, color: Color) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        if hour >= 5 && hour < 12 {
            return ("sunrise.fill", .orange)
        } else if hour >= 12 && hour < 18 {
            return ("sun.max.fill", .yellow)
        } else {
            return ("moon.stars.fill", .indigo)
        }
    }

    /// Generate deep link to event (to be handled by main app)
    private var deepLinkURL: URL? {
        guard let event = entry.event, let member = entry.familyMember else { return nil }
        var components = URLComponents(string: "famli://event")
        components?.queryItems = [
            URLQueryItem(name: "title", value: event.title),
            URLQueryItem(name: "date", value: ISO8601DateFormatter().string(from: event.startDate)),
            URLQueryItem(name: "memberId", value: member.id.uuidString)
        ]
        return components?.url
    }
}

/// Status badge showing event state
struct StatusBadge: View {
    let event: WidgetEventData

    var statusText: String {
        let now = Date()
        if event.startDate <= now && now < event.endDate {
            return "In Progress"
        } else if event.startDate.timeIntervalSince(now) <= 3600 {
            return "Soon"
        } else {
            return "Upcoming"
        }
    }

    var statusColor: Color {
        let now = Date()
        if event.startDate <= now && now < event.endDate {
            return .red
        } else if event.startDate.timeIntervalSince(now) <= 3600 {
            return .orange
        } else {
            return .blue
        }
    }

    var body: some View {
        Text(statusText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
}

/// Extension to generate initials from member name
extension FamilyMemberData {
    var initials: String {
        let parts = name.split(separator: " ").map(String.init)
        let result = parts.prefix(2).map { $0.first.map(String.init) ?? "" }.joined()
        return result.isEmpty ? "?" : result.uppercased()
    }
}

/// Extension to create UIColor from hex string
extension UIColor {
    convenience init(hex: String, fallback: UIColor = UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1)) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else {
            self.init(cgColor: fallback.cgColor)
            return
        }

        let r, g, b, a: CGFloat
        switch cleaned.count {
        case 6:
            r = CGFloat((value & 0xFF0000) >> 16) / 255.0
            g = CGFloat((value & 0x00FF00) >> 8) / 255.0
            b = CGFloat(value & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            // Expect RRGGBBAA
            r = CGFloat((value & 0xFF000000) >> 24) / 255.0
            g = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((value & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(value & 0x000000FF) / 255.0
        default:
            // Fallback for unexpected lengths
            self.init(cgColor: fallback.cgColor)
            return
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

/// View extension for rounded corners on specific edges
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// Shape for rounding specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    /// Apply a system-matching widget background on iOS 17+ and a plain background on earlier OS versions.
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                Color(UIColor.systemBackground)
            }
        } else {
            background(Color(UIColor.systemBackground))
        }
    }
}

#Preview("Next Event") {
    let mockEvent = WidgetEventData(
        title: "Team Meeting",
        startDate: Date(timeIntervalSinceNow: 1800),
        endDate: Date(timeIntervalSinceNow: 5400),
        location: "Conference Room A",
        colorHex: "#007AFF"
    )

    let mockMember = FamilyMemberData(
        id: UUID(),
        name: "John Doe",
        colorHex: "#007AFF"
    )

    let entry = NextEventEntry(date: Date(), event: mockEvent, familyMember: mockMember)

    NextEventWidgetView(entry: entry)
        .preferredColorScheme(.light)
}

#Preview("Loading") {
    let entry = NextEventEntry(date: Date())
    NextEventWidgetView(entry: entry)
}

#Preview("Error") {
    let entry = NextEventEntry(date: Date(), errorMessage: "No upcoming events")
    NextEventWidgetView(entry: entry)
}

#Preview("Login Required") {
    let entry = NextEventEntry(date: Date(), isAuthenticated: false)
    NextEventWidgetView(entry: entry)
}
