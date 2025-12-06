//
//  SavedAddressesSettingsView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData
import MapKit

struct SavedAddressesSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedAddress.name, ascending: true)]
    )
    private var savedAddresses: FetchedResults<SavedAddress>

    @State private var showingAddSheet = false
    @State private var addressPendingDelete: SavedAddress? = nil
    @State private var showingDeleteConfirmation = false
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Saved Places Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved Places")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                            .padding(.horizontal, 16)

                        if savedAddresses.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "mappin.slash.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(secondaryTextColor)

                                Text("No saved places")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(primaryTextColor)

                                Text("Add favorite locations for quick access")
                                    .font(.system(size: 14))
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
                                ForEach(Array(savedAddresses.enumerated()), id: \.element.id) { index, address in
                                    addressRow(for: address)

                                    if index < savedAddresses.count - 1 {
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

                        Button(action: { showingAddSheet = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.accentColor)

                                Text("Add Saved Place")
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
        .sheet(isPresented: $showingAddSheet) {
            AddSavedAddressView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(dataManager)
        }
        .alert("Delete Place?", isPresented: $showingDeleteConfirmation, presenting: addressPendingDelete) { address in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAddress(address)
            }
        } message: { address in
            Text("Are you sure you want to delete \(address.name ?? "this place")? This cannot be undone.")
        }
    }

    private func addressRow(for address: SavedAddress) -> some View {
        Menu {
            Button(role: .destructive, action: {
                addressPendingDelete = address
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash.fill")
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.selectedTheme.accentColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(address.name ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)

                    if let addr = address.address, !addr.isEmpty {
                        Text(addr)
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
    
    private func deleteAddress(_ address: SavedAddress) {
        guard let id = address.id else {
            print("❌ Cannot delete saved address: missing ID")
            return
        }
        let idString = id.uuidString

        Task { @MainActor in
            // 1. Optimistic Local Delete
            viewContext.delete(address)
            
            do {
                try viewContext.save()
                print("✅ Saved address deleted locally (optimistic)")
                
                // 2. Background Sync
                Task.detached {
                    await dataManager.deleteSavedAddress(id: idString)
                }
            } catch {
                print("❌ Error deleting address locally: \(error)")
            }
        }
    }
}
