//
//  AddFamilyMemberView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct AddFamilyMemberView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var authManager: SupabaseAuthManager

    @State private var name = ""
    @State private var isDriver = false
    @State private var availableCalendars: [AvailableCalendar] = []
    @State private var matchedCalendar: AvailableCalendar? = nil
    @State private var isLoading = false
    @State private var noCalendarTimer: Timer?
    @State private var showCreateCalendarAlert = false
    @State private var pendingCalendarName: String?
    @State private var saveError: String?
    @State private var showSaveError = false

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
                        .lineLimit(nil)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBlue).opacity(0.1))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                calendarLinkingBanner

                // Form content
                VStack(spacing: 24) {
                    // Name input
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

                    // Driver toggle
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

                    // Calendar preview
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar Match")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(uiColor: matched.color))
                                    .frame(width: 12, height: 12)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(matched.title)
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
                    } else if !name.isEmpty {
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: saveMember) {
                        Text("Add Member")
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Family Member")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                }
            }
        }
        .onAppear {
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
        .alert("Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "An unknown error occurred")
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
        Task {
            do {
                // Check if member already exists
                if dataManager.familyMembers.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                    saveError = "A family member named '\(name)' already exists"
                    showSaveError = true
                    return
                }

                let colorHex = getRandomColor().toHex()

                // Use local-only method for guests, Supabase sync for authenticated users
                if authManager.isGuest {
                    let newMember = try dataManager.createFamilyMemberLocal(name: name, colorHex: colorHex)

                    // If a calendar was matched, add it to the member locally
                    if let matched = matchedCalendar {
                        let calendar = FamilyMemberCalendar(context: viewContext)
                        calendar.id = UUID()
                        calendar.calendarID = matched.id
                        calendar.calendarName = matched.title
                        calendar.calendarColorHex = matched.color.hex()
                        calendar.isAutoLinked = true
                        newMember.addToMemberCalendars(calendar)

                        try viewContext.save()
                        print("✅ Calendar linked to family member (guest mode)")
                    }
                } else {
                    _ = try await dataManager.createFamilyMember(name: name, colorHex: colorHex)

                    // If a calendar was matched, add it to the member
                    if let matched = matchedCalendar,
                       let newMember = dataManager.familyMembers.first(where: { $0.name == name }) {
                        try await dataManager.supabaseManager.addFamilyMemberCalendar(
                            memberId: newMember.id,
                            calendarId: matched.id,
                            calendarName: matched.title,
                            calendarColorHex: matched.color.hex(),
                            isAutoLinked: true
                        )
                        print("✅ Calendar linked to family member")

                        // Refresh data to sync the newly added calendar
                        await dataManager.fetchUserData()
                    }
                }

                print("✅ Family member '\(name)' saved successfully")
                dismiss()
            } catch {
                saveError = "Failed to save family member: \(error.localizedDescription)"
                showSaveError = true
                print("❌ Error saving member '\(name)': \(error)")
            }
        }
    }

    private func getRandomColor() -> Color {
        Color.familyColors.randomElement() ?? Color(red: 0.33, green: 0.33, blue: 0.33)
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
}

#Preview {
    AddFamilyMemberView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
