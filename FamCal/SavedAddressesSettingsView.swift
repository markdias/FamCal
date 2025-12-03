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

        Task {
            await dataManager.deleteSavedAddress(id: id)
        }
    }
}

struct AddSavedAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecentSearch.timestamp, ascending: false)]
    )
    private var recentSearches: FetchedResults<RecentSearch>

    @State private var name = ""
    @State private var address = ""
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var isSearching = false
    @FocusState private var isFocused: Bool
    
    // Refinement State
    @State private var showRefinementAlert = false
    @State private var pendingMapItem: MKMapItem?
    @State private var isRefiningSearch = false
    @State private var refiningLocationName = ""
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Form Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(secondaryTextColor)
                                    .padding(.horizontal, 16)

                                TextField("e.g. Home, Work, Gym", text: $name)
                                    .font(.system(size: 16, weight: .regular))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(theme.cardStroke, lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                                    .padding(.horizontal, 16)
                            }

                            // Address Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Address")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(secondaryTextColor)
                                    .padding(.horizontal, 16)

                                TextField(isRefiningSearch ? "Search in \(refiningLocationName)" : "Search address", text: $address)
                                    .font(.system(size: 16, weight: .regular))
                                    .focused($isFocused)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(theme.cardStroke, lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                                    .padding(.horizontal, 16)
                                    .onChange(of: address) { _, newValue in
                                        if !isSearching {
                                            searchCompleter.query = newValue
                                        }
                                    }
                                    .overlay(alignment: .trailing) {
                                        if !address.isEmpty || isRefiningSearch {
                                            Button(action: {
                                                address = ""
                                                if isRefiningSearch {
                                                    isRefiningSearch = false
                                                    refiningLocationName = ""
                                                    searchCompleter.reset()
                                                } else {
                                                    searchCompleter.query = ""
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .padding(.trailing, 28)
                                            }
                                        }
                                    }

                                // Search Results
                                if !searchCompleter.results.isEmpty && !isSearching {
                                    VStack(spacing: 0) {
                                        ForEach(Array(searchCompleter.results.enumerated()), id: \.element.self) { index, result in
                                            Button(action: {
                                                selectLocation(result)
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "mappin.circle.fill")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(.gray)
                                                        .frame(width: 12, height: 12)

                                                   VStack(alignment: .leading, spacing: 2) {
                                                       Text(result.title)
                                                           .font(.system(size: 14, weight: .medium))
                                                            .foregroundColor(primaryTextColor)

                                                       Text(result.subtitle)
                                                           .font(.system(size: 12))
                                                            .foregroundColor(secondaryTextColor)
                                                            .lineLimit(1)
                                                   }

                                                    Spacer()
                                                }
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)

                                            if index < searchCompleter.results.count - 1 {
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
                               
                                // Recent Searches
                                if searchCompleter.results.isEmpty && !recentSearches.isEmpty && !isSearching {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Recent Searches")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(secondaryTextColor)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)
                                        
                                        VStack(spacing: 0) {
                                            ForEach(Array(recentSearches.prefix(5).enumerated()), id: \.element.self) { index, recent in
                                                Button(action: {
                                                    selectRecentSearch(recent)
                                                }) {
                                                    HStack(spacing: 12) {
                                                        Image(systemName: "clock.fill")
                                                            .font(.system(size: 16))
                                                            .foregroundColor(.gray)
                                                            .frame(width: 12, height: 12)
                                                        
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(recent.query ?? "Unknown")
                                                                .font(.system(size: 14, weight: .medium))
                                                                .foregroundColor(primaryTextColor)
                                                            
                                                            if let address = recent.address, !address.isEmpty {
                                                                Text(address)
                                                                    .font(.system(size: 12))
                                                                    .foregroundColor(secondaryTextColor)
                                                                    .lineLimit(1)
                                                            }
                                                        }
                                                        
                                                        Spacer()
                                                    }
                                                    .padding(.vertical, 12)
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                
                                                if index < min(recentSearches.count, 5) - 1 {
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
                                }
                           }
                       }

                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                    }

                    Button(action: { saveAddress() }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isFormValid ? theme.accentFillStyle() : AnyShapeStyle(Color.gray.opacity(0.5)))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                    }
                    .disabled(!isFormValid)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
            .background(theme.backgroundLayer())
        }
        .alert("Location Found", isPresented: $showRefinementAlert) {
            Button("Search in this area") {
                if let mapItem = pendingMapItem {
                    startRefinedSearch(in: mapItem)
                }
            }
            Button("Use as is") {
                if let mapItem = pendingMapItem {
                    saveMapItem(mapItem, fallbackTitle: mapItem.name ?? "", fallbackSubtitle: "")
                }
            }
            Button("Cancel", role: .cancel) {
                pendingMapItem = nil
            }
        } message: {
            if let name = pendingMapItem?.name {
                Text("Do you want to use '\(name)' as your location, or search for a specific place nearby?")
            } else {
                Text("Do you want to use this location, or search for a specific place nearby?")
            }
        }
    }

    private func saveAddress() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)

        Task {
            await dataManager.createSavedAddress(
                name: trimmedName,
                address: trimmedAddress,
                latitude: 0,
                longitude: 0
            )

            // Set modifiedAt timestamp for offline change tracking
            do {
                let fetchRequest: NSFetchRequest<SavedAddress> = SavedAddress.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", trimmedName)
                fetchRequest.fetchLimit = 1
                let matches = try viewContext.fetch(fetchRequest)
                if let address = matches.first {
                    address.modifiedAt = Date()
                    try viewContext.save()
                }
            } catch {
                print("❌ Error setting modifiedAt for saved address: \(error)")
            }

            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        searchCompleter.resolve(result: result) { mapItem in
            guard let mapItem = mapItem else {
                // Fallback
                self.setAddress(result.title + ", " + result.subtitle)
                return
            }
            
            // Check for refinement
            if mapItem.placemark.subThoroughfare == nil && !self.isRefiningSearch {
                self.pendingMapItem = mapItem
                self.showRefinementAlert = true
                return
            }
            
            self.saveMapItem(mapItem, fallbackTitle: result.title, fallbackSubtitle: result.subtitle)
        }
    }
    
    private func saveMapItem(_ mapItem: MKMapItem, fallbackTitle: String, fallbackSubtitle: String) {
        let placemark = mapItem.placemark
        let placeName = mapItem.name ?? fallbackTitle
        
        // Auto-populate name if empty
        DispatchQueue.main.async {
            if self.name.isEmpty {
                self.name = placeName
            }
        }
        
        // Construct full address
        var addressComponents: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            addressComponents.append(postalCode)
        }
        if let country = placemark.country {
            addressComponents.append(country)
        }
        
        let fullAddress = addressComponents.joined(separator: ", ")
        var finalAddress = fullAddress.isEmpty ? (fallbackTitle + ", " + fallbackSubtitle) : fullAddress
        
        // Prepend name if not already in address
        if !placeName.isEmpty && !finalAddress.contains(placeName) {
            finalAddress = "\(placeName), \(finalAddress)"
        }
        
        DispatchQueue.main.async {
            self.setAddress(finalAddress)
        }
    }
    
    private func setAddress(_ newAddress: String) {
        isSearching = true
        address = newAddress
        searchCompleter.query = ""
        searchCompleter.results = []
        
        // Use a slight delay to allow the UI to update before re-enabling search trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearching = false
        }
    }
    
    private func startRefinedSearch(in mapItem: MKMapItem) {
        isRefiningSearch = true
        refiningLocationName = mapItem.name ?? "this area"
        
        if let location = mapItem.placemark.location {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            searchCompleter.region = region
        }
        
        address = ""
        searchCompleter.query = ""
        isFocused = true
    }
    
    private func selectRecentSearch(_ recent: RecentSearch) {
        let query = recent.query ?? ""
        let recentAddress = recent.address ?? ""
        
        name = query
        
        // Combine name and address if needed
        if !query.isEmpty && !recentAddress.isEmpty && !recentAddress.contains(query) {
            address = "\(query), \(recentAddress)"
        } else {
            address = recentAddress
        }
        
        // Update timestamp
        recent.timestamp = Date()
        try? viewContext.save()
    }
}
