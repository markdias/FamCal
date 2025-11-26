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
    @State private var inviteEmail: String = ""
    @State private var selectedInviteMember: FamilyMember?
    @State private var isSendingInvite = false
    @State private var inviteMessage: String?
    @State private var familyName: String = ""
    @State private var isUpdatingFamilyName = false
    @State private var familyNameMessage: String?
    @State private var isOwner: Bool = false
    @State private var familyId: String?
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    private var isAtFamilyLimit: Bool {
        !appSettingsManager.isProUser && familyMembers.count >= appSettingsManager.maxFamilyMembersAllowed
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
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Family Members Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Family Members")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            if familyMembers.isEmpty {
                                emptyStateView
                            } else {
                                settingsContainer {
                                    ForEach(Array(familyMembers.enumerated()), id: \.element.id) { index, member in
                                        memberRow(for: member)

                                        if index < familyMembers.count - 1 {
                                            Divider()
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }

                        // MARK: - Add Button Section
                        Button(action: { activeSheet = .addMember }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(isAtFamilyLimit ? secondaryTextColor : theme.accentColor)

                                Text("Add Family Member")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isAtFamilyLimit ? secondaryTextColor : theme.accentColor)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                            .overlay(alignment: .trailing) {
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
                        }
                        .padding(.horizontal, 16)
                        .disabled(isAtFamilyLimit)
                        .opacity(isAtFamilyLimit ? 0.7 : 1.0)
                        if isAtFamilyLimit {
                            Text("Add up to 2 family members on Free. Enable FamCal Pro in Settings to keep adding.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.accentColor)
                                .padding(.horizontal, 16)
                        }

                        // MARK: - Family Name Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Family Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                VStack(alignment: .leading, spacing: 12) {
                                    TextField("e.g. The Dias Family", text: $familyName)
                                        .padding(12)
                                        .background(theme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(theme.cardStroke, lineWidth: 1)
                                        )
                                        .cornerRadius(10)
                                        .disabled(!isOwner)

                                    if let familyNameMessage {
                                        Text(familyNameMessage)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.accentColor)
                                    }

                                    Button(action: saveFamilyName) {
                                        HStack {
                                            if isUpdatingFamilyName { ProgressView() }
                                            Text("Save Family Name")
                                                .font(.system(size: 15, weight: .semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(theme.accentColor)
                                    .disabled(!isOwner || isUpdatingFamilyName || familyName.isEmpty)
                                }
                                .padding(12)
                            }
                        }

                        // MARK: - Invite Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invite to FamCal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            settingsContainer {
                                VStack(alignment: .leading, spacing: 12) {
                                    Picker("Select member", selection: $selectedInviteMember) {
                                        Text("Choose a member").tag(Optional<FamilyMember>.none)
                                        ForEach(familyMembers, id: \.self) { member in
                                            Text(member.name ?? "Member").tag(Optional(member))
                                        }
                                    }
                                    .pickerStyle(.menu)

                                    TextField("Invitee email", text: $inviteEmail)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .padding(12)
                                        .background(theme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(theme.cardStroke, lineWidth: 1)
                                        )
                                        .cornerRadius(10)

                                    if let inviteMessage {
                                        Text(inviteMessage)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.accentColor)
                                    }

                                    Button(action: sendInvite) {
                                        HStack {
                                            if isSendingInvite {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                            }
                                            Text("Send Invite")
                                                .font(.system(size: 15, weight: .semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(theme.accentColor)
                                    .disabled(isSendingInvite || selectedInviteMember == nil || inviteEmail.isEmpty)
                                }
                                .padding(12)
                            }
                        }

                        Spacer()
                            .frame(height: 24)
                    }
                    .padding(.vertical, 24)
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
        .onAppear {
            loadFamilyName()
        }
    }

    private func deleteMember(_ member: FamilyMember) {
        Task {
            do {
                if authManager.isGuest {
                    // Local-only delete for guests
                    try dataManager.deleteFamilyMemberLocal(id: member.id ?? UUID())
                    print("✅ Family member deleted locally (guest mode)")
                } else {
                    // Delete from Supabase for authenticated users
                    if let memberId = member.id?.uuidString {
                        try await dataManager.deleteFamilyMember(id: memberId)
                        print("✅ Family member deleted from Supabase")
                    }
                }

                // Delete from CoreData
                viewContext.delete(member)

                try viewContext.save()
                print("✅ Family member deleted successfully")
            } catch {
                print("❌ Error deleting family member: \(error)")
            }
        }
    }

    private func saveFamilyName() {
        guard let familyId else {
            familyNameMessage = "Family not found."
            return
        }
        guard isOwner else {
            familyNameMessage = "Only the owner can update the family name."
            return
        }
        isUpdatingFamilyName = true
        familyNameMessage = nil
        Task {
            do {
                try await supabaseManager.updateFamilyName(familyId: familyId, name: familyName)
                familyNameMessage = "Saved"
            } catch {
                familyNameMessage = "Failed to save: \(error.localizedDescription)"
            }
            isUpdatingFamilyName = false
        }
    }

    private func linkedEmail(for member: FamilyMember) -> String? {
        guard let id = member.id else { return nil }
        return dataManager.memberLinkedEmails[id]
    }

    private func loadFamilyName() {
        Task {
            do {
                if let family = try await supabaseManager.getCurrentFamily() {
                    familyId = family.id
                    familyName = family.family_name ?? ""
                    isOwner = (family.owner_user_id == authManager.userId)
                } else {
                    familyNameMessage = "Family not found."
                }
            } catch {
                familyNameMessage = "Failed to load family name: \(error.localizedDescription)"
            }
        }
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

    private func memberRow(for member: FamilyMember) -> some View {
        Menu {
            Button(action: {
                activeSheet = .selectCalendars(member)
            }) {
                Label("Edit Calendars", systemImage: "pencil.circle.fill")
            }

            Button(action: {
                activeSheet = .editMember(member)
            }) {
                Label("Edit Member", systemImage: "square.and.pencil")
            }

            Divider()

            Button(role: .destructive, action: {
                memberPendingDelete = member
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash.fill")
            }
        } label: {
            HStack(spacing: 16) {
                if let firstCalendar = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first {
                    Circle()
                        .fill(Color.fromHex(firstCalendar.calendarColorHex ?? "#007AFF"))
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)

                    Text("\((member.memberCalendars?.count) ?? 0) calendar\((member.memberCalendars?.count) ?? 0 != 1 ? "s" : "")")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(secondaryTextColor)
                    if let email = linkedEmail(for: member) {
                        Text(email)
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                    } else {
                        Text("Not linked")
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondaryTextColor.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
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
