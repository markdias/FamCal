//
//  EditFamilyMemberView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct EditFamilyMemberView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let member: FamilyMember

    @State private var name = ""
    @State private var isDriver = false
    @State private var availableCalendars: [AvailableCalendar] = []
    @State private var matchedCalendar: AvailableCalendar? = nil
    @State private var isLoading = false
    @State private var noCalendarTimer: Timer?
    @State private var showCreateCalendarAlert = false
    @State private var pendingCalendarName: String?
    @State private var showDeleteConfirmation = false
    @State private var showDeleteCalendarOption = false

    private var calendarLinkingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar Linking")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.primary)

                    Text("Enter a name that matches an existing calendar. If no match is found after 5 seconds, you'll be offered the option to create a new calendar.")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .lineLimit(4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBlue).opacity(0.1))
    }

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.gray)

            TextField("Enter family member's name", text: $name)
                .font(.system(size: 16, weight: .regular, design: .default))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onChange(of: name) { oldValue, newValue in
                    updateCalendarMatch()
                }
        }
    }

    private var driverToggle: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Can be a driver")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)

                    Text("Allow as event driver")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Toggle("", isOn: $isDriver)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var calendarStatus: some View {
        Group {
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(red: 0.33, green: 0.33, blue: 0.33))

                    Text("Searching for calendar...")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else if let matched = matchedCalendar {
                calendarFound(matched)
            } else if !name.isEmpty {
                calendarNotFound
            }
        }
    }

    private func calendarFound(_ calendar: AvailableCalendar) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar Match")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                Circle()
                    .fill(Color(uiColor: calendar.color))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(.primary)

                    Text("This calendar will be linked to \(name)")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var calendarNotFound: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar Match")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("No calendar found")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(.primary)

                    Text("No calendar matches '\(name)'")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            nameInput
            driverToggle
            calendarStatus
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveMember) {
                Text("Save Changes")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(name.isEmpty ? Color.gray : Color(red: 0.33, green: 0.33, blue: 0.33))
                    .cornerRadius(12)
            }
            .disabled(name.isEmpty)

            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            Button(action: { showDeleteConfirmation = true }) {
                Text("Delete Member")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                calendarLinkingBanner
                formContent
                Spacer()
                actionButtons
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Family Member")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                }
            }
        }
        .onAppear {
            name = member.name ?? ""
            isDriver = member.isDriver
            loadAvailableCalendars()
        }
        .alert("Create Calendar?", isPresented: $showCreateCalendarAlert) {
            Button("Create", action: createCalendar)
            Button("Cancel", role: .cancel) {
                pendingCalendarName = nil
            }
        } message: {
            Text("Would you like to create a calendar named '\(pendingCalendarName ?? "")'?")
        }
        .alert("Delete Member?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showDeleteCalendarOption = true
            }
        } message: {
            Text("Are you sure you want to delete \(member.name ?? "this member")? This action cannot be undone.")
        }
        .confirmationDialog("Delete Calendar?", isPresented: $showDeleteCalendarOption, presenting: matchedCalendar) { calendar in
            Button("Delete Member Only") {
                deleteMember(deleteCalendar: false)
            }
            Button("Delete Member & Calendar", role: .destructive) {
                deleteMember(deleteCalendar: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: { calendar in
            Text("Would you also like to delete the '\(calendar.title)' calendar from your iOS Calendar app?")
        }
    }

    private func loadAvailableCalendars() {
        isLoading = true
        Task { @MainActor in
            let calendars = CalendarManager.shared.fetchAvailableCalendars()
            availableCalendars = calendars
            isLoading = false
            updateCalendarMatch()
        }
    }

    private func updateCalendarMatch() {
        guard !name.isEmpty else {
            matchedCalendar = nil
            noCalendarTimer?.invalidate()
            noCalendarTimer = nil
            return
        }

        matchedCalendar = CalendarManager.shared.findMatchingCalendar(for: name, in: availableCalendars)

        // Start timer only when no calendar is found
        if matchedCalendar == nil {
            noCalendarTimer?.invalidate()
            pendingCalendarName = name
            noCalendarTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                showCreateCalendarAlert = true
            }
        } else {
            // Calendar found, cancel any pending timer
            noCalendarTimer?.invalidate()
            noCalendarTimer = nil
            pendingCalendarName = nil
        }
    }

    private func saveMember() {
        member.name = name
        member.isDriver = isDriver
        member.avatarInitials = getInitials(from: name)
        member.linkedCalendarID = matchedCalendar?.id

        // Handle auto-linked calendar updates
        let autoLinkedCal = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first { $0.isAutoLinked }

        if let matched = matchedCalendar {
            // If the matched calendar is different from the current auto-linked one, update it
            if autoLinkedCal?.calendarID != matched.id {
                // Remove old auto-linked calendar if it exists
                if let oldCal = autoLinkedCal {
                    viewContext.delete(oldCal)
                }

                // Create new auto-linked calendar entry
                let memberCalendar = FamilyMemberCalendar(context: viewContext)
                memberCalendar.id = UUID()
                memberCalendar.calendarID = matched.id
                memberCalendar.calendarName = matched.title
                memberCalendar.calendarColorHex = matched.color.hex()
                memberCalendar.isAutoLinked = true
                memberCalendar.familyMember = member
            }
        } else {
            // No match found, remove auto-linked calendar if it exists
            if let oldCal = autoLinkedCal {
                viewContext.delete(oldCal)
            }
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error saving member: \(nsError), \(nsError.userInfo)")
        }
    }

    private func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].first ?? "?") + String(components[1].first ?? "?")
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    private func createCalendar() {
        guard let calendarName = pendingCalendarName else { return }

        // Show loading state while creating calendar
        isLoading = true

        Task { @MainActor in
            if let newCalendar = CalendarManager.shared.createLocalCalendar(with: calendarName) {
                // Add the newly created calendar to available calendars
                availableCalendars.append(newCalendar)
                // Update match to the newly created calendar
                matchedCalendar = newCalendar
                pendingCalendarName = nil
                print("✅ Calendar successfully created and matched: \(calendarName)")
            } else {
                print("❌ Failed to create calendar: \(calendarName)")
            }
            isLoading = false
        }
    }

    private func deleteMember(deleteCalendar: Bool) {
        // If user wants to delete the calendar too, do it first
        if deleteCalendar, let calendar = matchedCalendar {
            let deleted = CalendarManager.shared.deleteCalendar(withIdentifier: calendar.id)
            if deleted {
                print("✅ Calendar deleted from iOS Calendar app")
            } else {
                print("⚠️ Failed to delete calendar from iOS Calendar app")
            }
        }

        // Delete all associated calendar entries (auto-linked and manually added)
        if let memberCalendars = member.memberCalendars?.allObjects as? [FamilyMemberCalendar] {
            for calendar in memberCalendars {
                viewContext.delete(calendar)
            }
        }

        // Delete shared calendar associations
        if let sharedCalendars = member.sharedCalendars?.allObjects as? [SharedCalendar] {
            for sharedCalendar in sharedCalendars {
                sharedCalendar.removeFromMembers(member)
            }
        }

        // Delete the family member from CoreData
        viewContext.delete(member)

        do {
            try viewContext.save()
            print("✅ Family member deleted successfully")
            dismiss()
        } catch {
            let nsError = error as NSError
            print("❌ Error deleting member: \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let testMember = FamilyMember(context: context)
    testMember.id = UUID()
    testMember.name = "John Doe"
    testMember.colorHex = "#555555"
    testMember.avatarInitials = "JD"

    return EditFamilyMemberView(member: testMember)
        .environment(\.managedObjectContext, context)
}
