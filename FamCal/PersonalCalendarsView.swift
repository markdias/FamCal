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

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        if personalCalendars.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 48))
                                    .foregroundColor(secondaryTextColor)

                                Text("No personal calendars")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                                    .foregroundColor(primaryTextColor)

                                Text("Add calendars for your eyes only")
                                    .font(.system(size: 14, weight: .regular, design: .default))
                                    .foregroundColor(secondaryTextColor)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(personalCalendars, id: \.self) { calendar in
                                    CalendarRow(
                                        title: calendar.calendarName ?? "Unknown",
                                        subtitle: "Personal only",
                                        colorHex: calendar.calendarColorHex ?? "#007AFF",
                                        onDelete: {
                                            calendarPendingDelete = calendar
                                            showingDeleteConfirmation = true
                                        }
                                    )

                                    if calendar.id != personalCalendars.last?.id {
                                        Divider()
                                            .padding(.horizontal, 16)
                                    }
                                }
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

                        Button(action: { showingAddPersonalCalendar = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.accentColor)

                                Text("Add Personal Calendar")
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
                    }

                    Spacer()
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
}

#Preview {
    PersonalCalendarsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
