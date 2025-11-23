//
//  ContactsPermissionScreen.swift
//  FamCal
//
//  Created by Mark Dias on 19/11/2025.
//

import SwiftUI
import Contacts

struct ContactsPermissionScreen: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var contactsAccessGranted = false
    @State private var isRequestingPermission = false
    @State private var orbit = false

    var body: some View {
        ZStack {
            OnboardingGradientBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                OnboardingGlassCard {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                                .frame(width: 140, height: 140)
                                .overlay(
                                    Circle()
                                        .trim(from: 0, to: 0.35)
                                        .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                        .frame(width: 160, height: 160)
                                        .rotationEffect(.degrees(orbit ? 360 : 0))
                                        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: false), value: orbit)
                                )

                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 72))
                                .foregroundColor(.white)
                        }

                        Text("Import family from Contacts")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Add drivers or caregivers straight from contacts so sharing pickups is effortless.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                OnboardingGlassCard {
                    VStack(spacing: 20) {
                        PermissionStatusRow(
                            title: "Contacts",
                            detail: contactsAccessGranted ? "Permission granted" : "Not permitted yet",
                            granted: contactsAccessGranted
                        )

                        Button(action: requestContactsPermission) {
                            if isRequestingPermission {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                HStack(spacing: 12) {
                                    Image(systemName: contactsAccessGranted ? "checkmark.seal.fill" : "hand.tap")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(contactsAccessGranted ? "Access already granted" : "Allow access to Contacts")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                        .disabled(contactsAccessGranted || isRequestingPermission)
                        .opacity(contactsAccessGranted ? 0.6 : 1)
                    }
                }

                VStack(spacing: 16) {
                    OnboardingPrimaryButton(
                        title: contactsAccessGranted ? "Continue" : "I'll do this later",
                        action: onContinue
                    )

                    OnboardingSecondaryButton(title: "Skip for now", action: onSkip)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            checkContactsPermission()
            orbit = true
        }
    }

    private func checkContactsPermission() {
        let status = ContactsManager.shared.getContactsAuthorizationStatus()
        contactsAccessGranted = (status == .authorized)
    }

    private func requestContactsPermission() {
        guard !contactsAccessGranted else { return }
        isRequestingPermission = true

        Task {
            let granted = await ContactsManager.shared.requestContactsAccess()
            await MainActor.run {
                contactsAccessGranted = granted
                isRequestingPermission = false
            }
        }
    }
}

#Preview {
    ContactsPermissionScreen(onContinue: {}, onSkip: {})
}
