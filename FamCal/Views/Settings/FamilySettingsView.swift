//
//  FamilySettingsView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData

struct FamilySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authManager: SupabaseAuthManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    private let supabaseManager = SupabaseManager.shared

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FamilyMember.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)
        ]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @State private var activeSheet: ActiveSheet? = nil
    @State private var memberPendingDelete: FamilyMember? = nil
    @State private var showingDeleteConfirmation = false
    @State private var memberPendingUnlink: FamilyMember? = nil
    @State private var showingUnlinkConfirmation = false
    @State private var inviteEmail: String = ""
    @State private var selectedInviteMember: FamilyMember?
    @State private var isSendingInvite = false
    @State private var inviteMessage: String?
    @State private var familyName: String = ""
    @State private var isUpdatingFamilyName = false
    @State private var familyNameMessage: String?
    @State private var isOwner: Bool = false
    @State private var familyId: String?
    @State private var isEditingFamilyName = false

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    private var isAtFamilyLimit: Bool {
        !appSettingsManager.isProUser && familyMembers.count >= appSettingsManager.maxFamilyMembersAllowed
    }

    /// Members eligible for invitation (no linked email/user yet)
    private var availableInviteMembers: [FamilyMember] {
        familyMembers.filter { member in
            guard let id = member.id else { return false }
            return dataManager.memberLinkedEmails[id] == nil
        }
    }

    private enum ActiveSheet: Identifiable {
        case addMember
        case editMember(FamilyMember)
        case selectCalendars(FamilyMember)
        case spotlight(FamilyMember)

        var id: String {
            switch self {
            case .addMember:
                return "addMember"
            case .editMember(let member),
                 .selectCalendars(let member),
                 .spotlight(let member):
                return member.objectID.uriRepresentation().absoluteString
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // MARK: - Family Name Section
                        familyNameCard

                        // MARK: - Family Members Section
                        if familyMembers.isEmpty {
                            emptyStateView
                        } else {
                            VStack(spacing: 8) {
                                ForEach(familyMembers, id: \.objectID) { member in
                                    memberCard(member)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Add Button Section
                        addMemberButton
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        if isAtFamilyLimit {
                            Text("Add up to 2 family members on Free. Enable FamCal Pro in Settings to keep adding.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.accentColor)
                                .padding(.horizontal, 16)
                        }

                        // MARK: - Invite Section
                        inviteCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        Spacer()
                            .frame(height: 16)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Family")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addMember:
                AddFamilyMemberView()
                    .environment(\.managedObjectContext, viewContext)
            case .editMember(let member):
                EditFamilyMemberView(member: member)
                    .environment(\.managedObjectContext, viewContext)
            case .selectCalendars(let member):
                SelectMemberCalendarsView(member: member)
                    .environment(\.managedObjectContext, viewContext)
            case .spotlight(let member):
                SpotlightView(member: member)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .alert("Delete Member?", isPresented: $showingDeleteConfirmation, presenting: memberPendingDelete) { member in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMember(member)
            }
        } message: { member in
            Text("Are you sure you want to delete \(member.name ?? "this member")? This cannot be undone.")
        }
        .alert("Unlink Account?", isPresented: $showingUnlinkConfirmation, presenting: memberPendingUnlink) { member in
            Button("Cancel", role: .cancel) { }
            Button("Unlink", role: .destructive) {
                unlinkMember(member)
            }
        } message: { member in
            Text("Are you sure you want to unlink the account from \(member.name ?? "this member")? The member will remain in your family, but the linked account will be removed. You can link a different account to this member later.")
        }
            .onAppear {
                loadFamilyName()
            }
    }

    private func deleteMember(_ member: FamilyMember) {
        let memberId = member.id?.uuidString
        
        // 1. Optimistic Local Deletion
        viewContext.delete(member)
        
        do {
            try viewContext.save()
            print("✅ Family member deleted locally (optimistic)")
        } catch {
            print("❌ Error deleting local member: \(error)")
            return
        }
        
        // 2. Background Sync
        if let id = memberId, !authManager.isGuest {
            Task.detached {
                do {
                    try await SupabaseDataManager.shared.deleteFamilyMember(id: id)
                    print("✅ Family member deleted from Supabase")
                } catch {
                    print("❌ Error deleting family member from Supabase: \(error)")
                }
            }
        }
    }

    private func unlinkMember(_ member: FamilyMember) {
        let memberId = member.id?.uuidString
        let memberName = member.name
        
        // 1. Optimistic Local Update
        member.linkedUserId = nil
        
        do {
            try viewContext.save()
            print("✅ Account unlinked locally (optimistic)")
            memberPendingUnlink = nil
        } catch {
            print("❌ Error unlinking local member: \(error)")
            return
        }
        
        // 2. Background Sync
        if let id = memberId, !authManager.isGuest {
            Task.detached {
                do {
                    try await SupabaseManager.shared.unlinkSpecificMember(memberId: id)
                    print("✅ Account unlinked from family member \(memberName ?? "Unknown") in Supabase")
                    // No need to fetch, local is accurate
                } catch {
                    print("❌ Error unlinking member in Supabase: \(error)")
                }
            }
        }
    }

    private func toggleDriverStatus(for member: FamilyMember) {
        let newStatus = !member.isDriver
        let memberId = member.id?.uuidString
        let memberName = member.name
        
        // 1. Optimistic Local Update
        member.isDriver = newStatus
        
        do {
            try viewContext.save()
            print("✅ Driver status updated locally (optimistic) to \(newStatus)")
        } catch {
            print("❌ Error updating local driver status: \(error)")
            return
        }
        
        // 2. Background Sync
        if let id = memberId, !authManager.isGuest {
            Task.detached {
                do {
                    try await SupabaseManager.shared.updateFamilyMemberDriver(memberId: id, isDriver: newStatus)
                    print("✅ Driver status updated to \(newStatus) for \(memberName ?? "Unknown") in Supabase")
                } catch {
                    print("❌ Error updating driver status in Supabase: \(error)")
                }
            }
        }

    }

    private func saveFamilyName() {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            familyNameMessage = "Enter a family name."
            return
        }

        familyName = trimmedName
        isUpdatingFamilyName = true
        familyNameMessage = nil
        
        let currentFamilyId = familyId
        let isOwnerUser = isOwner
        let isGuestUser = authManager.isGuest
        
        Task {
            // 1. Optimistic Local Save
            await persistFamilyNameLocally(trimmedName, familyId: currentFamilyId)
            
            if isGuestUser || currentFamilyId == nil {
                await MainActor.run {
                    familyNameMessage = "Saved locally"
                    isUpdatingFamilyName = false
                }
                return
            }
            
            guard isOwnerUser else {
                await MainActor.run {
                    familyNameMessage = "Only the owner can update the family name."
                    isUpdatingFamilyName = false
                }
                return
            }

            // 2. Background Sync
            if let ownerFamilyId = currentFamilyId {
                Task.detached {
                    do {
                        try await SupabaseManager.shared.updateFamilyName(familyId: ownerFamilyId, name: trimmedName)
                        await MainActor.run {
                            familyNameMessage = "Saved"
                        }
                    } catch {
                        await MainActor.run {
                            familyNameMessage = "Failed to sync: \(error.localizedDescription)"
                        }
                    }
                }
            }
            
            await MainActor.run {
                isUpdatingFamilyName = false
            }
        }
    }

    @MainActor
    private func persistFamilyNameLocally(_ name: String, familyId: String?) async {
        do {
            try FamilyInfoStore.upsert(name: name, familyId: familyId, in: viewContext)
        } catch {
            print("⚠️ Failed to persist family name locally: \(error)")
        }
    }

    private func linkedEmail(for member: FamilyMember) -> String? {
        guard let id = member.id else { return nil }
        // Primary lookup by UUID from Supabase DTOs
        if let email = dataManager.memberLinkedEmails[id] {
            return email
        }
        // Fallback: match by name if IDs are out of sync
        if let name = member.name,
           let dto = dataManager.familyMembers.first(where: { $0.name == name }),
           let dtoUUID = UUID(uuidString: dto.id),
           let email = dataManager.memberLinkedEmails[dtoUUID] {
            return email
        }
        return nil
    }

    private func loadFamilyName() {
        Task {
            await loadFamilyNameLocally()

            guard authManager.isAuthenticated && !authManager.isGuest else { return }

            do {
                if let family = try await supabaseManager.getCurrentFamily() {
                    familyId = family.id
                    let remoteName = family.family_name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? familyName
                    familyName = remoteName
                    isOwner = (family.owner_user_id == authManager.userId)
                    await persistFamilyNameLocally(remoteName, familyId: family.id)
                } else {
                    familyNameMessage = "Family not found."
                }
            } catch {
                familyNameMessage = "Failed to load family name: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func loadFamilyNameLocally() async {
        do {
            if let info = try FamilyInfoStore.fetchFirst(in: viewContext) {
                familyName = info.name ?? familyName
                if familyId == nil {
                    familyId = info.familyId
                }
            }
        } catch {
            print("⚠️ Failed to load family name from CoreData: \(error)")
        }
    }

    private var trimmedFamilyNameInput: String {
        familyName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveFamilyName: Bool {
        !trimmedFamilyNameInput.isEmpty && !isUpdatingFamilyName && (authManager.isGuest || isOwner)
    }

    private func sendInvite() {
        guard !isSendingInvite else { return }
        guard let member = selectedInviteMember, let memberId = member.id else {
            inviteMessage = "Select a member to invite."
            return
        }
        guard !inviteEmail.isEmpty else {
            inviteMessage = "Enter an email address."
            return
        }
        inviteMessage = nil
        isSendingInvite = true

        Task {
            do {
                try await supabaseManager.createFamilyInvitation(familyMemberId: memberId, inviteeEmail: inviteEmail)
                inviteMessage = "Invite sent to \(inviteEmail)"
                inviteEmail = ""
                selectedInviteMember = nil
            } catch {
                inviteMessage = "Failed to send invite: \(error.localizedDescription)"
            }
            isSendingInvite = false
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No family members yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
        .padding(.horizontal, 16)
    }

    // MARK: - View Components

    private var familyNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Family icon
                Image(systemName: "person.3.fill")
                    .font(.system(size: 24))
                    .foregroundColor(theme.accentColor)

                // Family info
                VStack(alignment: .leading, spacing: 4) {
                    if !isEditingFamilyName {
                        // Display mode
                        Text(familyName.isEmpty ? "Family Name" : familyName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(primaryTextColor)
                    }

                    Text("\(familyMembers.count) member\(familyMembers.count != 1 ? "s" : "")")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                }

                Spacer()

                // Edit/Save button
                if !isEditingFamilyName {
                    Button(action: {
                        if authManager.isGuest || isOwner {
                            isEditingFamilyName = true
                        }
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemGray))
                    }
                    .buttonStyle(.plain)
                    .disabled(!(authManager.isGuest || isOwner))
                } else {
                    Button(action: {
                        saveFamilyName()
                        isEditingFamilyName = false
                    }) {
                        if isUpdatingFamilyName {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveFamilyName)
                }
            }

            // Edit mode text field
            if isEditingFamilyName {
                TextField("Family Name", text: $familyName)
                    .font(.system(size: 15))
                    .padding(10)
                    .background(theme.backgroundLayer())
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.cardStroke, lineWidth: 1)
                    )
            }

            if let familyNameMessage {
                Text(familyNameMessage)
                    .font(.system(size: 12))
                    .foregroundColor(theme.accentColor)
            }
        }
        .padding(16)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.3 : 0.05), radius: theme.prefersDarkInterface ? 10 : 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func memberCard(_ member: FamilyMember) -> some View {
        HStack(spacing: 12) {
            // Member color circle
            if let firstCalendar = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first {
                Circle()
                    .fill(Color.fromHex(firstCalendar.calendarColorHex ?? "#007AFF"))
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(Color.fromHex(member.colorHex ?? "#007AFF"))
                    .frame(width: 12, height: 12)
            }

            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)

                // Linked calendars count
                let calendarCount = (member.memberCalendars?.count ?? 0)
                Text("\(calendarCount) linked calendar\(calendarCount != 1 ? "s" : "")")
                    .font(.system(size: 12))
                    .foregroundColor(secondaryTextColor)

                // Linked email (if account is linked)
                if let email = linkedEmail(for: member) {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundColor(theme.accentColor)
                }
            }

            Spacer()

            // Non-linked members: Edit, Driver, Calendar, Bin
            // Linked members: Clickable Padlock (unlink), Driver, Calendar, Red disabled Bin

            if member.linkedUserId == nil {
                // Non-linked member icons

                // 1. Edit button
                Button(action: {
                    activeSheet = .editMember(member)
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.systemGray))
                }
                .buttonStyle(.plain)

                // 2. Driver status toggle
                Button(action: {
                    toggleDriverStatus(for: member)
                }) {
                    Image(systemName: member.isDriver ? "car.fill" : "car")
                        .font(.system(size: 16))
                        .foregroundColor(member.isDriver ? .green : .red)
                }
                .buttonStyle(.plain)

                // 3. Calendar button
                Button(action: {
                    activeSheet = .selectCalendars(member)
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.systemGray))
                }
                .buttonStyle(.plain)

                // 4. Delete button
                Button(action: {
                    memberPendingDelete = member
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.systemGray))
                }
                .buttonStyle(.plain)
            } else {
                // Linked member icons

                // 1. Clickable Padlock (to unlink)
                Button(action: {
                    memberPendingUnlink = member
                    showingUnlinkConfirmation = true
                }) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)

                // 2. Driver status toggle
                Button(action: {
                    toggleDriverStatus(for: member)
                }) {
                    Image(systemName: member.isDriver ? "car.fill" : "car")
                        .font(.system(size: 16))
                        .foregroundColor(member.isDriver ? .green : .red)
                }
                .buttonStyle(.plain)

                // 3. Calendar button
                Button(action: {
                    activeSheet = .selectCalendars(member)
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.systemGray))
                }
                .buttonStyle(.plain)

                // 4. Red disabled bin
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.3 : 0.05), radius: theme.prefersDarkInterface ? 10 : 4, x: 0, y: 2)
    }

    private var addMemberButton: some View {
        Button(action: { activeSheet = .addMember }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isAtFamilyLimit ? secondaryTextColor : theme.accentColor)

                Text("Add Family Member")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isAtFamilyLimit ? secondaryTextColor : theme.accentColor)

                Spacer()

                if isAtFamilyLimit {
                    Text("Pro")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(isAtFamilyLimit ? secondaryTextColor.opacity(0.4) : theme.accentColor.opacity(0.4))
            )
        }
        .disabled(isAtFamilyLimit)
        .opacity(isAtFamilyLimit ? 0.6 : 1.0)
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(spacing: 10) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentColor)

                Text("Invite Family Member")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(primaryTextColor)

                Spacer()
            }

            // Member picker - full width
            Picker("", selection: $selectedInviteMember) {
                Text("Select Member").tag(Optional<FamilyMember>.none)
                ForEach(availableInviteMembers, id: \.self) { member in
                    Text(member.name ?? "Member").tag(Optional(member))
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.backgroundLayer())
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )

            // Email and send button row
            HStack(spacing: 8) {
                // Email input
                TextField("Email address", text: $inviteEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .font(.system(size: 14))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(theme.backgroundLayer())
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.cardStroke, lineWidth: 1)
                    )

                // Send button
                Button(action: sendInvite) {
                    if isSendingInvite {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                    }
                }
                .frame(width: 40, height: 40)
                .background(
                    (isSendingInvite || selectedInviteMember == nil || inviteEmail.isEmpty)
                        ? Color.gray.opacity(0.3)
                        : theme.accentColor
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(isSendingInvite || selectedInviteMember == nil || inviteEmail.isEmpty)
            }

            // Status message
            if let inviteMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accentColor)

                    Text(inviteMessage)
                        .font(.system(size: 12))
                        .foregroundColor(theme.accentColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(14)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.3 : 0.05), radius: theme.prefersDarkInterface ? 10 : 4, x: 0, y: 2)
    }

    private func settingsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
        .padding(.horizontal, 16)
    }
}

#Preview {
    FamilySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
        .environmentObject(AppSettingsManager())
        .environmentObject(SupabaseDataManager.shared)
        .environmentObject(SupabaseAuthManager.shared)
}
