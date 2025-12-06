//
//  SharedCalendarsView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData

struct SharedCalendarsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @State private var showingAddSharedCalendar = false
    @State private var calendarPendingDelete: SharedCalendar?
    @State private var showingDeleteConfirmation = false
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    private var reachedFreeLimit: Bool {
        !appSettingsManager.isProUser && sharedCalendars.count >= appSettingsManager.maxSharedCalendarsAllowed
    }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Shared Calendars Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shared Calendars")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 16)

                        if sharedCalendars.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(secondaryTextColor)

                                Text("No shared calendars")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                                    .foregroundColor(primaryTextColor)

                                Text("Add calendars to share with all family members")
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
                                ForEach(sharedCalendars, id: \.self) { calendar in
                                    CalendarRow(
                                        title: calendar.calendarName ?? "Unknown",
                                        subtitle: "Shared with all",
                                        colorHex: calendar.calendarColorHex ?? "#007AFF",
                                        onDelete: {
                                            calendarPendingDelete = calendar
                                            showingDeleteConfirmation = true
                                        }
                                    )

                                    if calendar.id != sharedCalendars.last?.id {
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

                        Button(action: { showingAddSharedCalendar = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(reachedFreeLimit ? secondaryTextColor : theme.accentColor)

                                Text("Add Shared Calendar")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(reachedFreeLimit ? secondaryTextColor : theme.accentColor)

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
                                if reachedFreeLimit {
                                    Text("Pro")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(theme.accentColor)
                                        .clipShape(Capsule())
                                        .offset(x: -6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .disabled(reachedFreeLimit)
                        .opacity(reachedFreeLimit ? 0.6 : 1.0)
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Shared Calendars")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSharedCalendar) {
            AddSharedCalendarView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(dataManager)
                .environmentObject(appSettingsManager)
        }
        .alert("Delete Shared Calendar?", isPresented: $showingDeleteConfirmation, presenting: calendarPendingDelete) { calendar in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSharedCalendar(calendar)
            }
        } message: { calendar in
            Text("Are you sure you want to delete \(calendar.calendarName ?? "this calendar")?")
        }
    }

    private func deleteSharedCalendar(_ calendar: SharedCalendar) {
        guard let id = calendar.id else {
            print("❌ Cannot delete shared calendar: missing ID")
            return
        }

        // First, delete from CoreData immediately for UI responsiveness
        viewContext.delete(calendar)
        do {
            try viewContext.save()
            print("✅ Shared calendar deleted from CoreData")
        } catch {
            print("❌ Failed to save CoreData deletion: \(error)")
            return
        }

        // Then, delete from Supabase asynchronously
        Task {
            do {
                try await dataManager.deleteSharedCalendar(id: id.uuidString)
                print("✅ Shared calendar deleted from Supabase")
            } catch {
                print("❌ Failed to delete shared calendar in Supabase: \(error)")
                // If Supabase deletion fails, the calendar is already deleted locally
                // On next sync/refresh, it may reappear if still in Supabase
            }
        }
    }
}

// MARK: - CalendarRow View

struct CalendarRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: String
    let subtitle: String
    let colorHex: String
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.fromHex(colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(themeManager.selectedTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(themeManager.selectedTheme.textSecondary)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    SharedCalendarsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
