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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

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
    @State private var showSharingPrompt = false
    @State private var newlyCreatedCalendarName: String?

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: []
    )
    private var familyMembers: FetchedResults<FamilyMember>

    private var isAtFamilyLimit: Bool {
        !appSettingsManager.isProUser && familyMembers.count >= appSettingsManager.maxFamilyMembersAllowed
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

                    Text("Enter a name that matches an existing calendar. If no match is found after 2 seconds, you'll be offered the option to create a new calendar.")
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
                // Fixed header
                VStack(spacing: 0) {
                    calendarLinkingBanner

                    if isAtFamilyLimit {
                        limitBanner
                    }
                }

                // Scrollable form content
                ScrollView {
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
                        let memberExists = familyMembers.contains(where: { $0.name?.lowercased() == name.lowercased() })

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

                                    Text(memberExists ? "Will be linked to \(name) if not already added" : "This calendar will be linked to \(name)")
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
                        let memberExists = familyMembers.contains(where: { $0.name?.lowercased() == name.lowercased() })

                        // Only show "no calendar found" if member doesn't already exist
                        if !memberExists {
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: { saveMember() }) {
                        let memberExists = familyMembers.contains(where: { $0.name?.lowercased() == name.lowercased() })
                        let buttonText = memberExists && matchedCalendar != nil ? "Link Calendar" : "Add Member"

                        Text(buttonText)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background((name.isEmpty || isAtFamilyLimit) ? Color.gray : Color(red: 0.33, green: 0.33, blue: 0.33))
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty || isAtFamilyLimit)

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
        .sheet(isPresented: $showSharingPrompt) {
            sharingGuideSheet
        }
    }

    private var sharingGuideSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with icon
                VStack(spacing: 16) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))

                    VStack(spacing: 8) {
                        Text("Share Calendar with Family")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.primary)

                        Text("You've created '\(newlyCreatedCalendarName ?? "")' calendar. Share it with family members to keep everyone in sync.")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Steps
                        VStack(alignment: .leading, spacing: 16) {
                            stepCard(number: "1", title: "Open Calendar Settings", description: "Tap 'Configure Sharing' to open Calendar app")
                            stepCard(number: "2", title: "Find Your Calendar", description: "Locate '\(newlyCreatedCalendarName ?? "")' in the calendar list")
                            stepCard(number: "3", title: "Enable iCloud Sharing", description: "Tap 'Edit' and toggle iCloud sharing on")
                            stepCard(number: "4", title: "Add Family Members", description: "Tap 'Add Person' to invite family via email")
                        }

                        // Info box
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pro Tip")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Calendar sharing requires iCloud accounts. Everyone will see real-time updates.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.systemBlue).opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: configureCalendarSharing) {
                        Text("Configure Sharing")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.33, green: 0.33, blue: 0.33))
                            .cornerRadius(12)
                    }

                    Button(action: { showSharingPrompt = false }) {
                        Text("Do It Later")
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
                    Text("Share Calendar")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                }
            }
        }
    }

    private func stepCard(number: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            // Step number badge
            Text(number)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color(red: 0.33, green: 0.33, blue: 0.33))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func configureCalendarSharing() {
        // Close the sharing prompt and open iOS Settings to Calendar app settings
        print("🔵 configureCalendarSharing() called")
        showSharingPrompt = false

        // Open Settings app to Calendar section for iCloud sharing configuration
        // This is the most reliable way to access calendar sharing settings
        if let url = URL(string: "App-Prefs:root=CALENDAR") {
            UIApplication.shared.open(url) { success in
                if success {
                    print("✅ Opened Settings > Calendar")
                } else {
                    print("⚠️ Failed to open Settings > Calendar, trying fallback")
                    // Fallback: Try settings URL string
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                        print("✅ Opened App Settings")
                    }
                }
            }
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

        // Check if member already exists - if so, skip calendar creation flow
        let memberExists = familyMembers.contains(where: { $0.name?.lowercased() == name.lowercased() })

        // Start timer only when no calendar is found AND member doesn't exist
        if matchedCalendar == nil && !memberExists {
            noCalendarTimer?.invalidate()
            pendingCalendarName = name
            noCalendarTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                showCreateCalendarAlert = true
            }
        } else {
            // Calendar found or member exists, cancel any pending timer
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
        let userId = authManager.userId
        
        Task { @MainActor in
            do {
                print("📝 saveMember() called")
                guard !isAtFamilyLimit else {
                    saveError = "FamCal Free supports up to 2 family members. Enable Pro in Settings > Test Only to add more."
                    showSaveError = true
                    return
                }

                // Check if member already exists
                if let existingMember = familyMembers.first(where: { $0.name?.lowercased() == memberName.lowercased() }) {
                    // Member exists - update driver status and add calendar if matched and not already linked
                    existingMember.isDriver = memberIsDriver
                    existingMember.modifiedAt = Date() // Mark for sync

                    var calendarAdded = false
                    if let matched = matched {
                        // Check if this calendar is already linked to the member
                        let existingCalendarIds = (existingMember.memberCalendars as? Set<FamilyMemberCalendar> ?? [])
                            .compactMap { $0.calendarID }

                        if !existingCalendarIds.contains(matched.id) {
                            // Calendar not linked yet - add it locally
                            let calendar = FamilyMemberCalendar(context: viewContext)
                            calendar.id = UUID()
                            calendar.calendarID = matched.id
                            calendar.calendarName = matched.title
                            calendar.calendarColorHex = matched.color.hex()
                            calendar.isAutoLinked = true
                            existingMember.addToMemberCalendars(calendar)
                            calendarAdded = true
                            print("✅ New calendar linked to existing family member (optimistic)")
                        }
                    }

                    // Save local changes
                    try viewContext.save()
                    print("✅ Family member '\(memberName)' updated locally")
                    
                    // Dismiss UI immediately
                    dismiss()
                    
                    // Capture ID for background task
                    let existingMemberId = existingMember.id?.uuidString

                    // Background Sync
                    Task.detached {
                        if !isGuest {
                            // Trigger sync of pending changes (updates member details)
                            await dataManager.fetchUserDataIfNeeded(force: false)
                            
                            // Handle calendar linking explicitly since pending sync doesn't cover it yet
                            if calendarAdded, let matched = matched, let memberId = existingMemberId {
                                try? await dataManager.supabaseManager.addFamilyMemberCalendar(
                                    memberId: memberId,
                                    calendarName: matched.title,
                                    calendarColorHex: matched.color.hex(),
                                    isAutoLinked: true
                                )
                                // Refresh to confirm
                                await dataManager.fetchUserDataIfNeeded(force: true)
                            }
                        }
                    }
                    return
                }

                let colorHex = getRandomColor().toHex()

                // New Member Flow
                // 1. Create locally
                let newMember = try dataManager.createFamilyMemberLocal(name: memberName, colorHex: colorHex)
                newMember.isDriver = memberIsDriver
                
                // 2. Link calendar locally
                if let matched = matched {
                    let calendar = FamilyMemberCalendar(context: viewContext)
                    calendar.id = UUID()
                    calendar.calendarID = matched.id
                    calendar.calendarName = matched.title
                    calendar.calendarColorHex = matched.color.hex()
                    calendar.isAutoLinked = true
                    newMember.addToMemberCalendars(calendar)
                }
                
                try viewContext.save()
                print("✅ Family member '\(memberName)' created locally (optimistic)")
                
                // 3. Dismiss UI immediately
                dismiss()
                
                // 4. Background Sync
                if !isGuest, let userId = userId, let memberId = newMember.id {
                    Task.detached {
                        do {
                            // Create on Supabase with same ID
                            _ = try await dataManager.supabaseManager.createFamilyMember(
                                userId: userId,
                                name: memberName,
                                colorHex: colorHex,
                                id: memberId
                            )
                            
                            // Update driver status
                            if memberIsDriver {
                                try await dataManager.supabaseManager.updateFamilyMemberDriver(
                                    memberId: memberId.uuidString,
                                    isDriver: true
                                )
                            }
                            
                            // Add calendar
                            if let matched = matched {
                                try await dataManager.supabaseManager.addFamilyMemberCalendar(
                                    memberId: memberId.uuidString,
                                    calendarName: matched.title,
                                    calendarColorHex: matched.color.hex(),
                                    isAutoLinked: true
                                )
                            }
                            
                            // Final sync to ensure consistency
                            await dataManager.fetchUserDataIfNeeded(force: true)
                        } catch {
                            print("❌ Background sync failed for new member: \(error)")
                            // Note: Local data remains. Retry logic would be handled by SyncMetadataManager in future app launches
                        }
                    }
                }
                
            } catch {
                saveError = "Failed to save family member: \(error.localizedDescription)"
                showSaveError = true
                print("❌ Error saving member '\(memberName)': \(error)")
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
    
    private var limitBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text("FamCal Free limit reached")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("Add up to 2 family members on Free. Enable Pro in Settings > Test Only to keep adding.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.16, green: 0.5, blue: 0.95))
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
                newlyCreatedCalendarName = calendarName
                pendingCalendarName = nil
                showSharingPrompt = true
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
        .environmentObject(AppSettingsManager())
        .environmentObject(SupabaseDataManager.shared)
        .environmentObject(SupabaseAuthManager.shared)
}
