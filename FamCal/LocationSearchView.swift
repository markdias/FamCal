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
                    TextField("Search address or postcode", text: $searchText)
                        .focused($isFocused)
                        .onChange(of: searchText) { _, newValue in
                            searchCompleter.query = newValue
                        }
                        .submitLabel(.search)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchCompleter.query = ""
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
        }
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        // Update bindings
        locationName = result.title
        locationAddress = result.subtitle
        
        // Save to Recent Searches
        let recent = RecentSearch(context: viewContext)
        recent.id = UUID()
        recent.query = result.title
        recent.address = result.subtitle
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
