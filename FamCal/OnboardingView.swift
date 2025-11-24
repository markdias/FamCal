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
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: SupabaseAuthManager

    @State private var currentStep: OnboardingStep = .intro
    @State private var hasCompletedOnboarding = false
    @State private var calendarPermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var contactsPermissionGranted = false
    @State private var hasFamily = false
    @State private var hasSharedCalendars = false

    var body: some View {
        ZStack {
            switch currentStep {
            case .intro:
                IntroScreen(onGetStarted: {
                    withAnimation {
                        advanceToNextStep()
                    }
                })

            case .permission:
                PermissionScreen(onNext: {
                    withAnimation {
                        advanceToNextStep()
                    }
                })

            case .notificationPermission:
                NotificationPermissionScreen(onNext: {
                    withAnimation {
                        advanceToNextStep()
                    }
                })

            case .contactsPermission:
                ContactsPermissionScreen(
                    onContinue: {
                        withAnimation { advanceToNextStep() }
                    },
                    onSkip: {
                        withAnimation { advanceToNextStep() }
                    }
                )

            case .familySetup:
                OnboardingFamilySetupView {
                    withAnimation {
                        advanceToNextStep()
                    }
                }

            case .sharedCalendars:
                OnboardingSharedCalendarsView {
                    withAnimation {
                        advanceToNextStep()
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
        .onAppear {
            checkInitialConditions()
        }
    }

    private func checkInitialConditions() {
        // Check calendar permission
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            calendarPermissionGranted = (status == .fullAccess || status == .writeOnly)
        } else {
            calendarPermissionGranted = (status == .authorized)
        }

        // Check notification permission asynchronously
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            await MainActor.run {
                notificationPermissionGranted = (settings.authorizationStatus == .authorized)
            }
        }

        // For authenticated users, assume they have everything set up (data will sync from Supabase)
        // Only check local data for guest users
        if authManager.isAuthenticated {
            print("ℹ️ Authenticated user detected - assuming family and calendars are set up")
            hasFamily = true
            hasSharedCalendars = true
        } else {
            // Check for existing family members (guest or first-time setup)
            let familyFetch = FamilyMember.fetchRequest()
            do {
                let count = try viewContext.count(for: familyFetch)
                hasFamily = count > 0
            } catch {
                print("⚠️ Error checking family members: \(error)")
                hasFamily = false
            }

            // Check for existing shared calendars
            let sharedCalendarFetch = SharedCalendar.fetchRequest()
            do {
                let count = try viewContext.count(for: sharedCalendarFetch)
                hasSharedCalendars = count > 0
            } catch {
                print("⚠️ Error checking shared calendars: \(error)")
                hasSharedCalendars = false
            }
        }
    }

    private func advanceToNextStep() {
        switch currentStep {
        case .intro:
            // For authenticated users, skip all permission screens and go straight to ready
            if authManager.isAuthenticated {
                print("ℹ️ Authenticated user - skipping all permission screens")
                currentStep = .ready
            } else if calendarPermissionGranted {
                // Skip calendar permission if already granted
                currentStep = .notificationPermission
            } else {
                currentStep = .permission
            }

        case .permission:
            // Skip notification screen if already granted
            if notificationPermissionGranted {
                currentStep = .contactsPermission
            } else {
                currentStep = .notificationPermission
            }

        case .notificationPermission:
            currentStep = .contactsPermission

        case .contactsPermission:
            // Skip family setup if members already exist
            if hasFamily {
                // Skip shared calendars if they already exist
                if hasSharedCalendars {
                    currentStep = .ready
                } else {
                    currentStep = .sharedCalendars
                }
            } else {
                currentStep = .familySetup
            }

        case .familySetup:
            // Skip shared calendars if they already exist
            if hasSharedCalendars {
                currentStep = .ready
            } else {
                currentStep = .sharedCalendars
            }

        case .sharedCalendars:
            currentStep = .ready

        case .ready:
            completeOnboarding()
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
