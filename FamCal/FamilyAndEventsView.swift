//
//  FamilyAndEventsView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData

struct FamilyAndEventsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

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

    @State private var showingAddMember = false
    @State private var editingMember: FamilyMember? = nil
    @State private var spotlightMember: FamilyMember? = nil
    @State private var expandedMember: FamilyMember? = nil
    @State private var selectedMember: FamilyMember? = nil
    @State private var showingAddSharedCalendar = false
    @State private var navigationSelection: String? = nil

    private var linkedCalendars: [FamilyMember] {
        familyMembers.filter { ($0.memberCalendars?.count ?? 0) > 0 }
    }
    private var isAtFamilyLimit: Bool {
        !appSettingsManager.isProUser && familyMembers.count >= appSettingsManager.maxFamilyMembersAllowed
    }

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Family Members Section
                        familyMembersSection

                        // MARK: - Submenu Items
                        VStack(spacing: 12) {
                            NavigationLink(destination: DriversListView().environment(\.managedObjectContext, viewContext)) {
                                SettingsMenuRow(
                                    iconName: "car.fill",
                                    iconColor: Color.orange,
                                    title: "Drivers",
                                    subtitle: "Manage drivers for events"
                                )
                            }

                            NavigationLink(destination: EventPreferencesView()) {
                                SettingsMenuRow(
                                    iconName: "calendar.badge.clock",
                                    iconColor: Color.blue,
                                    title: "Event Preferences",
                                    subtitle: "Display and alert settings"
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : Color(red: 0.33, green: 0.33, blue: 0.33))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMember) {
            AddFamilyMemberView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editingMember) { member in
            EditFamilyMemberView(member: member)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $spotlightMember) { member in
            SpotlightView(member: member)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddSharedCalendar) {
            AddSharedCalendarView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(dataManager)
                .environmentObject(appSettingsManager)
        }
        .sheet(item: $selectedMember) { member in
            SelectMemberCalendarsView(member: member)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Family Members Section
    private var familyMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Members")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                .padding(.horizontal, 16)

            if familyMembers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)

                    Text("No family members yet")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .glassyCard(padding: 0)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(linkedCalendars, id: \.self) { member in
                        VStack(spacing: 0) {
                            // Member row (clickable to expand)
                            Button(action: {
                                withAnimation {
                                    if expandedMember?.id == member.id {
                                        expandedMember = nil
                                    } else {
                                        expandedMember = member
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
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
                                            .font(.system(size: 16, weight: .semibold, design: .default))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)

                                            Text("\((member.memberCalendars?.count) ?? 0) calendar\((member.memberCalendars?.count) ?? 0 != 1 ? "s" : "")")
                                                .font(.system(size: 12, weight: .regular, design: .default))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: expandedMember?.id == member.id ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // Expanded content - Calendars
                            if expandedMember?.id == member.id, let memberCals = member.memberCalendars?.allObjects as? [FamilyMemberCalendar] {
                                let sortedCals = memberCals.sorted { ($0.isAutoLinked && !$1.isAutoLinked) || ($0.isAutoLinked == $1.isAutoLinked && ($0.calendarName ?? "") < ($1.calendarName ?? "")) }

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                VStack(spacing: 0) {
                                    ForEach(sortedCals, id: \.self) { cal in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color.fromHex(cal.calendarColorHex ?? "#007AFF"))
                                                .frame(width: 8, height: 8)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(cal.calendarName ?? "Unknown")
                                                    .font(.system(size: 14, weight: .regular))
                                                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)
                                            }

                                            Spacer()

                                            if cal.isAutoLinked {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .opacity(cal.isAutoLinked ? 0.6 : 1.0)

                                        if cal.id != sortedCals.last?.id {
                                            Divider()
                                                .padding(.horizontal, 16)
                                                .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)
                                        }
                                    }
                                }

                                // Edit button in expanded section
                                Button(action: { selectedMember = member }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 16))

                                        Text("Select Calendars")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)

                                // Shared calendars in expanded view
                                if !sharedCalendars.isEmpty {
                                    Divider()
                                        .padding(.horizontal, 16)
                                        .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                    VStack(spacing: 0) {
                                        ForEach(sharedCalendars, id: \.self) { calendar in
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(Color.fromHex(calendar.calendarColorHex ?? "#007AFF"))
                                                    .frame(width: 8, height: 8)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(calendar.calendarName ?? "Unknown")
                                                        .font(.system(size: 14, weight: .regular))
                                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                                    Text("Shared")
                                                        .font(.system(size: 11, weight: .regular))
                                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                                }

                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .opacity(0.7)

                                            if calendar.id != sharedCalendars.last?.id {
                                                Divider()
                                                    .padding(.horizontal, 16)
                                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)
                                            }
                                        }
                                    }

                                    Button(action: { showingAddSharedCalendar = true }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 16))

                                            Text("Add Shared Calendar")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if member.id != linkedCalendars.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)
                            }
                        }
                    }
                }
                .glassyCard(padding: 0)
                .padding(.horizontal, 16)
            }

            Button(action: { showingAddMember = true }) {
                Text("Add Family Member")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentFillStyle() : AnyShapeStyle(Color(red: 0.33, green: 0.33, blue: 0.33)))
                    .cornerRadius(12)
                    .shadow(color: themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 16)
            .disabled(isAtFamilyLimit)
            .opacity(isAtFamilyLimit ? 0.6 : 1.0)
            if isAtFamilyLimit {
                Text("Add up to 2 family members on Free. Enable FamCal Pro in Settings to keep adding.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.accentColor)
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Settings Menu Row
private struct SettingsMenuRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(iconColor)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
        }
        .glassyCard(padding: 0)
    }
}

#Preview {
    FamilyAndEventsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
        .environmentObject(AppSettingsManager())
        .environmentObject(SupabaseDataManager.shared)
}
