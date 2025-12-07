//
//  PremiumBannerView.swift
//  FamCal
//
//  Created by Codex on 21/11/2025.
//

import SwiftUI

struct PremiumBannerView: View {
    let isPro: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isPro {
                // Minimal badge for Pro users
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Text("Pro Active")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("Manage")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            } else {
                // Compact card for Free users
                HStack(spacing: 14) {
                    // Icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.4))

                    // Content
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FamCal Pro")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)

                        Text("Unlimited family, themes & more")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))

                        Text("3-day free trial")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.4))
                    }

                    Spacer()

                    // CTA
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)

                        Text("View")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.24, blue: 0.30),
                            Color(red: 0.30, green: 0.34, blue: 0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PremiumBannerView(isPro: false, action: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}

struct FamCalProView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedPlan: PlanOption = .annual

    private struct Feature: Identifiable {
        let id = UUID()
        let title: String
        let freeValue: String
        let proValue: String
        let isBoolean: Bool
    }

    private let features: [Feature] = [
        Feature(title: "Family members", freeValue: "2", proValue: "Unlimited", isBoolean: false),
        Feature(title: "Spotlight events", freeValue: "5", proValue: "15", isBoolean: false),
        Feature(title: "Shared calendars", freeValue: "1", proValue: "Unlimited", isBoolean: false),
        Feature(title: "Themes", freeValue: "—", proValue: "✓", isBoolean: true),
        Feature(title: "Widgets", freeValue: "—", proValue: "✓", isBoolean: true),
        Feature(title: "Saved places", freeValue: "—", proValue: "✓", isBoolean: true),
        Feature(title: "Drivers", freeValue: "—", proValue: "✓", isBoolean: true),
        Feature(title: "Remove ads", freeValue: "—", proValue: "✓", isBoolean: true)
    ]
    
    private enum PlanOption: String {
        case annual
        case monthly
    }

    var body: some View {
        ZStack {
            themeManager.selectedTheme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    featureTable
                    bottomSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 32)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.textSecondary)
                    .padding()
            }
            .accessibilityLabel("Close")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FamCal Pro")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(themeManager.selectedTheme.textPrimary)
                .padding(.top, 12)

            Text("Unlock more capacity and polish for your family calendar.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.selectedTheme.textSecondary)

            if appSettingsManager.isProUser {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("You're already Pro")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var featureTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's Included")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.textPrimary)

            VStack(spacing: 0) {
                tableHeader
                Divider().background(themeManager.selectedTheme.cardStroke)
                ForEach(features) { feature in
                    featureRow(feature)
                    if feature.id != features.last?.id {
                        Divider().background(themeManager.selectedTheme.cardStroke)
                    }
                }
            }
            .background(themeManager.selectedTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(themeManager.selectedTheme.cardStroke, lineWidth: 1)
            )
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("Feature")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.textSecondary)
            Spacer()
            Text("Free")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.textSecondary)
                .frame(width: 80, alignment: .center)
            Text("Pro")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.textSecondary)
                .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .center) {
            Text(feature.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.selectedTheme.textPrimary)
            Spacer()
            Text(feature.freeValue)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(themeManager.selectedTheme.textSecondary)
                .frame(width: 80, alignment: .center)
            proValueView(feature.proValue, isBoolean: feature.isBoolean)
                .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func proValueView(_ value: String, isBoolean: Bool) -> some View {
        if isBoolean {
            return AnyView(
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(themeManager.selectedTheme.accentColor)
                    .font(.system(size: 16, weight: .semibold))
            )
        } else {
            return AnyView(
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.accentColor)
            )
        }
    }

    private var bottomSection: some View {
        Group {
            if appSettingsManager.isProUser {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Pro enabled via Settings > Test Only")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.textPrimary)
                    }
                    Text("Thanks for testing FamCal Pro. All premium features are unlocked.")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.selectedTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose your plan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme.textPrimary)

                    planCard(
                        title: "Annual",
                        subtitle: "Save 57% versus monthly",
                        price: "£14.99/year",
                        badge: "Best value",
                        option: .annual
                    )
                    planCard(
                        title: "Monthly",
                        subtitle: "Start small, upgrade anytime",
                        price: "£2.99/month",
                        badge: nil,
                        option: .monthly
                    )

                    Button(action: {
                        print("🛎️ Pro trial selected plan: \(selectedPlan.rawValue)")
                    }) {
                        Text("Start 3-day free trial")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.selectedTheme.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Text("Then £14.99/yr, billed annually.")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.selectedTheme.textSecondary)

                    VStack(spacing: 8) {
                        Button("Restore Purchases") {}
                            .font(.system(size: 14, weight: .semibold))
                        HStack(spacing: 16) {
                            Button("Terms & Conditions") {}
                                .font(.system(size: 12))
                            Button("Privacy Policy") {}
                                .font(.system(size: 12))
                        }
                        .foregroundColor(themeManager.selectedTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func planCard(title: String, subtitle: String, price: String, badge: String?, option: PlanOption) -> some View {
        let isSelected = selectedPlan == option
        let isDimmed = !isSelected
        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(isDimmed ? Color.gray.opacity(0.4) : themeManager.selectedTheme.accentColor, lineWidth: 3)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(themeManager.selectedTheme.accentColor)
                        .frame(width: 12, height: 12)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme.textPrimary.opacity(isDimmed ? 0.6 : 1))
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.selectedTheme.accentColor.opacity(0.15))
                            .foregroundColor(themeManager.selectedTheme.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.selectedTheme.textSecondary.opacity(isDimmed ? 0.6 : 1))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(price)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.selectedTheme.textPrimary.opacity(isDimmed ? 0.6 : 1))
                Text(isDimmed ? "Billed monthly" : "3-day free trial, then billed annually")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.selectedTheme.textSecondary.opacity(isDimmed ? 0.6 : 1))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(themeManager.selectedTheme.cardBackground.opacity(isDimmed ? 0.6 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isDimmed ? themeManager.selectedTheme.cardStroke : themeManager.selectedTheme.accentColor, lineWidth: 2)
        )
        .onTapGesture {
            selectedPlan = option
            print("ℹ️ Selected plan: \(option.rawValue)")
        }
    }
}
