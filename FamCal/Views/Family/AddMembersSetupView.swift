//
//  AddMembersSetupView.swift
//  FamCal
//
//  Second screen: User adds family members and links their calendars
//

import SwiftUI
import CoreData

struct AddMembersSetupView: View {
    @Environment(\.managedObjectContext) var viewContext
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Binding var familyMembers: [FamilyMember]
    var onNext: () -> Void
    var onBack: () -> Void

    @State private var showAddMemberSheet = false
    @State private var errorMessage: String?

    var canProceed: Bool {
        !familyMembers.isEmpty && familyMembers.contains { member in
            guard let calendars = member.memberCalendars as? Set<FamilyMemberCalendar>, !calendars.isEmpty else { return false }
            return true
        }
    }

    var isAddMemberDisabled: Bool {
        !appSettingsManager.isProUser && familyMembers.count >= appSettingsManager.maxFamilyMembersAllowed
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Add Family Members")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)

                Text("Link their calendars as you add them")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Members List
            if familyMembers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("No members yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)

                    Text("Add your first family member to get started")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(familyMembers, id: \.id) { member in
                            MemberRow(member: member, onRemove: {
                                familyMembers.removeAll { $0.id == member.id }
                            })
                        }
                    }
                }
                .frame(maxHeight: 250)
            }

            // Add Member Button
            VStack(spacing: 8) {
                Button(action: { showAddMemberSheet = true }) {
                    Label("Add Member", systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isAddMemberDisabled ? .gray : .blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .disabled(isAddMemberDisabled)

                if isAddMemberDisabled {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text("Free plan limited to \(appSettingsManager.maxFamilyMembersAllowed) family members")
                            .font(.system(size: 12, weight: .regular))
                        Spacer()
                    }
                    .foregroundColor(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            Spacer()

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

                Button(action: onNext) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canProceed ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!canProceed)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showAddMemberSheet) {
            AddFamilyMemberSetupSheet(
                isPresented: $showAddMemberSheet,
                onMemberAdded: { newMember in
                    familyMembers.append(newMember)
                }
            )
            .environment(\.managedObjectContext, viewContext)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: FamilyMember
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            let hexColor = member.colorHex ?? "#007AFF"
            Circle()
                .fill(Color.fromHex(hexColor))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(member.avatarInitials ?? "?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name ?? "Unknown")
                    .font(.system(size: 14, weight: .semibold))

                if let calendarCount = member.memberCalendars?.count, calendarCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("\(calendarCount) calendar\(calendarCount == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("No calendar linked")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Add Family Member Setup Sheet Wrapper

struct AddFamilyMemberSetupSheet: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    var onMemberAdded: (FamilyMember) -> Void

    var body: some View {
        AddFamilyMemberViewForSetup(
            isPresented: $isPresented,
            onMemberAdded: onMemberAdded
        )
        .environment(\.managedObjectContext, viewContext)
    }
}

// Simplified version of AddFamilyMemberView for use in setup flow
struct AddFamilyMemberViewForSetup: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    var onMemberAdded: (FamilyMember) -> Void

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

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: []
    )
    private var existingFamilyMembers: FetchedResults<FamilyMember>

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
                        VStack(alignment: .leading, spacing: 12) {
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

                    Button(action: { isPresented = false }) {
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
            Text("Would you like to create a calendar named '\(pendingCalendarName ?? "")'?\n\nAfter creating, you can set up sharing in the Calendar app on your iPhone to allow others to view this calendar.")
        }
        .alert("Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "An unknown error occurred")
        }
    }

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

                    Text("Enter a name that matches an existing calendar.")
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

        if matchedCalendar == nil {
            noCalendarTimer?.invalidate()
            pendingCalendarName = name
            noCalendarTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                showCreateCalendarAlert = true
            }
        } else {
            noCalendarTimer?.invalidate()
            noCalendarTimer = nil
            pendingCalendarName = nil
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

    private func saveMember() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newMember = FamilyMember(context: viewContext)
        newMember.id = UUID()
        newMember.name = trimmedName
        newMember.avatarInitials = generateInitials(from: trimmedName)
        newMember.colorHex = Color.familyColors.first?.toHex() ?? "#007AFF"
        newMember.isDriver = isDriver
        newMember.isInvited = false
        newMember.sortOrder = Int16(existingFamilyMembers.count)

        // Link matched calendar if found
        if let matched = matchedCalendar {
            let calendar = FamilyMemberCalendar(context: viewContext)
            calendar.id = UUID()
            calendar.calendarID = matched.id
            calendar.calendarName = matched.title
            calendar.calendarColorHex = matched.color.hex()
            calendar.isAutoLinked = true
            newMember.addToMemberCalendars(calendar)
        }

        do {
            try viewContext.save()
            onMemberAdded(newMember)
            isPresented = false
            print("✅ Member added in setup: \(trimmedName)")
        } catch {
            saveError = "Failed to save member. Please try again."
            showSaveError = true
            print("❌ Error saving member: \(error)")
        }
    }

    private func generateInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].first ?? "?") + String(components[1].first ?? "?")
        } else if let first = components.first, let firstChar = first.first {
            return String(firstChar)
        }
        return "?"
    }
}

#Preview {
    AddMembersSetupView(
        familyMembers: .constant([]),
        onNext: {},
        onBack: {}
    )
}
