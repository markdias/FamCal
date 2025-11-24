//
//  IntroScreen.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

struct IntroScreen: View {
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
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("Welcome to FamCal")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                    
                    Text("The Family Calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.43, green: 0.43, blue: 0.45))
                        .tracking(0.5)
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
                
                // Feature cards
                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "calendar.circle.fill",
                        title: "Syncs to Apple Calendar",
                        description: "Seamlessly integrates with your existing calendars"
                    )
                    
                    FeatureRow(
                        icon: "person.2.circle.fill",
                        title: "Family Organization",
                        description: "Keep everyone's schedule in one place"
                    )
                    
                    FeatureRow(
                        icon: "paintpalette.fill",
                        title: "Beautiful Design",
                        description: "Clean and easy to use interface"
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
                
                // Next button
                OnboardingPrimaryButton(title: "Get Started", action: onNext)
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
}

#Preview {
    IntroScreen(onNext: {}, theme: .classic, currentStep: .welcome, onSelectStep: { _ in })
        .environmentObject(ThemeManager())
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.35, green: 0.34, blue: 0.84)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(red: 0.43, green: 0.43, blue: 0.45))
            }
            
            Spacer()
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
}
