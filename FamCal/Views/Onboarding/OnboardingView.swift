//
//  OnboardingView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit
import UserNotifications

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case permissions
    case getStarted
    case proOffer

    var totalSteps: Int { Self.allCases.count }
}

struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: SupabaseAuthManager
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var currentStep: OnboardingStep = .welcome
    @Binding var hasCompletedOnboarding: Bool

    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        // Screen content - each screen provides its own background
        ZStack {
            switch currentStep {
            case .welcome:
                IntroScreen(
                    onNext: { goToNext() },
                    theme: theme,
                    currentStep: currentStep,
                    onSelectStep: { selectStep($0) }
                )

            case .permissions:
                PermissionScreen(
                    onNext: { goToNext() },
                    theme: theme,
                    currentStep: currentStep,
                    onSelectStep: { selectStep($0) }
                )

            case .getStarted:
                ReadyScreen(
                    onStartUsingApp: { goToNext() },
                    theme: theme,
                    currentStep: currentStep,
                    onSelectStep: { selectStep($0) }
                )

            case .proOffer:
                OnboardingProUpsellView(
                    currentStep: currentStep,
                    onSelectStep: { selectStep($0) },
                    onFinish: { completeOnboarding() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func goToNext() {
        let nextIndex = currentStep.rawValue + 1
        if let nextStep = OnboardingStep(rawValue: nextIndex) {
            withAnimation { currentStep = nextStep }
        }
    }

    private func selectStep(_ step: OnboardingStep) {
        withAnimation {
            currentStep = step
        }
    }

    private func goToPrevious() {
        let previousIndex = currentStep.rawValue - 1
        if previousIndex >= 0, let previousStep = OnboardingStep(rawValue: previousIndex) {
            withAnimation { currentStep = previousStep }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
