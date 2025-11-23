//
//  FamilyEventsWidget.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI

@main
struct FamliCalWidgetsWrapper {
    static func main() {
        if #available(iOS 17.0, *) {
            FamliCalWidgetsModern.main()
        } else {
            FamliCalWidgetsLegacy.main()
        }
    }
}

struct FamliCalWidgetsModern: WidgetBundle {
    var body: some Widget {
        NextEventWidget()
        FamilyEventsWidget()
    }
}

struct FamliCalWidgetsLegacy: WidgetBundle {
    var body: some Widget {
        FamilyEventsWidgetLegacy()
    }
}

@available(iOS 17.0, *)
struct FamilyEventsWidget: Widget {
    let kind: String = "FamilyEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyEventsProvider()) { entry in
            FamilyEventsWidgetView(entry: entry)
        }
        .configurationDisplayName("Family Events")
        .description("See upcoming events for all family members")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct FamilyEventsWidgetLegacy: Widget {
    let kind: String = "FamilyEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyEventsProvider()) { entry in
            FamilyEventsWidgetView(entry: entry)
        }
        .configurationDisplayName("Family Events")
        .description("See upcoming events for all family members")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
