//
//  PersonalCalendarsView.swift
//  FamCal
//
//  Created by Mark Dias on 26/11/2025.
//

import SwiftUI
import CoreData

struct PersonalCalendarsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: PersonalCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PersonalCalendar.calendarName, ascending: true)]
    )
    private var personalCalendars: FetchedResults<PersonalCalendar>

    @State private var showingAddPersonalCalendar = false
    @State private var calendarPendingDelete: PersonalCalendar?
    @State private var showingDeleteConfirmation = false
    @State private var visibilityState: [NSManagedObjectID: Bool] = [:]

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !personalCalendars.isEmpty {
                        infoNote
                    }

                    if personalCalendars.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 8) {
                            ForEach(personalCalendars, id: \.objectID) { calendar in
                                calendarCard(calendar)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    addCalendarButton
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Personal Calendars")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddPersonalCalendar) {
            AddPersonalCalendarView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(dataManager)
                .environmentObject(appSettingsManager)
        }
        .alert("Delete Personal Calendar?", isPresented: $showingDeleteConfirmation, presenting: calendarPendingDelete) { calendar in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePersonalCalendar(calendar)
            }
        } message: { calendar in
            Text("Are you sure you want to delete \(calendar.calendarName ?? "this calendar")?")
        }
        .onAppear(perform: hydrateVisibilityState)
        .onChange(of: personalCalendars.count) { _, _ in
            hydrateVisibilityState()
        }
    }

    // MARK: - View Components

    private var infoNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(theme.accentColor.opacity(0.8))

            Text("All personal calendars are visible in Calendar view")
                .font(.system(size: 13))
                .foregroundColor(secondaryTextColor)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(theme.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(secondaryTextColor.opacity(0.6))

            Text("No personal calendars")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(primaryTextColor)

            Text("Add calendars for your eyes only")
                .font(.system(size: 14))
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.3 : 0.05), radius: theme.prefersDarkInterface ? 10 : 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func calendarCard(_ calendar: PersonalCalendar) -> some View {
        let isFamilyViewOn = visibilityState[calendar.objectID] ?? (calendar.showInNext || calendar.showInSpotlight || calendar.showInUpcoming)

        return HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.fromHex(calendar.calendarColorHex ?? "#007AFF"))
                .frame(width: 4, height: 44)

            // Calendar info
            VStack(alignment: .leading, spacing: 4) {
                Text(calendar.calendarName ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)

                Text(isFamilyViewOn ? "Family view on" : "Family view off")
                    .font(.system(size: 12))
                    .foregroundColor(isFamilyViewOn ? theme.accentColor : secondaryTextColor)
            }

            Spacer()

            // Family view toggle
            Toggle("", isOn: familyViewBinding(for: calendar))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                .scaleEffect(0.85)

            // Delete button
            Button(action: {
                calendarPendingDelete = calendar
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.systemGray))
            }
            .buttonStyle(.plain)
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

    private var addCalendarButton: some View {
        Button(action: { showingAddPersonalCalendar = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentColor)

                Text("Add Personal Calendar")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.accentColor)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(theme.accentColor.opacity(0.4))
            )
        }
    }

    private func deletePersonalCalendar(_ calendar: PersonalCalendar) {
        guard let id = calendar.id else {
            print("❌ Cannot delete personal calendar: missing ID")
            return
        }

        // First, delete from CoreData immediately for UI responsiveness
        viewContext.delete(calendar)
        do {
            try viewContext.save()
            print("✅ Personal calendar deleted from CoreData")
        } catch {
            print("❌ Failed to save CoreData deletion: \(error)")
            return
        }

        // Then, delete from Supabase asynchronously
        Task {
            do {
                try await dataManager.deletePersonalCalendar(id: id.uuidString)
                print("✅ Personal calendar deleted from Supabase")
            } catch {
                print("❌ Failed to delete personal calendar in Supabase: \(error)")
                // If Supabase deletion fails, the calendar is already deleted locally
                // On next sync/refresh, it may reappear if still in Supabase
            }
        }
    }

    // MARK: - Visibility State

    private func hydrateVisibilityState() {
        for calendar in personalCalendars {
            guard visibilityState[calendar.objectID] == nil else { continue }
            // Determine if family view is enabled (any of the three family flags)
            let familyView = calendar.showInNext || calendar.showInSpotlight || calendar.showInUpcoming
            visibilityState[calendar.objectID] = familyView

            // Always enable calendar views on load
            calendar.showInMonth = true
            calendar.showInDay = true
        }

        // Save initial calendar view state
        try? viewContext.save()
    }

    private func familyViewBinding(for calendar: PersonalCalendar) -> Binding<Bool> {
        Binding(
            get: {
                visibilityState[calendar.objectID] ?? (calendar.showInNext || calendar.showInSpotlight || calendar.showInUpcoming)
            },
            set: { newValue in
                updateFamilyViewVisibility(for: calendar, value: newValue)
            }
        )
    }

    private func updateFamilyViewVisibility(for calendar: PersonalCalendar, value: Bool) {
        visibilityState[calendar.objectID] = value

        // Update CoreData immediately for snappy UI
        // When family view is toggled, set all three family view fields
        calendar.showInNext = value
        calendar.showInSpotlight = value
        calendar.showInUpcoming = value
        // Always keep calendar views enabled
        calendar.showInMonth = true
        calendar.showInDay = true

        do {
            try viewContext.save()
            print("✅ Updated visibility in CoreData: FamilyView=\(value) (CalendarView always true)")
        } catch {
            print("❌ Failed to save visibility locally: \(error)")
        }

        guard let id = calendar.id?.uuidString else {
            print("❌ Cannot update visibility: missing calendar ID")
            return
        }

        Task { @MainActor in
            do {
                try await dataManager.updatePersonalCalendarVisibility(
                    id: id,
                    showInNext: value,
                    showInSpotlight: value,
                    showInUpcoming: value,
                    showInMonth: true,
                    showInDay: true
                )
                print("ℹ️ Updated personal calendar visibility for \(calendar.calendarName ?? id)")

                // Notify views to reload events
                NotificationCenter.default.post(name: Notification.Name("PersonalCalendarVisibilityChanged"), object: nil)
            } catch {
                print("❌ Failed to update visibility in Supabase: \(error)")
            }
        }
    }
}

#Preview {
    PersonalCalendarsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
