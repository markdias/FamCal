//
//  DonateView.swift
//  FamCal
//
//  Created by Codex on 29/11/2025.
//

import SwiftUI

struct DonateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var selectedDonation: DonationType? = nil
    @State private var customAmount: String = ""
    @State private var donationNote: String = ""

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    enum DonationType: Identifiable {
        case crisps
        case coffee
        case lunch
        case custom

        var id: String {
            switch self {
            case .crisps: return "crisps"
            case .coffee: return "coffee"
            case .lunch: return "lunch"
            case .custom: return "custom"
            }
        }

        var amount: String {
            switch self {
            case .crisps: return "£1"
            case .coffee: return "£5"
            case .lunch: return "£10"
            case .custom: return "Custom"
            }
        }

        var title: String {
            switch self {
            case .crisps: return "Packet of Crisps"
            case .coffee: return "Coffee"
            case .lunch: return "Lunch"
            case .custom: return "Custom Amount"
            }
        }

        var icon: String {
            switch self {
            case .crisps: return "🥔"
            case .coffee: return "☕"
            case .lunch: return "🍽️"
            case .custom: return "💳"
            }
        }
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
                            Text("Support FamCal")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(primaryTextColor)

                            Text("Love FamCal? Help us keep the app free and continuously improving by making a donation.")
                                .font(.system(size: 15))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Donation Options
                        VStack(spacing: 12) {
                            donationOption(type: .crisps)
                            donationOption(type: .coffee)
                            donationOption(type: .lunch)
                        }
                        .padding(.horizontal, 16)

                        // Custom Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Optional Amount")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            HStack(spacing: 12) {
                                Text("£")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(primaryTextColor)

                                TextField("Enter amount", text: $customAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16))
                                    .foregroundColor(primaryTextColor)
                            }
                            .padding(12)
                            .background(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                            .cornerRadius(8)
                            .padding(.horizontal, 16)

                            if !customAmount.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "💳")
                                        .font(.system(size: 20))

                                    Button(action: { selectedDonation = .custom }) {
                                        HStack {
                                            Text("Custom Amount")
                                                .font(.system(size: 16, weight: .medium))
                                            Spacer()
                                            Text("£\(customAmount)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(theme.accentColor)
                                        }
                                        .foregroundColor(primaryTextColor)
                                        .padding(12)
                                    }

                                    if selectedDonation == .custom {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(theme.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Note Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a Note (Optional)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 16)

                            TextEditor(text: $donationNote)
                                .font(.system(size: 15))
                                .foregroundColor(primaryTextColor)
                                .frame(height: 100)
                                .padding(12)
                                .background(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(theme.cardStroke, lineWidth: 1)
                                )
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 20)

                        // Donate Button
                        Button(action: performDonation) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 16, weight: .semibold))

                                Text(selectedDonation != nil ? "Donate \(getDonationAmount())" : "Select a donation amount")
                                    .font(.system(size: 16, weight: .semibold))

                                Spacer()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(selectedDonation != nil ? theme.accentColor : Color.gray.opacity(0.4))
                            .cornerRadius(12)
                        }
                        .disabled(selectedDonation == nil)
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

    private func donationOption(type: DonationType) -> some View {
        let isSelected = selectedDonation == type

        return Button(action: { selectedDonation = type }) {
            HStack(spacing: 12) {
                Text(type.icon)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(type.amount)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                }

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

    private func getDonationAmount() -> String {
        guard let donation = selectedDonation else { return "" }
        if donation == .custom {
            return customAmount.isEmpty ? "£0" : "£\(customAmount)"
        }
        return donation.amount
    }

    private func performDonation() {
        guard let donation = selectedDonation else { return }

        let amount: String
        switch donation {
        case .crisps:
            amount = "£1"
        case .coffee:
            amount = "£5"
        case .lunch:
            amount = "£10"
        case .custom:
            amount = "£\(customAmount)"
        }

        // Log to Xcode console
        print("=== DONATION RECEIVED ===")
        print("Amount: \(amount)")
        print("Note: \(donationNote.isEmpty ? "No note provided" : donationNote)")
        print("Timestamp: \(Date())")
        print("======================")
    }
}

#Preview {
    DonateView()
        .environmentObject(ThemeManager())
}
