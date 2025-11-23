//
//  AppGroupDefaults.swift
//  FamCal
//
//  Created by Claude Code
//

import Foundation

/// Utility for accessing UserDefaults via app groups
/// Allows widget and main app to share user preferences
struct AppGroupDefaults {
    static let appGroupID = "group.com.markdias.famli"

    static var shared: UserDefaults {
        return UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    }
}
