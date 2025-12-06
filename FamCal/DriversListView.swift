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
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Drivers Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Drivers")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(primaryTextColor)
                                .padding(.horizontal, 16)

                            if drivers.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(secondaryTextColor)

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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(theme.cardStroke, lineWidth: 1)
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(drivers.enumerated()), id: \.element.id) { index, driver in
                                        driverRow(for: driver)

                                        if index < drivers.count - 1 {
                                            Divider()
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
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

                            Button(action: { showingAddDriver = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(theme.accentColor)

                                    Text("Add Driver")
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
                        // Pro gating handled in App Settings; data layer still enforces access
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
            Text("Are you sure you want to delete \(driver.name ?? "this driver")? This cannot be undone.")
        }
    }

    private func driverRow(for driver: Driver) -> some View {
        Menu {
            Button(action: { editingDriver = driver }) {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive, action: {
                driverPendingDelete = driver
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash.fill")
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "car.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(driver.name ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)

                    if let phone = driver.phone, !phone.isEmpty {
                        Text(phone)
                            .font(.system(size: 13))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondaryTextColor.opacity(0.6))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
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
