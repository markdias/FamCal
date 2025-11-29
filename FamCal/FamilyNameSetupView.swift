//
//  FamilyNameSetupView.swift
//  FamCal
//
//  First screen: User enters their family name
//

import SwiftUI

struct FamilyNameSetupView: View {
    @Binding var familyName: String
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Name Your Family")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)

                Text("This helps organize your calendar")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Input Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)

                TextField("e.g., Smith Family", text: $familyName)
                    .font(.system(size: 16, weight: .regular))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            Spacer()

            // Next Button
            Button(action: onNext) {
                Text("Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(familyName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(familyName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}

#Preview {
    FamilyNameSetupView(familyName: .constant(""), onNext: {})
}
