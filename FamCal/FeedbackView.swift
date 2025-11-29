//
//  FeedbackView.swift
//  FamCal
//
//  Created by Codex on 29/11/2025.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var feedbackType: FeedbackType = .general
    @State private var feedbackText: String = ""
    @State private var email: String = ""
    @State private var includeContactInfo = false

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    enum FeedbackType: String, CaseIterable {
        case general = "General Feedback"
        case bug = "Report a Bug"
        case feature = "Feature Request"

        var icon: String {
            switch self {
            case .general: return "💬"
            case .bug: return "🐛"
            case .feature: return "✨"
            }
        }
    }

    var isFormValid: Bool {
        !feedbackText.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!includeContactInfo || !email.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                theme.backgroundLayer()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Send Feedback")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(primaryTextColor)

                            Text("Help us improve FamCal by sharing your thoughts, reporting bugs, or suggesting features.")
                                .font(.system(size: 15))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Feedback Type Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Feedback Type")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                ForEach(FeedbackType.allCases, id: \.self) { type in
                                    feedbackTypeButton(type: type)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Feedback Text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Feedback")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            TextEditor(text: $feedbackText)
                                .font(.system(size: 15))
                                .foregroundColor(primaryTextColor)
                                .frame(height: 150)
                                .padding(12)
                                .background(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(theme.cardStroke, lineWidth: 1)
                                )
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                        }

                        // Contact Information (Optional)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Toggle("", isOn: $includeContactInfo)
                                    .labelsHidden()
                                    .tint(theme.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Include Contact Information")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(primaryTextColor)
                                    Text("So we can follow up on your feedback")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryTextColor)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            if includeContactInfo {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email Address")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(secondaryTextColor)
                                        .padding(.horizontal, 16)

                                    TextField("your.email@example.com", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .font(.system(size: 15))
                                        .foregroundColor(primaryTextColor)
                                        .padding(12)
                                        .background(theme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(theme.cardStroke, lineWidth: 1)
                                        )
                                        .cornerRadius(8)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        Spacer(minLength: 20)

                        // Submit Button
                        Button(action: submitFeedback) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Send Feedback")
                                    .font(.system(size: 16, weight: .semibold))

                                Spacer()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(isFormValid ? theme.accentColor : Color.gray.opacity(0.4))
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
        }
    }

    private func feedbackTypeButton(type: FeedbackType) -> some View {
        let isSelected = feedbackType == type

        return Button(action: { feedbackType = type }) {
            HStack(spacing: 12) {
                Text(type.icon)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(primaryTextColor)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentColor)
                }
            }
            .padding(12)
            .background(isSelected ? theme.accentColor.opacity(0.1) : theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? theme.accentColor : theme.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(8)
        }
    }

    private func submitFeedback() {
        let feedbackData: [String: String] = [
            "type": feedbackType.rawValue,
            "message": feedbackText.trimmingCharacters(in: .whitespaces),
            "email": includeContactInfo ? email.trimmingCharacters(in: .whitespaces) : "Not provided",
            "timestamp": Date().description
        ]

        // Log to Xcode console
        print("=== FEEDBACK RECEIVED ===")
        print("Type: \(feedbackData["type"] ?? "")")
        print("Message: \(feedbackData["message"] ?? "")")
        print("Email: \(feedbackData["email"] ?? "")")
        print("Timestamp: \(feedbackData["timestamp"] ?? "")")
        print("========================")

        dismiss()
    }
}

#Preview {
    FeedbackView()
        .environmentObject(ThemeManager())
}
