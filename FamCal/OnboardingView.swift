//
//  OnboardingView.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

enum OnboardingStep {
    case intro
    case permission
    case notificationPermission
    case contactsPermission
    case familySetup
    case sharedCalendars
    case ready
}

struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .intro
    @State private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            switch currentStep {
            case .intro:
                IntroScreen(onGetStarted: {
                    withAnimation {
                        currentStep = .permission
                    }
                })

            case .permission:
                PermissionScreen(onNext: {
                    withAnimation {
                        currentStep = .notificationPermission
                    }
                })

            case .notificationPermission:
                NotificationPermissionScreen(onNext: {
                    withAnimation {
                        currentStep = .contactsPermission
                    }
                })

            case .contactsPermission:
                ContactsPermissionScreen(
                    onContinue: {
                        withAnimation { currentStep = .familySetup }
                    },
                    onSkip: {
                        withAnimation { currentStep = .familySetup }
                    }
                )

            case .familySetup:
                OnboardingFamilySetupView {
                    withAnimation {
                        currentStep = .sharedCalendars
                    }
                }

            case .sharedCalendars:
                OnboardingSharedCalendarsView {
                    withAnimation {
                        currentStep = .ready
                    }
                }

            case .ready:
                ReadyScreen(onStartUsingApp: {
                    completeOnboarding()
                })
            }
        }
        .fullScreenCover(isPresented: $hasCompletedOnboarding) {
            FamilyView()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
}
