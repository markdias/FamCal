//
//  OnboardingProUpsellView.swift
//  FamCal
//
//  Mirrors the FamCal Pro screen for the final onboarding step.
//

import SwiftUI

struct OnboardingProUpsellView: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedPlan: PlanOption = .annual

    let currentStep: OnboardingStep
    var onSelectStep: ((OnboardingStep) -> Void)?
    let onFinish: () -> Void

    private struct Feature: Identifiable {
        let id = UUID()
        let title: String
        let freeValue: String
        let proValue: String
        let isBoolean: Bool
    }

    private enum PlanOption: String {
        case annual
        case monthly
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

    var body: some View {
        ZStack {
            themeManager.selectedTheme.backgroundLayer().ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        featureTable
                        bottomSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
                    .padding(.bottom, 12)
                }

                VStack(spacing: 12) {
                    OnboardingProgressDots(
                        theme: themeManager.selectedTheme,
                        currentStep: currentStep,
                        onSelectStep: onSelectStep
                    )

                    OnboardingPrimaryButton(title: "Start Using FamCal", action: onFinish)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
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
                        Text("Pro enabled via onboarding")
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
                        Button("Restore Purchases") {
                            handleRestorePurchases()
                        }
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

    private func handleRestorePurchases() {
        appSettingsManager.isProUser = true
        Task { await appSettingsManager.saveSettings() }
    }
}

#Preview {
    OnboardingProUpsellView(
        currentStep: .proOffer,
        onSelectStep: { _ in },
        onFinish: {}
    )
    .environmentObject(AppSettingsManager())
    .environmentObject(ThemeManager())
}
