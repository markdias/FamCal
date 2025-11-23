//
//  VisibleCalendarsView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct VisibleCalendarsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @State private var showingAddSharedCalendar = false
    @State private var selectedMember: FamilyMember? = nil
    @State private var sharedCalendarPendingDelete: SharedCalendar? = nil
    @State private var showingDeleteConfirmation = false

    var linkedCalendars: [FamilyMember] {
        familyMembers.filter { ($0.memberCalendars?.count ?? 0) > 0 }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Visible Calendars Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Visible Calendars")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            if linkedCalendars.isEmpty && sharedCalendars.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)

                                    Text("No visible calendars")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Add family members or shared calendars to see them here")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 0) {
                                    // Family Member Calendars
                                    ForEach(Array(linkedCalendars.enumerated()), id: \.element.id) { index, member in
                                        memberRow(for: member)

                                        if index < linkedCalendars.count - 1 {
                                            Divider()
                                                .padding(.leading, 56)
                                        }
                                    }

                                    // Shared Calendars
                                    if !sharedCalendars.isEmpty {
                                        if !linkedCalendars.isEmpty {
                                            Divider()
                                                .padding(.leading, 56)
                                        }

                                        ForEach(Array(sharedCalendars.enumerated()), id: \.element.id) { index, calendar in
                                            sharedCalendarRow(for: calendar)

                                            if index < sharedCalendars.count - 1 {
                                                Divider()
                                                    .padding(.leading, 56)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            }

                            Button(action: { showingAddSharedCalendar = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)

                                    Text("Add Shared Calendar")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            .padding(.horizontal, 16)
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
                    Text("Visible Calendars")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSharedCalendar) {
            AddSharedCalendarView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $selectedMember) { member in
            SelectMemberCalendarsView(member: member)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Calendar?", isPresented: $showingDeleteConfirmation, presenting: sharedCalendarPendingDelete) { calendar in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSharedCalendar(calendar)
            }
        } message: { calendar in
            Text("Are you sure you want to remove \(calendar.calendarName ?? "this calendar")? This cannot be undone.")
        }
    }

    private func memberRow(for member: FamilyMember) -> some View {
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
                    .foregroundColor(.primary)

                Text("\((member.memberCalendars?.count) ?? 0) calendar\((member.memberCalendars?.count) ?? 0 != 1 ? "s" : "")")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedMember = member
        }
    }

    private func sharedCalendarRow(for calendar: SharedCalendar) -> some View {
        Menu {
            Button(role: .destructive, action: {
                sharedCalendarPendingDelete = calendar
                showingDeleteConfirmation = true
            }) {
                Label("Remove", systemImage: "trash.fill")
            }
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.fromHex(calendar.calendarColorHex ?? "#007AFF"))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.calendarName ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text("Shared Family Calendar")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }

    private func deleteSharedCalendar(_ calendar: SharedCalendar) {
        viewContext.delete(calendar)

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error deleting shared calendar: \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    VisibleCalendarsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
