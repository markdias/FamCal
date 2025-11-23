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
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

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
                                    .foregroundColor(theme.accentColor)

                                Text("Add Family Member")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.accentColor)

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
                        }
                        .padding(.horizontal, 16)

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                    }
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
    }

    private func deleteMember(_ member: FamilyMember) {
        // Delete from Supabase first
        if let memberId = member.id?.uuidString {
            Task {
                do {
                    let dataManager = SupabaseDataManager.shared
                    try await dataManager.deleteFamilyMember(id: memberId)
                    print("✅ Family member deleted from Supabase")
                } catch {
                    print("❌ Error deleting family member from Supabase: \(error)")
                }
            }
        }

        // Then delete from CoreData
        viewContext.delete(member)

        do {
            try viewContext.save()
            print("✅ Family member deleted from CoreData")
        } catch {
            let nsError = error as NSError
            print("❌ Error deleting family member: \(nsError), \(nsError.userInfo)")
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
}
