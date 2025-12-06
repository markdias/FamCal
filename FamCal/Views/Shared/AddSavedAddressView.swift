//
//  AddSavedAddressView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import MapKit
import CoreData
import Combine

struct AddSavedAddressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var dataManager: SupabaseDataManager

    @State private var name: String = ""
    @State private var address: String = ""
    @State private var isSearching = false
    @StateObject private var locationSearcher = LocationSearcher()
    @State private var isRefiningSearch = false
    @State private var refiningLocationName: String = ""
    @State private var pendingMapItem: MKMapItem?
    @State private var showRefinementAlert = false
    @State private var isFocused = false // Tracking focus state

    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                VStack(spacing: 20) {
                    // Search Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        TextField("e.g. Grandma's House", text: $name)
                            .padding()
                            .background(theme.cardBackground)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        TextField("Search address...", text: $address)
                            .padding()
                            .background(theme.cardBackground)
                            .cornerRadius(8)
                            .onChange(of: address) { _, newValue in
                                locationSearcher.searchQuery = newValue
                                isSearching = !newValue.isEmpty
                            }
                    }
                    .padding(.horizontal)

                    if isSearching && !locationSearcher.results.isEmpty {
                        List(locationSearcher.results, id: \.self) { result in
                            Button(action: {
                                selectLocation(result)
                            }) {
                                VStack(alignment: .leading) {
                                    Text(result.title)
                                        .foregroundColor(theme.textPrimary)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAddress() }
                        .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        address = result.title + ", " + result.subtitle
        isSearching = false
        if name.isEmpty {
            name = result.title
        }
    }

    private func saveAddress() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        
        Task { @MainActor in
            // 1. Optimistic Local Creation
            let newAddress = SavedAddress(context: viewContext)
            newAddress.id = UUID()
            newAddress.name = trimmedName
            newAddress.address = trimmedAddress
            newAddress.latitude = 0 // Placeholder
            newAddress.longitude = 0
            newAddress.modifiedAt = Date()
            
            do {
                try viewContext.save()
                print("✅ Saved address '\(trimmedName)' created locally (optimistic)")
                
                // 2. Dismiss UI
                dismiss()
                
                // 3. Background Sync
                if let id = newAddress.id {
                    let idString = id.uuidString
                    Task.detached {
                        // Create on Supabase
                        await dataManager.createSavedAddress(
                            name: trimmedName,
                            address: trimmedAddress,
                            latitude: 0,
                            longitude: 0,
                            id: idString
                        )
                    }
                }
            } catch {
                print("❌ Error saving address locally: \(error)")
            }
        }
    }
}

class LocationSearcher: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.results = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search failed: \(error.localizedDescription)")
    }
}
