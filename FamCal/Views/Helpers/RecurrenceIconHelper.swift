//
//  RecurrenceIconHelper.swift
//  FamCal
//
//  Helper for displaying recurrence icons on events
//

import SwiftUI

/// A small recurrence icon that shows when an event repeats
struct RecurrenceIcon: View {
    let color: Color
    var fontSize: CGFloat = 11

    var body: some View {
        Image(systemName: "repeat")
            .font(.system(size: fontSize, weight: .regular))
            .foregroundColor(color)
    }
}

/// Modifier to add recurrence icon to event titles
struct WithRecurrenceIcon: ViewModifier {
    let hasRecurrence: Bool
    let color: Color

    func body(content: Content) -> some View {
        HStack(spacing: 4) {
            content
            if hasRecurrence {
                RecurrenceIcon(color: color)
            }
        }
    }
}

extension View {
    /// Apply recurrence icon styling to event titles
    func withRecurrenceIcon(_ hasRecurrence: Bool, color: Color) -> some View {
        modifier(WithRecurrenceIcon(hasRecurrence: hasRecurrence, color: color))
    }
}
