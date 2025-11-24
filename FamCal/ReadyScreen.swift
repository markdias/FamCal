//
//  ReadyScreen.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

struct ReadyScreen: View {
    var onStartUsingApp: () -> Void
    let theme: AppTheme
    let currentStep: OnboardingStep
    var onSelectStep: ((OnboardingStep) -> Void)? = nil
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Grey gradient background
            OnboardingGradientBackground()
            
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Header card with success animation
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.15))
                            .frame(width: 100, height: 100)
                            .scaleEffect(scale)
                            .opacity(opacity)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    Text("You're All Set!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                    
                    Text("Here are some helpful resources")
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

                // Resource cards
                VStack(spacing: 16) {
                    ResourceCard(
                        icon: "checkmark.circle.fill",
                        title: "Check Permissions",
                        subtitle: "Settings › Permissions",
                        action: {}
                    )

                    ResourceCard(
                        icon: "book.circle.fill",
                        title: "User Guide",
                        subtitle: "Settings › Help",
                        action: {}
                    )

                    ResourceCard(
                        icon: "envelope.circle.fill",
                        title: "Contact Support",
                        subtitle: "help@famcal.app",
                        action: {
                            if let url = URL(string: "mailto:help@famcal.app") {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Progress dots
                OnboardingProgressDots(
                    theme: theme,
                    currentStep: currentStep,
                    onSelectStep: onSelectStep
                )
                .padding(.bottom, 20)

                // Start button
                OnboardingPrimaryButton(title: "Start Using FamCal", action: onStartUsingApp)
                    .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    ReadyScreen(onStartUsingApp: {}, theme: .classic, currentStep: .getStarted)
}

struct ResourceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .frame(width: 48)
                    .shadow(color: Color.blue.opacity(0.2), radius: 5, x: 0, y: 2)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(red: 0.43, green: 0.43, blue: 0.45))
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.78, green: 0.78, blue: 0.80))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}
