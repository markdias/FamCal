//
//  FamilyNameSetupView.swift
//  FamCal
//
//  First screen: User enters their family name and verifies email
//

import SwiftUI

struct FamilyNameSetupView: View {
    @Binding var familyName: String
    var onNext: () -> Void

    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var isEmailVerified = false
    @State private var isCheckingVerification = false
    @State private var showVerificationSent = false
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var baseFamilyName: String = ""

    var body: some View {
        VStack(spacing: 24) {
            // Header with Sign Out button
            HStack {
                VStack(spacing: 12) {
                    Text("Name Your Family")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.5)

                    Text("This helps organize your calendar")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Allow both guests and authenticated users to exit the setup
                Button(action: { showSignOutConfirmation = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Log Out")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .disabled(isSigningOut)
            }

            // Email Verification Section (only for non-Google authenticated users)
            if requiresEmailVerification, let userEmail = authManager.userEmail {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isEmailVerified ? .green : .orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Verify Your Email")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(userEmail)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            if isEmailVerified {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                        if !isEmailVerified {
                            Text("Please check your email and click the verification link. We’ll detect verification automatically.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !isEmailVerified {
                        // Manual confirmation checkbox
                        HStack(spacing: 12) {
                            Button(action: { isEmailVerified.toggle() }) {
                                HStack(spacing: 10) {
                                    Image(systemName: isEmailVerified ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 18))
                                        .foregroundColor(isEmailVerified ? .green : .gray)

                                    Text("I've verified my email")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.primary)
                                }
                            }

                            Spacer()
                        }
                    }

                    // Check Again Button
                    Button(action: { checkVerificationStatus() }) {
                        HStack {
                            if isCheckingVerification {
                                ProgressView()
                                    .tint(.blue)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Check Again")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(.blue)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .disabled(isCheckingVerification)
                }
                .padding(12)
                .background(Color(.systemGray5).opacity(0.5))
                .cornerRadius(12)
            }

            // Input Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)

                HStack {
                    TextField("e.g., Smith", text: $baseFamilyName)
                        .font(.system(size: 16, weight: .regular))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: baseFamilyName) { _, newValue in
                            familyName = normalizedFamilyName(from: newValue)
                        }

                    Text("Family")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }
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
                    .background(isButtonDisabled ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(isButtonDisabled || isSigningOut)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .onAppear(perform: handleInitialVerification)
        .alert("Log Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                performSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll return to the login screen and can sign in or continue as guest to keep going.")
        }
    }

    private var isButtonDisabled: Bool {
        let emptyName = baseFamilyName.trimmingCharacters(in: .whitespaces).isEmpty
        if authManager.isGuest || authManager.isGoogleUser {
            return emptyName
        } else {
            return emptyName || !isEmailVerified
        }
    }

    private var requiresEmailVerification: Bool {
        !authManager.isGuest && !authManager.isGoogleUser
    }

    private func handleInitialVerification() {
        if authManager.didConfirmEmailViaLink {
            isEmailVerified = true
        }
        baseFamilyName = extractBaseFamilyName(from: familyName)
        familyName = normalizedFamilyName(from: baseFamilyName)

        if authManager.isGoogleUser {
            isEmailVerified = true
            return
        }

        if requiresEmailVerification && !isEmailVerified {
            checkVerificationStatus(triggeredAutomatically: true)
        }
    }

    private func checkVerificationStatus(triggeredAutomatically: Bool = false) {
        guard !isCheckingVerification else { return }
        isCheckingVerification = true

        Task {
            defer { isCheckingVerification = false }

            do {
                // Check actual email verification status from Supabase
                let isVerified = try await authManager.checkEmailVerificationStatus()
                if isVerified {
                    await MainActor.run {
                        isEmailVerified = true
                    }
                    print("✅ Email verified!")
                } else if !triggeredAutomatically {
                    print("ℹ️ Email not yet verified")
                }
            } catch {
                print("❌ Error checking email verification: \(error.localizedDescription)")
            }
        }
    }

    private func normalizedFamilyName(from base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.lowercased().hasSuffix(" family") {
            return trimmed
        }
        return "\(trimmed) Family"
    }

    private func extractBaseFamilyName(from full: String) -> String {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasSuffix(" family") {
            let dropCount = " Family".count
            let base = String(trimmed.dropLast(dropCount))
            return base.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func performSignOut() {
        isSigningOut = true

        Task {
            defer { isSigningOut = false }

            do {
                try await authManager.signOut()
                print("✅ User signed out successfully")
            } catch {
                print("❌ Sign out error: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    FamilyNameSetupView(familyName: .constant(""), onNext: {})
        .environmentObject(SupabaseAuthManager.shared)
}
