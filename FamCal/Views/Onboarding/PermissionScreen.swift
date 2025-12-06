//
//  PermissionScreen.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import EventKit
import Contacts
import UserNotifications

struct PermissionScreen: View {
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var calendarPermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var contactsPermissionGranted = false

    @State private var isRequestingCalendar = false
    @State private var isRequestingNotification = false
    @State private var isRequestingContacts = false

    var onNext: () -> Void
    let theme: AppTheme
    let currentStep: OnboardingStep
    var onSelectStep: ((OnboardingStep) -> Void)? = nil

    var body: some View {
        ZStack {
            // Grey gradient background
            OnboardingGradientBackground()
            
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Header card
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 72))
                        .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("Permissions")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                    
                    Text("We need a few permissions to get started")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.43, green: 0.43, blue: 0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 25, x: 0, y: 12)
                .padding(.horizontal, 24)

                Spacer().frame(height: 40)

                // Permission cards
                VStack(spacing: 16) {
                    PermissionCard(
                        iconName: "calendar",
                        title: "Calendar",
                        description: "Required to sync your events",
                        granted: calendarPermissionGranted,
                        isRequesting: isRequestingCalendar,
                        action: requestCalendarPermission
                    )

                    PermissionCard(
                        iconName: "person.2",
                        title: "Contacts",
                        description: "Sync contacts for drivers",
                        granted: contactsPermissionGranted,
                        isRequesting: isRequestingContacts,
                        isOptional: true,
                        action: requestContactsPermission
                    )

                    PermissionCard(
                        iconName: "bell.badge",
                        title: "Notifications",
                        description: "Event and morning summaries",
                        granted: notificationPermissionGranted,
                        isRequesting: isRequestingNotification,
                        isOptional: true,
                        action: requestNotificationPermission
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Progress dots
                OnboardingProgressDots(
                    theme: theme,
                    currentStep: currentStep,
                    onSelectStep: { handleStepSelection($0) }
                )
                .padding(.bottom, 20)

                // Next button
                OnboardingPrimaryButton(
                    title: "Continue",
                    action: onNext,
                    isDisabled: !calendarPermissionGranted
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            checkAllPermissions()
        }
    }

    private func handleStepSelection(_ step: OnboardingStep) {
        guard let onSelectStep else { return }
        if step.rawValue <= OnboardingStep.permissions.rawValue || calendarPermissionGranted {
            onSelectStep(step)
        }
    }

    private func checkAllPermissions() {
        // Calendar
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            calendarPermissionGranted = (calendarStatus == .fullAccess || calendarStatus == .writeOnly)
        } else {
            calendarPermissionGranted = (calendarStatus == .authorized)
        }

        // Contacts
        let contactsStatus = ContactsManager.shared.getContactsAuthorizationStatus()
        contactsPermissionGranted = (contactsStatus == .authorized || contactsStatus == .limited)

        // Notifications
        Task {
            let granted = await notificationManager.checkNotificationPermission()
            await MainActor.run {
                notificationPermissionGranted = granted
            }
        }
    }

    private func requestCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .denied || status == .restricted {
            openSettings()
            return
        }

        guard !isRequestingCalendar else { return }
        isRequestingCalendar = true
        let eventStore = EKEventStore()

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    isRequestingCalendar = false
                    if granted {
                        calendarPermissionGranted = true
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    isRequestingCalendar = false
                    if granted {
                        calendarPermissionGranted = true
                    }
                }
            }
        }
    }

    private func requestContactsPermission() {
        let status = ContactsManager.shared.getContactsAuthorizationStatus()
        if status == .denied || status == .restricted {
            openSettings()
            return
        }

        guard !isRequestingContacts else { return }
        isRequestingContacts = true

        Task {
            let granted = await ContactsManager.shared.requestContactsAccess()
            await MainActor.run {
                contactsPermissionGranted = granted
                isRequestingContacts = false
            }
        }
    }

    private func requestNotificationPermission() {
        // Notifications don't have a synchronous "status" check that is as simple, 
        // but we can assume if not granted and we are asking again, it might need settings.
        // For simplicity, we just request. The manager handles the request.
        
        guard !isRequestingNotification else { return }
        isRequestingNotification = true

        Task {
            let granted = await notificationManager.requestNotificationPermission()
            await MainActor.run {
                notificationPermissionGranted = granted
                isRequestingNotification = false
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    PermissionScreen(onNext: {}, theme: .classic, currentStep: .permissions)
}

struct PermissionCard: View {
    let iconName: String
    let title: String
    let description: String
    let granted: Bool
    let isRequesting: Bool
    var isOptional: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            granted
                            ? LinearGradient(
                                colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.0, green: 0.68, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.35, green: 0.34, blue: 0.84)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: granted ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: granted ? "checkmark" : iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                        
                        if isOptional {
                            Text("(optional)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(red: 0.43, green: 0.43, blue: 0.45))
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.43, green: 0.43, blue: 0.45))
                }
                
                Spacer()
                
                // Right side: Allow button or checkmark
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                } else if isRequesting {
                    ProgressView()
                        .tint(Color(red: 0.0, green: 0.48, blue: 1.0))
                } else {
                    Text("Allow")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.35, green: 0.34, blue: 0.84)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.25), radius: 6, x: 0, y: 3)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        granted
                        ? Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.3)
                        : Color.white,
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(granted || isRequesting)
    }
}
