//
//  FamilySetupCompleteView.swift
//  FamCal
//
//  Fifth screen: Confirmation screen after completing family setup
//

import SwiftUI

struct FamilySetupCompleteView: View {
    let familyName: String
    let memberCount: Int
    var onStart: () -> Void

    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success Icon with animation
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .scaleEffect(showConfetti ? 1.1 : 0.9)
                }

                VStack(spacing: 8) {
                    Text("You're All Set!")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.5)

                    Text("Your family is ready to go")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                }
            }

            // Family Summary
            VStack(spacing: 12) {
                SummaryRow(label: "Family Name", value: familyName.isEmpty ? "Not set" : familyName)
                SummaryRow(label: "Members", value: "\(memberCount)")
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Spacer()

            // Start Button
            Button(action: {
                onStart()
            }) {
                Text("Start Using FamCal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Spacer()
        }
        .padding(24)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showConfetti = true
            }
        }
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    FamilySetupCompleteView(
        familyName: "Smith Family",
        memberCount: 4,
        onStart: {}
    )
}
