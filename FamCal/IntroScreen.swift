//
//  IntroScreen.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

struct IntroScreen: View {
    var onGetStarted: () -> Void
    @State private var floatIcon = false

    var body: some View {
        ZStack {
            OnboardingGradientBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                OnboardingGlassCard {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.system(size: 88))
                            .foregroundStyle(Color.white, Color.white.opacity(0.6))
                            .scaleEffect(floatIcon ? 1.05 : 0.95)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 14)
                            .animation(
                                .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                                value: floatIcon
                            )

                        Text("Welcome to FamCal")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)

                        Text("Plan carpools, sports, and the everyday chaos with a shared family brain.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                OnboardingGlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Link everyone's calendars instantly", systemImage: "person.3.sequence.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Label("Spotlight what's happening today", systemImage: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))

                        Label("Share focus lists like pickups or practice", systemImage: "list.bullet.rectangle.portrait.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                VStack(spacing: 14) {
                    OnboardingPrimaryButton(title: "Get Started", action: onGetStarted)

                    Text("Takes less than a minute")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear { floatIcon = true }
    }
}

#Preview {
    IntroScreen(onGetStarted: {})
}
