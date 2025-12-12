//
//  RecurrenceIconPreview.swift
//  FamCal
//
//  Preview of different recurrence icon options at 11pt
//

import SwiftUI

struct RecurrenceIconPreview: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("Recurrence Icon Options (11pt)")
                .font(.headline)
                .padding()

            VStack(alignment: .leading, spacing: 20) {
                // Option 1: repeat
                HStack(spacing: 12) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("repeat")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Simple repeat symbol")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Option 2: repeat.circle
                HStack(spacing: 12) {
                    Image(systemName: "repeat.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    VStack(alignment: .leading) {
                        Text("repeat.circle")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Repeat with circle background")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Option 3: arrow.triangle.2.circlepath
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("arrow.triangle.2.circlepath")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Refresh/cycle arrows")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Option 4: repeat.1
                HStack(spacing: 12) {
                    Image(systemName: "repeat.1")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("repeat.1")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Repeat one (less common but interesting)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Option 5: calendar.badge.clock
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text("calendar.badge.clock")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Calendar with clock indicator")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding()

            Divider()

            Text("Usage Examples (How they'll appear in event cards)")
                .font(.headline)
                .padding()

            VStack(spacing: 12) {
                // Example 1: Event with recurrence
                HStack(spacing: 6) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Text("Team Meeting")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "repeat")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }
                        Text("Today at 2:00 PM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // Example 2: Event without recurrence
                HStack(spacing: 6) {
                    VStack(alignment: .leading) {
                        Text("Doctor Appointment")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Tomorrow at 3:00 PM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                // Example 3: Another recurring event with different color
                HStack(spacing: 6) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Text("Yoga Class")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "repeat")
                                .font(.system(size: 11))
                                .foregroundColor(.purple)
                        }
                        Text("Wednesday at 6:00 PM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()

            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

struct RecurrenceIconPreview_Previews: PreviewProvider {
    static var previews: some View {
        RecurrenceIconPreview()
    }
}
