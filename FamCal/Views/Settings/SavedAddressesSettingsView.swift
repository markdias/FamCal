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
                VStack(alignment: .leading, spacing: 16) {
                    if savedAddresses.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 8) {
                            ForEach(savedAddresses, id: \.objectID) { address in
                                addressCard(address)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    addPlaceButton
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Saved Places")
        .navigationBarTitleDisplayMode(.inline)
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
            Text("Are you sure you want to delete \(address.name ?? "this place")?")
        }
    }

    // MARK: - View Components

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash.circle")
                .font(.system(size: 48))
                .foregroundColor(secondaryTextColor.opacity(0.6))

            Text("No saved places")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(primaryTextColor)

            Text("Add favorite locations for quick access")
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

    private func addressCard(_ address: SavedAddress) -> some View {
        HStack(spacing: 12) {
            // Location icon
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(theme.accentColor)

            // Address info
            VStack(alignment: .leading, spacing: 4) {
                Text(address.name ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)

                if let addr = address.address, !addr.isEmpty {
                    Text(addr)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                } else {
                    Text("No address")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                }
            }

            Spacer()

            // Delete button
            Button(action: {
                addressPendingDelete = address
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

    private var addPlaceButton: some View {
        Button(action: { showingAddSheet = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentColor)

                Text("Add Saved Place")
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
