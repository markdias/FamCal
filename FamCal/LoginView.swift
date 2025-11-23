//
//  LoginView.swift
//  FamCal
//
//  User login screen
//

import SwiftUI

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
}

#Preview {
    LoginView()
        .environmentObject(SupabaseAuthManager.shared)
        .environmentObject(ThemeManager())
}
