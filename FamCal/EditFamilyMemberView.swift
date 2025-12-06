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
    @EnvironmentObject private var authManager: SupabaseAuthManager
    @EnvironmentObject private var dataManager: SupabaseDataManager

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
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var showUnlinkConfirmation = false
    @State private var isUnlinking = false

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
            HStack {
                Text("Name")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.gray)

                if member.linkedUserId != nil {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }

            if member.linkedUserId != nil {
                HStack {
                    Text(name)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
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
            if member.linkedUserId == nil {
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
            }

            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            if member.linkedUserId != nil {
                Button(action: { showUnlinkConfirmation = true }) {
                    Text("Unlink Account")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
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
        .alert("Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "An unknown error occurred")
        }
        .alert("Unlink Account?", isPresented: $showUnlinkConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unlink", role: .destructive) {
                unlinkAccount()
            }
        } message: {
            Text("Are you sure you want to unlink the account from \(member.name ?? "this member")? This action can be reversed by linking a different account later.")
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
        // Capture values for background task
        let memberName = name
        let memberIsDriver = isDriver
        let matched = matchedCalendar
        let isGuest = authManager.isGuest
        let memberId = member.id
        let memberUUIDString = member.id?.uuidString
        
        Task { @MainActor in
            do {
                // 1. Optimistic Local Update
                member.name = memberName
                member.isDriver = memberIsDriver
                member.avatarInitials = getInitials(from: memberName)
                if !isGuest {
                    member.linkedCalendarID = matched?.id
                }
                member.modifiedAt = Date() // Mark for sync
                
                // Handle auto-linked calendar updates locally
                let autoLinkedCal = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first { $0.isAutoLinked }

                if let matched = matched {
                    if autoLinkedCal?.calendarID != matched.id {
                        if let oldCal = autoLinkedCal {
                            viewContext.delete(oldCal)
                        }

                        let memberCalendar = FamilyMemberCalendar(context: viewContext)
                        memberCalendar.id = UUID()
                        memberCalendar.calendarID = matched.id
                        memberCalendar.calendarName = matched.title
                        memberCalendar.calendarColorHex = matched.color.hex()
                        memberCalendar.isAutoLinked = true
                        memberCalendar.familyMember = member
                    }
                } else {
                    if let oldCal = autoLinkedCal {
                        viewContext.delete(oldCal)
                    }
                }

                try viewContext.save()
                print("✅ Family member '\(memberName)' updated locally (optimistic)")
                
                // 2. Dismiss UI immediately
                dismiss()
                
                // Capture colorHex for background task
                let memberColorHex = member.colorHex ?? "#555555"
                
                // 3. Background Sync (if authenticated)
                if !isGuest, let memberId = memberUUIDString {
                    Task.detached {
                        do {
                            // Update in Supabase
                            try await dataManager.supabaseManager.updateFamilyMember(
                                id: memberId, 
                                name: memberName, 
                                colorHex: memberColorHex
                            )

                            // Update driver status
                            try await dataManager.supabaseManager.updateFamilyMemberDriver(
                                memberId: memberId, 
                                isDriver: memberIsDriver
                            )
                            
                            // Handle calendar linking explicitly
                            if let matched = matched {
                                // We can't easily check if it's already linked in Supabase without fetching
                                // But addFamilyMemberCalendar might be idempotent or we can ignore error
                                // For now, let's just trigger a refresh to ensure consistency
                                // Or try to add it?
                                try? await dataManager.supabaseManager.addFamilyMemberCalendar(
                                    memberId: memberId,
                                    calendarName: matched.title,
                                    calendarColorHex: matched.color.hex(),
                                    isAutoLinked: true
                                )
                            }
                            
                            // Final sync to ensure consistency
                            await dataManager.fetchUserDataIfNeeded(force: true)
                        } catch {
                            print("❌ Background sync failed for update member: \(error)")
                        }
                    }
                }
            } catch {
                saveError = "Failed to update family member: \(error.localizedDescription)"
                showSaveError = true
                print("❌ Error updating member '\(memberName)': \(error)")
            }
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
        // Capture values
        let memberId = member.id
        let memberUUIDString = member.id?.uuidString
        let isGuest = authManager.isGuest
        let memberCalendars = member.memberCalendars?.allObjects as? [FamilyMemberCalendar]
        let sharedCalendars = member.sharedCalendars?.allObjects as? [SharedCalendar]
        let calendarToDelete = matchedCalendar
        
        // If user wants to delete the calendar too, do it first (local iOS calendar)
        if deleteCalendar, let calendar = calendarToDelete {
            let deleted = CalendarManager.shared.deleteCalendar(withIdentifier: calendar.id)
            if deleted {
                print("✅ Calendar deleted from iOS Calendar app")
            } else {
                print("⚠️ Failed to delete calendar from iOS Calendar app")
            }
        }

        Task { @MainActor in
            do {
                // 1. Optimistic Local Delete
                // Delete all associated calendar entries (auto-linked and manually added)
                if let memberCalendars = memberCalendars {
                    for calendar in memberCalendars {
                        viewContext.delete(calendar)
                    }
                }

                // Delete shared calendar associations
                if let sharedCalendars = sharedCalendars {
                    for sharedCalendar in sharedCalendars {
                        sharedCalendar.removeFromMembers(member)
                    }
                }

                // Delete the family member from CoreData
                viewContext.delete(member)

                try viewContext.save()
                print("✅ Family member deleted locally (optimistic)")
                
                // 2. Dismiss UI
                dismiss()
                
                // 3. Background Sync
                if !isGuest, let memberId = memberUUIDString {
                    Task.detached {
                        do {
                            try await dataManager.supabaseManager.deleteFamilyMember(id: memberId)
                            print("✅ Family member deleted from Supabase")
                        } catch {
                            print("❌ Background sync failed for delete member: \(error)")
                        }
                    }
                }
            } catch {
                saveError = "Failed to delete family member: \(error.localizedDescription)"
                showSaveError = true
                print("❌ Error deleting member: \(error)")
            }
        }
    }

    private func unlinkAccount() {
        let memberUUIDString = member.id?.uuidString
        let isGuest = authManager.isGuest
        let memberName = member.name
        
        Task { @MainActor in
            do {
                isUnlinking = true

                // 1. Optimistic Local Update
                member.linkedUserId = nil
                try viewContext.save()
                print("✅ Account unlinked from family member locally (optimistic)")
                
                // 2. Dismiss UI
                isUnlinking = false
                dismiss()
                
                // 3. Background Sync
                if !isGuest, let memberId = memberUUIDString {
                    Task.detached {
                        do {
                            try await dataManager.supabaseManager.unlinkSpecificMember(memberId: memberId)
                            print("✅ Account unlinked from family member \(memberName ?? "Unknown") on Supabase")
                            
                            // Refresh data
                            await dataManager.fetchUserDataIfNeeded(force: true)
                        } catch {
                            print("❌ Background sync failed for unlink account: \(error)")
                        }
                    }
                }
            } catch {
                saveError = "Failed to unlink account: \(error.localizedDescription)"
                showSaveError = true
                isUnlinking = false
                print("❌ Error unlinking account: \(error)")
            }
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
