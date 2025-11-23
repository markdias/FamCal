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
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.results = []
    }
}
