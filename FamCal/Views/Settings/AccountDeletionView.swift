//
//  AccountDeletionView.swift
//  FamCal
//
//  Created by Mark Dias on 30/11/2025.
//

import SwiftUI

struct AccountDeletionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authManager: SupabaseAuthManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var dataManager: SupabaseDataManager
    private let supabaseManager = SupabaseManager.shared

    @State private var showingConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var linkedMembersWithOtherAccounts: [FamilyMemberDTO] = []
    @State private var isLoadingMembers = true

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Warning Header
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                            .padding(.top, 20)

                        VStack(spacing: 8) {
                            Text("Delete Account")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(primaryTextColor)

                            Text("This action cannot be undone")
                                .font(.system(size: 14))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)

                    // Warning Message
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("What will be deleted:")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(primaryTextColor)

                                    VStack(alignment: .leading, spacing: 8) {
                                        DeletionBulletPoint(text: "Your account and all authentication data")
                                        DeletionBulletPoint(text: "All family events and calendar data")
                                        DeletionBulletPoint(text: "All app settings and preferences")
                                        DeletionBulletPoint(text: "All family members and shared calendars")
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)

                    // Linked Accounts Warning (if applicable)
                    if !linkedMembersWithOtherAccounts.isEmpty {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Unlink Required")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.red)

                                        Text("Before deleting your account, you must unlink it from the following family members:")
                                            .font(.system(size: 13))
                                            .foregroundColor(secondaryTextColor)

                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(linkedMembersWithOtherAccounts, id: \.id) { member in
                                                HStack(spacing: 8) {
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.red)
                                                    Text(member.name)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(primaryTextColor)
                                                }
                                            }
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Loading State
                    if isLoadingMembers {
                        ProgressView()
                            .tint(theme.accentColor)
                            .padding(.vertical, 20)
                    } else if linkedMembersWithOtherAccounts.isEmpty {
                        // Delete Button (only if no linked members)
                        VStack(spacing: 12) {
                            Button(role: .destructive) {
                                showingConfirmation = true
                            } label: {
                                HStack {
                                    Text("Delete My Account")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                            }
                            .disabled(isDeleting)

                            Button {
                                dismiss()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.cardBackground)
                                    .foregroundColor(primaryTextColor)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(theme.cardStroke, lineWidth: 1)
                                    )
                            }
                            .disabled(isDeleting)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    } else {
                        // Disabled Delete Button
                        VStack(spacing: 12) {
                            Button {
                                // No action - button is disabled
                            } label: {
                                HStack {
                                    Text("Delete My Account")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(.gray)
                                .cornerRadius(12)
                            }
                            .disabled(true)

                            Text("Unlink from family members first")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)

                            Button {
                                dismiss()
                            } label: {
                                Text("Go Back")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.cardBackground)
                                    .foregroundColor(primaryTextColor)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(theme.cardStroke, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    if let error = deleteError {
                        VStack(spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)

                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .lineLimit(nil)
                            }
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Account?",
            isPresented: $showingConfirmation,
            presenting: ()
        ) { _ in
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("All your data will be permanently deleted. This cannot be undone.")
        }
        .onAppear {
            loadLinkedMembers()
        }
    }

    private func loadLinkedMembers() {
        isLoadingMembers = true

        Task {
            var responseData: Data?
            do {
                // Fetch all family members and check which ones have other linked accounts
                guard let familyId = appSettingsManager.familyId, !familyId.isEmpty else {
                    isLoadingMembers = false
                    return
                }

                var request = URLRequest(url: URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/family_members?family_id=eq.\(familyId)")!)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                if let token = authManager.accessToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }

                let (data, response) = try await URLSession.shared.data(for: request)
                responseData = data

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    deleteError = "Failed to check linked accounts"
                    isLoadingMembers = false
                    return
                }

                let decoder = JSONDecoder()
                let members = try decoder.decode([FamilyMemberDTO].self, from: data)

                if members.isEmpty {
                    print("ℹ️ No family members found for family: \(familyId)")
                }

                // Filter members that have a linked_user_id that isn't the current user
                linkedMembersWithOtherAccounts = members.filter { member in
                    member.linked_user_id != nil && member.linked_user_id != authManager.userId
                }

                isLoadingMembers = false
            } catch let decodingError as DecodingError {
                print("❌ Decoding error: \(decodingError)")
                if let data = responseData, let dataString = String(data: data, encoding: .utf8) {
                    print("❌ Response data: \(dataString)")
                }
                deleteError = "Failed to parse account information. Please try again."
                isLoadingMembers = false
            } catch {
                print("❌ Error checking linked accounts: \(error)")
                deleteError = "Error checking linked accounts: \(error.localizedDescription)"
                isLoadingMembers = false
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true
        deleteError = nil

        Task {
            do {
                // Delete account through Supabase manager
                try await supabaseManager.deleteAccount(userId: authManager.userId ?? "", token: authManager.accessToken)

                // Clear local session and sign out
                try await authManager.signOut()

                // Reset onboarding state
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

                dismiss()
            } catch {
                isDeleting = false
                deleteError = error.localizedDescription.isEmpty ? "Failed to delete account. Please try again." : error.localizedDescription
            }
        }
    }
}

struct DeletionBulletPoint: View {
    let text: String
    @EnvironmentObject private var themeManager: ThemeManager

    private var secondaryTextColor: Color { themeManager.selectedTheme.textSecondary }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(secondaryTextColor)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(secondaryTextColor)
                .lineLimit(nil)
        }
    }
}

#Preview {
    AccountDeletionView()
        .environmentObject(ThemeManager())
        .environmentObject(SupabaseAuthManager())
        .environmentObject(AppSettingsManager())
        .environmentObject(SupabaseDataManager())
}
