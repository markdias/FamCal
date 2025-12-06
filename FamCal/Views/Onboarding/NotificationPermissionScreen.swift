//
//  NotificationPermissionScreen.swift
//  FamCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI

struct NotificationPermissionScreen: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isRequesting = false
    @State private var hasRequested = false
    @State private var permissionGranted = false
    @State private var pulse = false

    var onNext: () -> Void

    var body: some View {
        ZStack {
            OnboardingGradientBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                OnboardingGlassCard {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 120, height: 120)
                                .scaleEffect(pulse ? 1.08 : 0.92)
                                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                            Image(systemName: "bell.and.waveform.fill")
                                .font(.system(size: 72))
                                .foregroundColor(.white)
                        }

                        Text("Stay updated")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Turn on notifications so we can remind the family about pickups, practice, and last-minute changes.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                OnboardingGlassCard {
                    VStack(spacing: 16) {
                        NotificationStatusRow(
                            title: permissionGranted ? "Notifications enabled" : "Notifications off",
                            detail: permissionGranted ? "We'll nudge you before events start" : "We won't send alerts unless you allow them",
                            granted: permissionGranted
                        )

                        Button(action: requestPermission) {
                            HStack(spacing: 12) {
                                if isRequesting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: permissionGranted ? "checkmark.seal.fill" : "bell.badge")
                                        .font(.system(size: 18, weight: .semibold))
                                }

                                Text(permissionGranted ? "Permission granted" : hasRequested ? "Request again" : "Enable notifications")
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
                        .disabled(isRequesting || permissionGranted)
                        .opacity(permissionGranted ? 0.65 : 1)

                        if hasRequested {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: permissionGranted ? "hand.thumbsup.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(permissionGranted ? .green : Color.yellow.opacity(0.9))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(permissionGranted ? "You're set" : "Permission still off")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text(permissionGranted
                                         ? "We'll keep alerts gentle—no spam."
                                         : "You can always enable notifications later in Settings.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                        }
                    }
                }

                OnboardingPrimaryButton(
                    title: permissionGranted ? "Continue" : "Skip for now",
                    action: onNext
                )

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            checkInitialPermission()
            pulse = true
        }
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            let granted = await notificationManager.requestNotificationPermission()
            await MainActor.run {
                permissionGranted = granted
                hasRequested = true
                isRequesting = false
            }
        }
    }

    private func checkInitialPermission() {
        Task {
            let granted = await notificationManager.checkNotificationPermission()
            await MainActor.run {
                if granted {
                    permissionGranted = true
                    hasRequested = true
                }
            }
        }
    }
}

#Preview {
    NotificationPermissionScreen(onNext: {})
}

private struct NotificationStatusRow: View {
    let title: String
    let detail: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: granted ? "checkmark.circle.fill" : "bell.slash.fill")
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
