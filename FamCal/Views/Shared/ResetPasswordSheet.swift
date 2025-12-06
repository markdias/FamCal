//
//  ResetPasswordSheet.swift
//  FamCal
//
//  Presents password reset after magic link recovery.
//

import SwiftUI

struct ResetPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: SupabaseAuthManager
    @EnvironmentObject private var themeManager: ThemeManager

    let email: String?

    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Set a new password")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.textPrimary)

                if let email {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.selectedTheme.textSecondary)
                }

                SecureField("New password", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(themeManager.selectedTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(themeManager.selectedTheme.cardStroke, lineWidth: 1)
                    )
                    .cornerRadius(10)

                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(themeManager.selectedTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(themeManager.selectedTheme.cardStroke, lineWidth: 1)
                    )
                    .cornerRadius(10)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.selectedTheme.accentColor)
                        .multilineTextAlignment(.center)
                }

                Button(action: updatePassword) {
                    HStack {
                        if isUpdating { ProgressView() }
                        Text("Update Password")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.selectedTheme.accentColor)
                .disabled(!canSubmit || isUpdating)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private func updatePassword() {
        guard canSubmit else {
            errorMessage = "Passwords must match."
            return
        }
        errorMessage = nil
        successMessage = nil
        isUpdating = true
        Task {
            do {
                try await authManager.updatePassword(newPassword: password)
                successMessage = "Password updated. You can now sign in with this password."
                dismiss()
            } catch {
                let msg = error.localizedDescription.lowercased()
                if msg.contains("same") || msg.contains("identical") || msg.contains("already") {
                    errorMessage = "Password could not be updated. Please choose a different one."
                } else {
                    errorMessage = "Password could not be updated. Please try again."
                }
            }
            isUpdating = false
        }
    }
}

#Preview {
    ResetPasswordSheet(email: "test@example.com")
        .environmentObject(SupabaseAuthManager.shared)
        .environmentObject(ThemeManager())
}
