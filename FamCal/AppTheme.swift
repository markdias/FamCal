//
//  AppTheme.swift
//  FamCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI
import Combine

struct ThemeGradient: Equatable {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint

    func linearGradient() -> LinearGradient {
        LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
}

struct AppTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let prefersDarkInterface: Bool
    let backgroundColor: Color
    let backgroundGradient: ThemeGradient?
    let cardBackground: Color
    let cardStroke: Color
    let floatingControlsBackground: Color
    let floatingControlsBorder: Color
    let floatingControlForeground: Color
    let accentColor: Color
    let accentGradient: ThemeGradient?
    let textPrimary: Color
    let textSecondary: Color
    let chromeOverlay: Color
    let mutedTagColor: Color

    static let classic = AppTheme(
        id: "classic",
        displayName: "FamCal Classic",
        description: "Bright cards, white background, and system blue actions.",
        prefersDarkInterface: false,
        backgroundColor: Color(.systemGroupedBackground),
        backgroundGradient: nil,
        cardBackground: Color(.systemBackground),
        cardStroke: Color.black.opacity(0.05),
        floatingControlsBackground: Color(.systemBackground).opacity(0.95),
        floatingControlsBorder: Color.black.opacity(0.08),
        floatingControlForeground: Color(red: 0.33, green: 0.33, blue: 0.33),
        accentColor: Color(red: 0.33, green: 0.33, blue: 0.33),
        accentGradient: nil,
        textPrimary: Color.primary,
        textSecondary: Color.gray,
        chromeOverlay: Color(.systemGray6),
        mutedTagColor: Color.gray.opacity(0.8)
    )

    static let launchFlow = AppTheme(
        id: "launchFlow",
        displayName: "Launch Flow",
        description: "Glass cards floating on the teal onboarding gradient with sunset accents.",
        prefersDarkInterface: true,
        backgroundColor: Color(red: 0.03, green: 0.17, blue: 0.32),
        backgroundGradient: ThemeGradient(
            colors: [
                Color(red: 0.02, green: 0.15, blue: 0.32),
                Color(red: 0.05, green: 0.34, blue: 0.46),
                Color(red: 0.04, green: 0.56, blue: 0.54)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBackground: Color.white.opacity(0.14),
        cardStroke: Color.white.opacity(0.28),
        floatingControlsBackground: Color.white.opacity(0.18),
        floatingControlsBorder: Color.white.opacity(0.3),
        floatingControlForeground: Color.white,
        accentColor: Color(red: 0.94, green: 0.53, blue: 0.45),
        accentGradient: ThemeGradient(
            colors: [
                Color(red: 0.95, green: 0.63, blue: 0.15),
                Color(red: 0.92, green: 0.33, blue: 0.6)
            ],
            startPoint: .leading,
            endPoint: .trailing
        ),
        textPrimary: Color.white,
        textSecondary: Color.white.opacity(0.78),
        chromeOverlay: Color.white.opacity(0.25),
        mutedTagColor: Color.white.opacity(0.75)
    )

    static let allThemes: [AppTheme] = [.classic, .launchFlow]

    static func theme(with id: String?) -> AppTheme? {
        guard let id = id else { return nil }
        return allThemes.first(where: { $0.id == id })
    }
}

extension AppTheme {
    @ViewBuilder
    func backgroundLayer() -> some View {
        if let gradient = backgroundGradient {
            gradient.linearGradient()
        } else {
            backgroundColor
        }
    }

    func accentFillStyle() -> AnyShapeStyle {
        if let gradient = accentGradient {
            return AnyShapeStyle(gradient.linearGradient())
        } else {
            return AnyShapeStyle(accentColor)
        }
    }
}

final class ThemeManager: ObservableObject {
    @Published private(set) var selectedTheme: AppTheme
    @Published var isDarkModeEnabled: Bool
    private var baseTheme: AppTheme
    private let storageKey = "selectedThemeID"
    private let darkModeKey = "darkModeEnabled"

    init(defaultTheme: AppTheme = .classic) {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        let initialBaseTheme = AppTheme.theme(with: stored) ?? defaultTheme
        let initialDarkModeEnabled = UserDefaults.standard.bool(forKey: darkModeKey)

        baseTheme = initialBaseTheme
        isDarkModeEnabled = initialDarkModeEnabled
        selectedTheme = ThemeManager.makeEffectiveTheme(from: initialBaseTheme, darkModeEnabled: initialDarkModeEnabled)
    }

    func select(theme: AppTheme) {
        guard theme != baseTheme else { return }
        baseTheme = theme
        UserDefaults.standard.set(theme.id, forKey: storageKey)
        applyEffectiveTheme()
    }

    func setDarkMode(_ enabled: Bool) {
        guard enabled != isDarkModeEnabled else { return }
        isDarkModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: darkModeKey)
        applyEffectiveTheme()
    }

    func getEffectiveTheme() -> AppTheme {
        ThemeManager.makeEffectiveTheme(from: baseTheme, darkModeEnabled: isDarkModeEnabled)
    }

    private func applyEffectiveTheme() {
        selectedTheme = ThemeManager.makeEffectiveTheme(from: baseTheme, darkModeEnabled: isDarkModeEnabled)
    }

    private static func makeEffectiveTheme(from baseTheme: AppTheme, darkModeEnabled: Bool) -> AppTheme {
        guard darkModeEnabled else { return baseTheme }

        return AppTheme(
            id: baseTheme.id,
            displayName: baseTheme.displayName,
            description: baseTheme.description,
            prefersDarkInterface: true,
            backgroundColor: Color(red: 0.07, green: 0.08, blue: 0.12),
            backgroundGradient: ThemeGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.12),
                    Color(red: 0.07, green: 0.1, blue: 0.16),
                    Color(red: 0.05, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            cardBackground: Color(red: 0.13, green: 0.14, blue: 0.2),
            cardStroke: Color.white.opacity(0.08),
            floatingControlsBackground: Color.white.opacity(0.06),
            floatingControlsBorder: Color.white.opacity(0.12),
            floatingControlForeground: Color.white,
            accentColor: baseTheme.accentColor,
            accentGradient: baseTheme.accentGradient,
            textPrimary: Color.white,
            textSecondary: Color.white.opacity(0.7),
            chromeOverlay: Color.white.opacity(0.12),
            mutedTagColor: Color.white.opacity(0.55)
        )
    }
}
