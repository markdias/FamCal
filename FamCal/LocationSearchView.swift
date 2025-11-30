//
//  LocationSearchView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import MapKit
import CoreData

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @Binding var locationName: String
    @Binding var locationAddress: String
    
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    
    // Refinement State
    @State private var showRefinementAlert = false
    @State private var pendingMapItem: MKMapItem?
    @State private var isRefiningSearch = false
    @State private var refiningLocationName = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedAddress.name, ascending: true)]
    )
    private var savedAddresses: FetchedResults<SavedAddress>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecentSearch.timestamp, ascending: false)]
    )
    private var recentSearches: FetchedResults<RecentSearch>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(isRefiningSearch ? "Search in \(refiningLocationName)" : "Search address or postcode", text: $searchText)
                        .focused($isFocused)
                        .onChange(of: searchText) { _, newValue in
                            searchCompleter.query = newValue
                        }
                        .submitLabel(.search)
                    
                    if !searchText.isEmpty || isRefiningSearch {
                        Button(action: {
                            searchText = ""
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
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                List {
                    if !searchText.isEmpty {
                        // Search Results
                        Section("Results") {
                            ForEach(searchCompleter.results, id: \.self) { result in
                                Button(action: {
                                    selectLocation(result)
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(result.title)
                                            .font(.headline)
                                        Text(result.subtitle)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    } else {
                        // Saved Addresses
                        if !savedAddresses.isEmpty {
                            Section("Saved Places") {
                                ForEach(savedAddresses) { place in
                                    Button(action: {
                                        selectSavedAddress(place)
                                    }) {
                                        HStack {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                            VStack(alignment: .leading) {
                                                Text(place.name ?? "Unknown")
                                                    .font(.headline)
                                                if let address = place.address, !address.isEmpty {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Recent Searches
                        if !recentSearches.isEmpty {
                            Section("Recent Searches") {
                                ForEach(recentSearches.prefix(10), id: \.self) { recent in
                                    Button(action: {
                                        selectRecentSearch(recent)
                                    }) {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.gray)
                                            VStack(alignment: .leading) {
                                                Text(recent.query ?? "Unknown")
                                                    .font(.headline)
                                                if let address = recent.address, !address.isEmpty {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                    }
                                }
                                .onDelete(perform: deleteRecentSearches)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
            .alert("Location Found", isPresented: $showRefinementAlert) {
                Button("Search in this area") {
                    if let mapItem = pendingMapItem {
                        startRefinedSearch(in: mapItem)
                    }
                }
                Button("Use as is") {
                    if let mapItem = pendingMapItem {
                        // Use the fallback title/subtitle from the original result if needed, 
                        // but here we can just use the mapItem's name/address since we have it.
                        // We'll reconstruct the fallback strings from the mapItem for simplicity
                        // or pass empty strings since saveMapItem prioritizes mapItem content.
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
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        searchCompleter.resolve(result: result) { mapItem in
            guard let mapItem = mapItem else {
                // Fallback to completion results if resolution fails
                self.saveLocation(name: result.title, address: result.subtitle)
                return
            }
            
            // Check if address is "broad" (missing house number)
            // We only offer refinement if we are NOT already refining
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
        let name = placemark.name ?? fallbackTitle
        
        // Construct full address from components
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
        let finalAddress = fullAddress.isEmpty ? fallbackSubtitle : fullAddress
        
        DispatchQueue.main.async {
            self.saveLocation(name: name, address: finalAddress)
        }
    }
    
    private func startRefinedSearch(in mapItem: MKMapItem) {
        isRefiningSearch = true
        refiningLocationName = mapItem.name ?? "this area"
        
        // Set region to the selected location
        if let location = mapItem.placemark.location {
            // Create a small region around the point
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            searchCompleter.region = region
        }
        
        // Clear current search text to let user type new query
        searchText = ""
        searchCompleter.query = ""
        
        // Focus back on search field
        isFocused = true
    }
    
    private func saveLocation(name: String, address: String) {
        // Update bindings
        locationName = name
        locationAddress = address
        
        // Save to Recent Searches
        let recent = RecentSearch(context: viewContext)
        recent.id = UUID()
        recent.query = name
        recent.address = address
        recent.timestamp = Date()
        
        saveContext()
        dismiss()
    }
    
    private func selectSavedAddress(_ place: SavedAddress) {
        locationName = place.name ?? ""
        locationAddress = place.address ?? ""
        dismiss()
    }
    
    private func selectRecentSearch(_ recent: RecentSearch) {
        locationName = recent.query ?? ""
        locationAddress = recent.address ?? ""
        
        // Update timestamp
        recent.timestamp = Date()
        saveContext()
        dismiss()
    }
    
    private func deleteRecentSearches(offsets: IndexSet) {
        withAnimation {
            offsets.map { recentSearches[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
