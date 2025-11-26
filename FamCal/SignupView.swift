//
//  SignupView.swift
//  FamCal
//
//  User signup screen
//

import SwiftUI
import UIKit

struct SignupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            // Background
            themeManager.selectedTheme.backgroundLayer()
                .ignoresSafeArea()
            
            ScrollView {
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
                    
                    // Title
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(themeManager.selectedTheme.textPrimary)

                        Text("Create Account")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.selectedTheme.textPrimary)

                        Text("Join FamCal to sync your family calendar")
                            .font(.subheadline)
                            .foregroundStyle(themeManager.selectedTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 20)
                    
                    // Signup Form
                    VStack(spacing: 20) {
                        // Email Field
                        GlassyTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email,
                            theme: themeManager.selectedTheme
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                        // Password Field
                        GlassySecureField(
                            icon: "lock.fill",
                            placeholder: "Password (min 10 characters)",
                            text: $password,
                            showPassword: $showPassword,
                            theme: themeManager.selectedTheme
                        )

                        // Confirm Password Field
                        GlassySecureField(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            showPassword: $showConfirmPassword,
                            theme: themeManager.selectedTheme
                        )
                        
                        // Password Requirements
                        if !password.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                PasswordRequirement(text: "At least 10 characters", isMet: hasMinLength, theme: themeManager.selectedTheme)
                                PasswordRequirement(text: "One lowercase letter", isMet: hasLowercase, theme: themeManager.selectedTheme)
                                PasswordRequirement(text: "One uppercase letter", isMet: hasUppercase, theme: themeManager.selectedTheme)
                                PasswordRequirement(text: "One digit", isMet: hasDigit, theme: themeManager.selectedTheme)
                                PasswordRequirement(text: "One symbol", isMet: hasSymbol, theme: themeManager.selectedTheme)
                                PasswordRequirement(text: "Passwords match", isMet: passwordsMatch, theme: themeManager.selectedTheme)
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Sign Up Button
                        Button {
                            Task {
                                await performSignup()
                            }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(themeManager.selectedTheme.textPrimary)
                                } else {
                                    Text("Create Account")
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
                        .disabled(authManager.isLoading || !isValidInput)
                        .opacity(isValidInput ? 1.0 : 0.5)
                        .padding(.top, 10)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(themeManager.selectedTheme.textSecondary.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundStyle(themeManager.selectedTheme.textSecondary.opacity(0.8))
                            Rectangle()
                                .fill(themeManager.selectedTheme.textSecondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        // Google Sign-Up
                        Button {
                            performGoogleSignup()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text(authManager.isLoading ? "Connecting..." : "Continue with Google")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeManager.selectedTheme.floatingControlsBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                        .foregroundStyle(themeManager.selectedTheme.textPrimary)
                        .disabled(authManager.isLoading)

                        // Terms
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundStyle(themeManager.selectedTheme.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
        }
        .alert("Signup Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success!", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Account created successfully! You can now sign in.")
        }
    }
    
    // MARK: - Helpers
    
    private var hasMinLength: Bool { password.count >= 10 }
    private var hasLowercase: Bool { password.range(of: "[a-z]", options: .regularExpression) != nil }
    private var hasUppercase: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    private var hasDigit: Bool { password.range(of: "[0-9]", options: .regularExpression) != nil }
    private var hasSymbol: Bool { password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }

    private var isValidInput: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        hasMinLength &&
        hasLowercase &&
        hasUppercase &&
        hasDigit &&
        hasSymbol &&
        passwordsMatch
    }
    
    private func performSignup() async {
        do {
            try await authManager.signUp(email: email, password: password)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performGoogleSignup() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "Unable to find a window to present Google Sign-In."
            showError = true
            return
        }

        Task {
            do {
                try await authManager.signInWithGoogle(presenting: rootViewController)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    let theme: AppTheme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? .green : theme.textSecondary)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(theme.textPrimary.opacity(isMet ? 1.0 : 0.7))
        }
    }
}

#Preview {
    SignupView()
        .environmentObject(SupabaseAuthManager.shared)
        .environmentObject(ThemeManager())
}
