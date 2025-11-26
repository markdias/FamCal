//
//  OnboardingFamilySetupView.swift
//  FamCal
//
//  Created by ChatGPT on 19/11/2025.
//

import SwiftUI
import CoreData

struct OnboardingFamilySetupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    var onNext: () -> Void

    @State private var showingAddMember = false
    private var isAtFamilyLimit: Bool {
        !appSettingsManager.isProUser && familyMembers.count >= appSettingsManager.maxFamilyMembersAllowed
    }

    var body: some View {
        ZStack {
            OnboardingGradientBackground()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                OnboardingGlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)

                        Text("Add your family")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Create a quick profile for each person so we can match the right calendars later.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                OnboardingGlassCard {
                    if familyMembers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 42))
                                .foregroundColor(.white)

                            Text("No family members yet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Add at least one person so we can link their calendars next.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(familyMembers, id: \.self) { member in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.fromHex(member.colorHex ?? "#555555"))
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.name ?? "Unknown")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)

                                        if let calendarCount = member.memberCalendars?.count, calendarCount > 0 {
                                            Text("\(calendarCount) calendar\(calendarCount == 1 ? "" : "s") linked")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.7))
                                        } else {
                                            Text("Calendars will be linked soon")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 10)

                                if member.id != familyMembers.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                }

                VStack(spacing: 14) {
                    OnboardingPrimaryButton(title: "Add Family Member") {
                        showingAddMember = true
                    }
                    .disabled(isAtFamilyLimit)
                    .opacity(isAtFamilyLimit ? 0.6 : 1.0)

                    if isAtFamilyLimit {
                        Text("Add up to 2 family members on Free. Enable FamCal Pro to add more.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    OnboardingSecondaryButton(
                        title: familyMembers.isEmpty ? "Skip for now" : "Continue",
                        action: onNext
                    )
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showingAddMember) {
            AddFamilyMemberView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

#Preview {
    OnboardingFamilySetupView(onNext: {})
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppSettingsManager())
}
