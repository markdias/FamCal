//
//  NextEventWidget.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 17.0, *)
struct NextEventWidget: Widget {
    let kind: String = "NextEventWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NextEventConfigurationIntent.self, provider: NextEventProvider()) { entry in
            NextEventWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Family Event")
        .description("Shows the next upcoming event for your family or a specific member")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    NextEventWidget()
} timeline: {
    let mockEvent = WidgetEventData(
        title: "Team Meeting",
        startDate: Date(timeIntervalSinceNow: 1800),
        endDate: Date(timeIntervalSinceNow: 5400),
        location: "Conference Room A",
        colorHex: "#007AFF",
        checklistCompleted: 2,
        checklistTotal: 5
    )

    let mockMember = FamilyMemberData(
        id: UUID(),
        name: "John Doe",
        colorHex: "#007AFF"
    )

    NextEventEntry(date: Date(), event: mockEvent, familyMember: mockMember)
}
