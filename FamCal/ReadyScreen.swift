//
//  ReadyScreen.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

struct ReadyScreen: View {
    var onStartUsingApp: () -> Void
    @State private var confetti = false

    var body: some View {
        ZStack {
            OnboardingGradientBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                OnboardingGlassCard {
                    VStack(spacing: 16) {
                        ZStack {
                            ForEach(0..<12, id: \.self) { index in
                                Capsule()
                                    .fill(index % 2 == 0 ? Color.white.opacity(0.7) : Color.white.opacity(0.4))
                                    .frame(width: 6, height: 24)
                                    .offset(y: -70)
                                    .rotationEffect(.degrees(Double(index) / 12.0 * 360.0))
                                    .opacity(confetti ? 1 : 0)
                                    .animation(
                                        .easeInOut(duration: 0.8)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.05),
                                        value: confetti
                                    )
                            }

                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 86))
                                .foregroundColor(.white)
                        }

                        Text("You're all set!")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)

                        Text("FamCal will keep your crew in sync with smart linking, shared timelines, and spotlight summaries.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                VStack(spacing: 16) {
                    OnboardingPrimaryButton(title: "Start using FamCal", action: onStartUsingApp)

                    Text("Tip: You can tweak colors and calendars anytime from Settings.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear { confetti = true }
    }
}

#Preview {
    ReadyScreen(onStartUsingApp: {})
}
