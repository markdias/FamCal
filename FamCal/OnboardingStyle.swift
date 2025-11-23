//
//  OnboardingStyle.swift
//  FamCal
//
//  Created by ChatGPT on 19/11/2025.
//

import SwiftUI

// Shared styling primitives for onboarding so visuals stay consistent.
struct OnboardingGradientBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Swap gradient colors or tweak circle sizes to quickly restyle onboarding.
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.15, blue: 0.32),
                    Color(red: 0.05, green: 0.34, blue: 0.46),
                    Color(red: 0.04, green: 0.56, blue: 0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: animate ? 110 : -40, y: animate ? -160 : -40)
                // Adjust duration/damping here to slow down or speed up the ambient motion.
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animate)

            Circle()
                .fill(Color(red: 0.12, green: 0.69, blue: 0.74).opacity(0.25))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: animate ? -120 : 60, y: animate ? 160 : 20)
                .animation(.easeInOut(duration: 6.2).repeatForever(autoreverses: true), value: animate)
        }
        .onAppear { animate = true }
    }
}

struct OnboardingGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
        }
        .foregroundColor(.white)
        .background(
            // Adjust these gradient colors to quickly experiment with new brand palettes.
            LinearGradient(colors: [Color(red: 0.95, green: 0.63, blue: 0.15), Color(red: 0.92, green: 0.33, blue: 0.6)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isDisabled ? 0.4 : 1)
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)
        .disabled(isDisabled)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        }
    }
}
