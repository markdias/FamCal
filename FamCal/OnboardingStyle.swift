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
            // Sophisticated grey gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.96, blue: 0.97), // #F5F5F7
                    Color(red: 0.91, green: 0.91, blue: 0.92)  // #E8E8EA
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle floating element 1 - top right
            Circle()
                .fill(Color(red: 0.85, green: 0.85, blue: 0.87).opacity(0.4))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: animate ? 80 : 60, y: animate ? -120 : -100)
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate)

            // Subtle floating element 2 - bottom left
            Circle()
                .fill(Color(red: 0.88, green: 0.88, blue: 0.90).opacity(0.35))
                .frame(width: 180, height: 180)
                .blur(radius: 45)
                .offset(x: animate ? -70 : -50, y: animate ? 140 : 120)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: animate)
            
            // Subtle floating element 3 - center
            Circle()
                .fill(Color(red: 0.82, green: 0.82, blue: 0.85).opacity(0.25))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: animate ? 30 : -30, y: animate ? 0 : 20)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(red: 0.85, green: 0.85, blue: 0.87).opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
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
                .frame(height: 56)
        }
        .foregroundColor(.white)
        .background(
            LinearGradient(
                colors: [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.35, green: 0.34, blue: 0.84)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(isDisabled ? 0.5 : 1)
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        .disabled(isDisabled)
    }
}

// Shared dot indicator so we can position progress consistently near the buttons.
struct OnboardingProgressDots: View {
    let theme: AppTheme
    let currentStep: OnboardingStep
    var onSelectStep: ((OnboardingStep) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                dot(for: step)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func dot(for step: OnboardingStep) -> some View {
        let isActive = currentStep == step
        let circle = Circle()
            .fill(
                LinearGradient(
                    colors: isActive
                    ? [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.35, green: 0.34, blue: 0.84)]
                    : [Color(red: 0.78, green: 0.78, blue: 0.80), Color(red: 0.68, green: 0.68, blue: 0.70)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: isActive ? 12 : 9, height: isActive ? 12 : 9)
            .shadow(color: isActive ? Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.4) : .clear, radius: isActive ? 6 : 0)

        if let onSelectStep {
            Button(action: { onSelectStep(step) }) {
                circle
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        } else {
            circle
        }
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(red: 0.28, green: 0.28, blue: 0.30))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.78, green: 0.78, blue: 0.80), lineWidth: 1.5)
                )
        }
    }
}
