//
//  NotificationCalendarSelectionView.swift
//  FamCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import CoreData

struct NotificationCalendarSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: FamilyMember.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)])
    private var familyMembers: FetchedResults<FamilyMember>
    @Binding var selectedCalendars: Set<String>

    var allCalendars: [(id: String, name: String, color: Color)] {
        var calendars: [(String, String, Color)] = []
        var seen = Set<String>()

        for member in familyMembers {
            if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
                for calendar in memberCalendars {
                    guard let calendarID = calendar.calendarID, !seen.contains(calendarID) else { continue }
                    seen.insert(calendarID)

                    let color = Color.fromHex(calendar.calendarColorHex ?? "#007AFF")
                    calendars.append((calendarID, calendar.calendarName ?? "Unknown", color))
                }
            }
        }

        if let sharedCalendars = familyMembers.first?.sharedCalendars as? Set<SharedCalendar> {
            for calendar in sharedCalendars {
                guard let calendarID = calendar.calendarID, !seen.contains(calendarID) else { continue }
                seen.insert(calendarID)

                let color = Color.fromHex(calendar.calendarColorHex ?? "#007AFF")
                calendars.append((calendarID, calendar.calendarName ?? "Unknown", color))
            }
        }

        return calendars.sorted(by: { $0.1 < $1.1 })
    }

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(spacing: 12) {
                        if allCalendars.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)

                                Text("No Calendars")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Add family members or shared calendars to enable notifications")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                        } else {
                            ForEach(allCalendars, id: \.id) { calendar in
                                HStack(spacing: 12) {
                                    // Color Indicator
                                    Circle()
                                        .fill(calendar.color)
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(calendar.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }

                                    Spacer()

                                    Image(systemName: selectedCalendars.contains(calendar.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedCalendars.contains(calendar.id) ? .blue : .gray)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedCalendars.contains(calendar.id) {
                                        selectedCalendars.remove(calendar.id)
                                    } else {
                                        selectedCalendars.insert(calendar.id)
                                    }
                                    NotificationManager.shared.saveSettings()
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Select Calendars")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

#Preview {
    NotificationCalendarSelectionView(selectedCalendars: .constant(Set()))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
