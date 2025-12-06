//
//  LocationSearchCompleter.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import MapKit
import Combine

class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var query: String = "" {
        didSet {
            searchDebounceTimer?.invalidate()
            searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.searchCompleter.queryFragment = self?.query ?? ""
            }
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []
    
    var region: MKCoordinateRegion? {
        didSet {
            if let region = region {
                searchCompleter.region = region
            } else {
                searchCompleter.region = MKCoordinateRegion() // Reset to default
            }
        }
    }

    private let searchCompleter = MKLocalSearchCompleter()
    private var searchDebounceTimer: Timer?

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }

    deinit {
        searchDebounceTimer?.invalidate()
    }
    
    func reset() {
        query = ""
        region = nil
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.results = []
    }
    
    func resolve(result: MKLocalSearchCompletion, completion: @escaping (MKMapItem?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let item = response?.mapItems.first else {
                completion(nil)
                return
            }
            completion(item)
        }
    }
}
