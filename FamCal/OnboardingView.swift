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
    case welcome = 0
    case permissions = 1
    case getStarted = 2

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
                    onStartUsingApp: { completeOnboarding() },
                    theme: theme,
                    currentStep: currentStep,
                    onSelectStep: { selectStep($0) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func goToNext() {
        if currentStep.rawValue < OnboardingStep.getStarted.rawValue {
            withAnimation {
                currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .getStarted
            }
        }
    }

    private func selectStep(_ step: OnboardingStep) {
        withAnimation {
            currentStep = step
        }
    }

    private func goToPrevious() {
        if currentStep.rawValue > 0 {
            withAnimation {
                currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
            }
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
