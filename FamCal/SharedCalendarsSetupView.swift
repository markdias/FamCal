//
//  SharedCalendarsSetupView.swift
//  FamCal
//
//  Third screen: User selects shared calendars for the family
//

import SwiftUI
import CoreData
import EventKit

struct SharedCalendarsSetupView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Binding var sharedCalendars: [SharedCalendar]
    var onNext: () -> Void
    var onBack: () -> Void

    @State private var availableCalendars: [AvailableCalendar] = []
    @State private var isLoadingCalendars = false
    @State private var selectedCalendarIds: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Shared Calendars")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)

                Text("Select calendars everyone in the family can see")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Calendars List - Takes up remaining space
            if isLoadingCalendars {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading calendars...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
            } else if availableCalendars.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("No calendars available")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)

                    Text("You can add shared calendars later in settings")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableCalendars, id: \.id) { calendar in
                            CalendarSelectionRow(
                                calendar: calendar,
                                isSelected: selectedCalendarIds.contains(calendar.id),
                                isDisabled: !selectedCalendarIds.contains(calendar.id) && selectedCalendarIds.count >= 1,
                                onToggle: {
                                    if selectedCalendarIds.contains(calendar.id) {
                                        selectedCalendarIds.remove(calendar.id)
                                    } else if selectedCalendarIds.count < 1 {
                                        selectedCalendarIds.insert(calendar.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // Info text
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)

                    Text("Shared calendars will be visible to all family members")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.blue)

                    Spacer()
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Free plan restriction notice
            if selectedCalendarIds.count >= 1 {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)

                        Text("Free plan limited to 1 shared calendar")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.orange)

                        Spacer()
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Navigation Buttons
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                Button(action: saveAndContinue) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .onAppear {
            loadAvailableCalendars()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    private func loadAvailableCalendars() {
        isLoadingCalendars = true
        DispatchQueue.global(qos: .userInitiated).async {
            let calendars = CalendarManager.shared.fetchAvailableCalendars()
            DispatchQueue.main.async {
                availableCalendars = calendars
                isLoadingCalendars = false
            }
        }
    }

    private func saveAndContinue() {
        do {
            // Create SharedCalendar entities for selected calendars
            for calendarId in selectedCalendarIds {
                if let calendar = availableCalendars.first(where: { $0.id == calendarId }) {
                    // Check if already exists
                    let fetchRequest: NSFetchRequest<SharedCalendar> = SharedCalendar.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "calendarID == %@", calendarId)
                    let existing = try viewContext.fetch(fetchRequest)

                    if existing.isEmpty {
                        let sharedCalendar = SharedCalendar(context: viewContext)
                        sharedCalendar.id = UUID()
                        sharedCalendar.calendarID = calendarId
                        sharedCalendar.calendarName = calendar.title
                        sharedCalendar.calendarColorHex = calendar.color.hex()
                        sharedCalendars.append(sharedCalendar)
                    }
                }
            }

            try viewContext.save()
            print("✅ Shared calendars saved: \(selectedCalendarIds.count)")
            onNext()
        } catch {
            errorMessage = "Failed to save calendars. Please try again."
            print("❌ Error saving shared calendars: \(error)")
        }
    }
}

// MARK: - Calendar Selection Row

struct CalendarSelectionRow: View {
    let calendar: AvailableCalendar
    let isSelected: Bool
    var isDisabled: Bool = false
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            Circle()
                .fill(Color(uiColor: calendar.color))
                .frame(width: 16, height: 16)
                .opacity(isDisabled ? 0.5 : 1)

            // Calendar info
            VStack(alignment: .leading, spacing: 4) {
                Text(calendar.title)
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(isDisabled ? 0.5 : 1)

                if !calendar.sourceTitle.isEmpty {
                    Text(calendar.sourceTitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                        .opacity(isDisabled ? 0.5 : 1)
                }
            }

            Spacer()

            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isDisabled ? .gray.opacity(0.5) : (isSelected ? .green : .gray))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: isDisabled ? {} : onToggle)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

#Preview {
    SharedCalendarsSetupView(
        sharedCalendars: .constant([]),
        onNext: {},
        onBack: {}
    )
}
