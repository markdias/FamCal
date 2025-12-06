//
//  ForgotPasswordView.swift
//  FamCal
//
//  Password reset screen
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var email = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            // Background
            themeManager.selectedTheme.backgroundLayer()
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(themeManager.selectedTheme.textPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)

                Spacer()

                // Title
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.selectedTheme.textPrimary)

                    Text("Reset Password")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.selectedTheme.textPrimary)

                    Text("Enter your email and we'll send you a link to reset your password")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Email Field
                VStack(spacing: 20) {
                    GlassyTextField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        theme: themeManager.selectedTheme
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    
                    // Send Reset Link Button
                    Button {
                        Task {
                            await sendResetLink()
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(themeManager.selectedTheme.textPrimary)
                            } else {
                                Text("Send Reset Link")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(themeManager.selectedTheme.floatingControlsBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeManager.selectedTheme.floatingControlsBorder, lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }
                    .foregroundStyle(themeManager.selectedTheme.textPrimary)
                    .disabled(authManager.isLoading || !isValidEmail)
                    .opacity(isValidEmail ? 1.0 : 0.5)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                Spacer()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Check Your Email", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("We've sent a password reset link to \(email)")
        }
    }
    
    // MARK: - Helpers
    
    private var isValidEmail: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    private func sendResetLink() async {
        do {
            try await authManager.resetPassword(email: email)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(SupabaseAuthManager.shared)
        .environmentObject(ThemeManager())
}
