//
//  MapsUtility.swift
//  FamCal
//
//  Created by Mark Dias on 20/11/2025.
//

import UIKit

struct MapsUtility {
    /// Opens a location in the user's preferred maps app
    /// - Parameters:
    ///   - location: The location string to search for
    ///   - preferredApp: The preferred maps app ("Apple Maps", "Google Maps", or "Waze")
    static func openLocation(_ location: String, in preferredApp: String) {
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location

        switch preferredApp {
        case "Google Maps":
            openInGoogleMaps(encodedLocation)
        case "Waze":
            openInWaze(encodedLocation)
        default: // Apple Maps
            openInAppleMaps(encodedLocation)
        }
    }

    private static func openInAppleMaps(_ encodedLocation: String) {
        if let appleURL = URL(string: "maps://?q=\(encodedLocation)") {
            UIApplication.shared.open(appleURL)
        }
    }

    private static func openInGoogleMaps(_ encodedLocation: String) {
        if let googleMapsURL = URL(string: "comgooglemaps://?q=\(encodedLocation)"),
           UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL)
        } else if let webURL = URL(string: "https://maps.google.com/?q=\(encodedLocation)") {
            UIApplication.shared.open(webURL)
        }
    }

    private static func openInWaze(_ encodedLocation: String) {
        if let wazeURL = URL(string: "waze://?q=\(encodedLocation)"),
           UIApplication.shared.canOpenURL(wazeURL) {
            UIApplication.shared.open(wazeURL)
        } else if let webURL = URL(string: "https://www.waze.com/ul?q=\(encodedLocation)") {
            UIApplication.shared.open(webURL)
        }
    }
}
