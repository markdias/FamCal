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
                VStack(alignment: .leading, spacing: 16) {
                    if sharedCalendars.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 8) {
                            ForEach(sharedCalendars, id: \.objectID) { calendar in
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

    // MARK: - View Components

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(secondaryTextColor.opacity(0.6))

            Text("No shared calendars")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(primaryTextColor)

            Text("Add calendars to share with all family members")
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

    private func calendarCard(_ calendar: SharedCalendar) -> some View {
        HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.fromHex(calendar.calendarColorHex ?? "#007AFF"))
                .frame(width: 4, height: 44)

            // Calendar info
            VStack(alignment: .leading, spacing: 4) {
                Text(calendar.calendarName ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)

                Text("Shared with all")
                    .font(.system(size: 12))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

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
        Button(action: { showingAddSharedCalendar = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(reachedFreeLimit ? secondaryTextColor : theme.accentColor)

                Text("Add Shared Calendar")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(reachedFreeLimit ? secondaryTextColor : theme.accentColor)

                Spacer()

                if reachedFreeLimit {
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
                    .foregroundColor(reachedFreeLimit ? secondaryTextColor.opacity(0.4) : theme.accentColor.opacity(0.4))
            )
        }
        .disabled(reachedFreeLimit)
        .opacity(reachedFreeLimit ? 0.6 : 1.0)
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

#Preview {
    SharedCalendarsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
