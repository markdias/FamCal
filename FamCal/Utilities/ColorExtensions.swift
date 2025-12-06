//
//  ColorExtensions.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import UIKit

extension UIColor {
    func hex() -> String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#555555"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// Helper function to create UIColor from hex string
func UIColorFromHex(_ hexString: String) -> UIColor {
    let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    let scanner = Scanner(string: hex)
    var value: UInt64 = 0
    scanner.scanHexInt64(&value)

    let r = CGFloat((value >> 16) & 0xFF) / 255.0
    let g = CGFloat((value >> 8) & 0xFF) / 255.0
    let b = CGFloat(value & 0xFF) / 255.0

    return UIColor(red: r, green: g, blue: b, alpha: 1.0)
}

extension Color {
    static let familyColors: [Color] = [
        Color(red: 0.33, green: 0.33, blue: 0.33),
        .red,
        .green,
        .orange,
        .pink,
        .purple,
        .yellow,
        Color(red: 1.0, green: 0.55, blue: 0.0),  // orange-ish
        Color(red: 0.6, green: 0.6, blue: 0.6),   // gray
    ]

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#555555"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    static func fromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}
