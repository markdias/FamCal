//
//  LoginView.swift
//  FamCal
//
//  User login screen
//

import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showSignup = false
    @State private var showForgotPassword = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Background
            themeManager.selectedTheme.backgroundLayer()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 60)

                    // Logo/Title
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 70))
                            .foregroundStyle(themeManager.selectedTheme.textPrimary)

                        Text("FamCal")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.selectedTheme.textPrimary)

                        Text("Family Calendar Made Simple")
                            .font(.subheadline)
                            .foregroundStyle(themeManager.selectedTheme.textSecondary)
                    }
                    .padding(.bottom, 40)
                    
                    // Login Form
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
                            placeholder: "Password",
                            text: $password,
                            showPassword: $showPassword,
                            theme: themeManager.selectedTheme
                        )
                        
                        // Forgot Password
                        HStack {
                            Spacer()
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundStyle(themeManager.selectedTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 4)

                        // Login Button
                        Button {
                            Task {
                                await performLogin()
                            }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(themeManager.selectedTheme.textPrimary)
                                } else {
                                    Text("Sign In")
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

                        // Google Sign-In Button
                        Button {
                            performGoogleLogin()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text(authManager.isLoading ? "Signing in..." : "Continue with Google")
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

                        // Sign Up Link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                            Button {
                                showSignup = true
                            } label: {
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(themeManager.selectedTheme.accentColor)
                            }
                        }
                        .font(.subheadline)
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
                        .padding(.vertical, 8)

                        // Continue as Guest Button
                        Button {
                            authManager.continueAsGuest()
                        } label: {
                            HStack {
                                Image(systemName: "person.slash")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Continue as Guest")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundStyle(themeManager.selectedTheme.textSecondary)
                            .background(.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeManager.selectedTheme.floatingControlsBorder.opacity(0.5), lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                        .disabled(authManager.isLoading)

                        // Guest Warning
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Guest Mode")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("Settings stay local. Create an account to sync across devices.")
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(themeManager.selectedTheme.textSecondary.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .background(themeManager.selectedTheme.textSecondary.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                }
            }
        }
        .alert("Login Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showSignup) {
            SignupView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
    }
    
    // MARK: - Helpers
    
    private var isValidInput: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func performLogin() async {
        do {
            try await authManager.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performGoogleLogin() {
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
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SupabaseAuthManager.shared)
        .environmentObject(ThemeManager())
}
