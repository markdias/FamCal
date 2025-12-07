//
//  DriversListView.swift
//  FamCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI
import CoreData

struct DriversListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager

    @FetchRequest(entity: Driver.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Driver.name, ascending: true)])
    private var drivers: FetchedResults<Driver>

    @State private var showingAddDriver = false
    @State private var driverPendingDelete: Driver? = nil
    @State private var showingDeleteConfirmation = false
    @State private var editingDriver: Driver? = nil
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if drivers.isEmpty {
                            emptyStateView
                        } else {
                            VStack(spacing: 8) {
                                ForEach(drivers, id: \.objectID) { driver in
                                    driverCard(driver)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        addDriverButton
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Drivers")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
            }
        }
        .sheet(isPresented: $showingAddDriver) {
            AddDriverView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(dataManager)
        }
        .sheet(item: $editingDriver) { driver in
            NavigationStack {
                EditDriverView(driver: driver)
            }
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(dataManager)
        }
        .alert("Delete Driver?", isPresented: $showingDeleteConfirmation, presenting: driverPendingDelete) { driver in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteDriver(driver)
            }
        } message: { driver in
            Text("Are you sure you want to delete \(driver.name ?? "this driver")?")
        }
    }

    // MARK: - View Components

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundColor(secondaryTextColor.opacity(0.6))

            Text("No Drivers")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(primaryTextColor)

            Text("Add drivers to manage who can drive to events")
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

    private func driverCard(_ driver: Driver) -> some View {
        HStack(spacing: 12) {
            // Driver icon
            Image(systemName: "person.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(theme.accentColor)

            // Driver info
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)

                if let phone = driver.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                } else {
                    Text("No phone number")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                }
            }

            Spacer()

            // Edit button
            Button(action: {
                editingDriver = driver
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.systemGray))
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: {
                driverPendingDelete = driver
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

    private var addDriverButton: some View {
        Button(action: { showingAddDriver = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentColor)

                Text("Add Driver")
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

    private func deleteDriver(_ driver: Driver) {
        guard let id = driver.id else {
            print("❌ Cannot delete driver: missing ID")
            return
        }

        Task {
            await dataManager.deleteDriver(id: id.uuidString)
        }
    }

}

#Preview {
    DriversListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
        .environmentObject(SupabaseDataManager.shared)
}
