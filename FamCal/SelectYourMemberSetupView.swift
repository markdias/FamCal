//
//  SelectYourMemberSetupView.swift
//  FamCal
//
//  Fourth screen: User selects which family member they are
//

import SwiftUI

struct SelectYourMemberSetupView: View {
    let familyMembers: [FamilyMember]
    @Binding var selectedMemberId: UUID?
    var onNext: () -> Void
    var onBack: () -> Void

    var canProceed: Bool {
        selectedMemberId != nil
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Which member are you?")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)

                Text("This helps personalize your view")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Members Grid
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(familyMembers, id: \.id) { member in
                        MemberSelectionCard(
                            member: member,
                            isSelected: selectedMemberId == member.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedMemberId = member.id
                                }
                            }
                        )
                    }
                }
            }

            Spacer()

            // Navigation Buttons
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                Button(action: onNext) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canProceed ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!canProceed)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}

// MARK: - Member Selection Card

struct MemberSelectionCard: View {
    let member: FamilyMember
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Avatar
                let hexColor = member.colorHex ?? "#007AFF"
                Circle()
                    .fill(Color.fromHex(hexColor))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(member.avatarInitials ?? "?")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    )

                // Selection indicator
                if isSelected {
                    Circle()
                        .strokeBorder(Color.green, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                        .offset(x: 28, y: -28)
                }
            }

            Text(member.name ?? "Unknown")
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(1)

            if let calendarCount = member.memberCalendars?.count, calendarCount > 0 {
                Text("\(calendarCount) calendar\(calendarCount == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    SelectYourMemberSetupView(
        familyMembers: [],
        selectedMemberId: .constant(nil),
        onNext: {},
        onBack: {}
    )
}
