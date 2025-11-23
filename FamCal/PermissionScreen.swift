//
//  PermissionScreen.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import EventKit

struct PermissionScreen: View {
    @State private var calendarPermissionGranted = false
    @State private var isRequestingPermission = false
    @State private var pulse = false

    var onNext: () -> Void

    var body: some View {
        ZStack {
            OnboardingGradientBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                OnboardingGlassCard {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 120, height: 120)
                                .scaleEffect(pulse ? 1.1 : 0.9)
                                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 70))
                                .foregroundColor(.white)
                        }

                        Text("Calendar Access")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("FamCal needs permission to read calendars so everyone stays aligned.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                OnboardingGlassCard {
                    VStack(spacing: 16) {
                        PermissionStatusRow(
                            title: "Calendar",
                            detail: calendarPermissionGranted ? "Access granted" : "Tap to allow",
                            granted: calendarPermissionGranted
                        )

                        Button(action: requestCalendarPermission) {
                            HStack(spacing: 12) {
                                Image(systemName: calendarPermissionGranted ? "checkmark.seal.fill" : "hand.point.up.left.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(calendarPermissionGranted ? "Already granted" : "Allow calendar access")
                                    .font(.system(size: 16, weight: .semibold))
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
                        }
                        .foregroundColor(.white)
                        .disabled(isRequestingPermission || calendarPermissionGranted)
                        .opacity(calendarPermissionGranted ? 0.7 : 1)
                    }
                }

                OnboardingPrimaryButton(
                    title: calendarPermissionGranted ? "Continue" : "Allow to continue",
                    action: onNext,
                    isDisabled: !calendarPermissionGranted
                )

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            checkCalendarPermission()
            pulse = true
        }
    }

    private func checkCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized:
            calendarPermissionGranted = true
        default:
            calendarPermissionGranted = false
        }
    }

    private func requestCalendarPermission() {
        guard !isRequestingPermission else { return }

        isRequestingPermission = true
        let eventStore = EKEventStore()

        eventStore.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                isRequestingPermission = false
                if granted {
                    calendarPermissionGranted = true
                }
            }
        }
    }
}

#Preview {
    PermissionScreen(onNext: {})
}

struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: granted ? "checkmark.circle.fill" : "calendar.badge.exclamationmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(granted ? .green : .yellow)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()
        }
    }
}
