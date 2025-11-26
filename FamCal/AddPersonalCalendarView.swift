//
//  AddPersonalCalendarView.swift
//  FamCal
//
//  Created by Mark Dias on 26/11/2025.
//

import SwiftUI
import CoreData
import EventKit

struct AddPersonalCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: PersonalCalendar.entity(),
        sortDescriptors: []
    )
    private var personalCalendars: FetchedResults<PersonalCalendar>

    @State private var availableCalendars: [AvailableCalendar] = []
    @State private var isLoading = false

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var calendarsBySource: [String: [AvailableCalendar]] {
        Dictionary(grouping: availableCalendars) { $0.sourceTitle }
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { result, pair in
                result[pair.key] = pair.value.sorted { $0.title < $1.title }
            }
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                VStack(spacing: 0) {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(theme.accentColor)

                            Text("Loading calendars...")
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundColor(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if availableCalendars.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 48))
                                .foregroundColor(secondaryTextColor)

                            Text("No calendars available")
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundColor(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(Array(calendarsBySource.keys.sorted()), id: \.self) { sourceTitle in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(sourceTitle)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(secondaryTextColor)
                                            .padding(.horizontal, 16)

                                        VStack(spacing: 0) {
                                            ForEach(Array((calendarsBySource[sourceTitle] ?? []).enumerated()), id: \.element.id) { index, calendar in
                                                let isAlreadyAdded = personalCalendars.contains { $0.calendarName == calendar.title }

                                                Button(action: {
                                                    if isAlreadyAdded {
                                                        removePersonalCalendar(calendar)
                                                    } else {
                                                        addPersonalCalendar(calendar)
                                                    }
                                                }) {
                                                    HStack(spacing: 12) {
                                                        Circle()
                                                            .fill(Color(uiColor: calendar.color))
                                                            .frame(width: 12, height: 12)

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(calendar.title)
                                                                .font(.system(size: 16, weight: .medium, design: .default))
                                                                .foregroundColor(primaryTextColor)
                                                        }

                                                        Spacer()

                                                        if isAlreadyAdded {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 20))
                                                                .foregroundColor(.green)
                                                        } else {
                                                            Image(systemName: "circle")
                                                                .font(.system(size: 20))
                                                                .foregroundColor(secondaryTextColor)
                                                        }
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .contentShape(Rectangle())
                                               }

                                                if index < (calendarsBySource[sourceTitle] ?? []).count - 1 {
                                                    Divider()
                                                        .padding(.leading, 44)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
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

                                Spacer()
                                    .frame(height: 16)
                            }
                            .padding(.vertical, 24)
                        }
                    }

                    VStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.accentColor)

                                Text("Done")
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
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Personal Calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
            }
        }
        .onAppear {
            loadAvailableCalendars()
        }
    }

    private func loadAvailableCalendars() {
        isLoading = true
        Task { @MainActor in
            let calendars = CalendarManager.shared.fetchAvailableCalendars()
            availableCalendars = calendars
            isLoading = false
        }
    }

    private func addPersonalCalendar(_ calendar: AvailableCalendar) {
        // Save to Supabase first
        Task {
            do {
                _ = try await dataManager.addPersonalCalendar(
                    calendarName: calendar.title,
                    calendarColorHex: calendar.color.hex()
                )
                print("✅ Personal calendar saved to Supabase")
            } catch {
                print("❌ Error saving personal calendar: \(error)")
            }
        }
    }

    private func removePersonalCalendar(_ calendar: AvailableCalendar) {
        print("🔍 removePersonalCalendar called for: \(calendar.title)")

        // Find the personal calendar in CoreData
        if let personalCalendar = personalCalendars.first(where: { $0.calendarName == calendar.title }) {
            guard let calendarId = personalCalendar.id?.uuidString else {
                print("❌ Cannot delete: calendar ID not available")
                return
            }

            print("📱 Calendar ID: \(calendarId)")

            // Delete from CoreData first (immediate UI update)
            viewContext.delete(personalCalendar)
            do {
                try viewContext.save()
                print("✅ Personal calendar deleted from CoreData")
            } catch {
                let nsError = error as NSError
                print("❌ Error deleting from CoreData: \(nsError), \(nsError.userInfo)")
                return
            }

            // Then sync deletion to Supabase
            Task {
                print("🌐 Starting Supabase deletion for ID: \(calendarId)")
                do {
                    let userId = dataManager.authManager.userId ?? "unknown"
                    print("📧 User ID for deletion: \(userId)")

                    try await dataManager.deletePersonalCalendar(id: calendarId)
                    print("✅ Personal calendar deleted from Supabase (ID: \(calendarId))")
                } catch {
                    print("❌ Error deleting from Supabase: \(error)")
                    // Note: Calendar is already deleted from CoreData locally
                    // Will be re-synced if Supabase still has it on next fetch
                }
            }
        } else {
            print("⚠️ Could not find personal calendar in CoreData for ID: \(calendar.id)")
        }
    }
}

#Preview {
    AddPersonalCalendarView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
