//
//  EventDetailViewRedesigns.swift
//  FamCal
//
//  Created by Claude on 2025-12-09.
//  Design alternatives for EventDetailView (compact option)
//

import SwiftUI
import EventKit

// MARK: - Option 1: Card-Based Compact Design
/// Consolidates information into fewer, denser cards to reduce scrolling
struct EventDetailCompactDesign: View {
    let event: UpcomingCalendarEvent

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Title Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(event.title)
                            .font(.system(size: 22, weight: .semibold))
                        if event.hasRecurrence {
                            RecurrenceIcon(color: .blue, fontSize: 14.0)
                        }
                    }

                    // Date & Time in one compact row
                    HStack(spacing: 16) {
                        Label {
                            Text(formatDate(event.startDate))
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                        }

                        Label {
                            Text("\(formatTime(event.startDate)) – \(formatTime(event.endDate))")
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.subheadline)

                    // Location if exists
                    if let location = event.location, !location.isEmpty {
                        Label {
                            Text(location)
                        } icon: {
                            Image(systemName: "location.fill")
                                .foregroundColor(.red)
                        }
                        .font(.subheadline)
                    }

                    // Recurring event indicator
                    if event.hasRecurrence {
                        Label {
                            Text("Repeats weekly")
                        } icon: {
                            Image(systemName: "repeat")
                                .foregroundColor(.purple)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Quick Actions Card (Calendar, Driver, Alert in one card)
                VStack(spacing: 0) {
                    quickActionRow(icon: "calendar.badge.clock", title: "Calendar", value: event.calendarTitle, color: Color(uiColor: event.calendarColor))
                    Divider().padding(.leading, 44)
                    quickActionRow(icon: "car.fill", title: "Driver", value: "None", color: .gray)
                    Divider().padding(.leading, 44)
                    quickActionRow(icon: "bell.fill", title: "Alert", value: "15 min before", color: .orange)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Checklist Card (if exists)
                checklistCard

                // Linked Calendars (preview data)
                if !linkedCalendarsPreview.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Linked calendars")
                            .font(.subheadline.weight(.semibold))
                        Text("Copies on other family calendars")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(linkedCalendarsPreview) { calendar in
                                calendarChip(calendar)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }

                // Map preview (at bottom, if location exists)
                if let location = event.location, !location.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)

                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                            .overlay(
                                VStack {
                                    Image(systemName: "map.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("Map Preview")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                            .cornerRadius(12)
                    }
                }

                // Actions
                Button("Delete Event") {
                    // Delete action
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func quickActionRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Checklist")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("3/5")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }

            VStack(spacing: 10) {
                checklistItemRow(title: "Buy decorations", due: "Due Jan 10", completed: false)
                checklistItemRow(title: "Send invitations", due: "Due Jan 8", completed: true)
                checklistItemRow(title: "Book venue", due: "Due Jan 12", completed: false)
            }

            Button(action: {}) {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func checklistItemRow(title: String, due: String, completed: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(completed ? .green : .gray)
            Text(title)
                .strikethrough(completed)
                .foregroundColor(completed ? .secondary : .primary)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Text(due)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func calendarChip(_ calendar: LinkedCalendarPreview) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(calendar.color.opacity(0.7))
                .frame(width: 10, height: 10)
            Text(calendar.name)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var linkedCalendarsPreview: [LinkedCalendarPreview] {
        previewLinkedCalendars
    }
}

private struct LinkedCalendarPreview: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
}

private let previewLinkedCalendars: [LinkedCalendarPreview] = [
    .init(name: "Family", color: .blue),
    .init(name: "Parents", color: .green),
    .init(name: "Kids", color: .orange)
]

// MARK: - Preview
#Preview("Compact") {
    EventDetailCompactDesign(
        event: UpcomingCalendarEvent(
            id: "1",
            title: "Team Lunch",
            location: "The Good Fork Restaurant",
            meetingLink: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarID: "cal1",
            calendarColor: UIColor.systemBlue,
            calendarTitle: "Work",
            hasRecurrence: true,
            recurrenceRule: nil,
            travelTimeMinutes: nil,
            isAllDay: false
        )
    )
}
