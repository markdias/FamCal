//
//  NotificationMemberSelectionView.swift
//  FamCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import CoreData

struct NotificationMemberSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: FamilyMember.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)])
    private var familyMembers: FetchedResults<FamilyMember>
    @Binding var selectedMembers: Set<UUID>

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(spacing: 12) {
                        if familyMembers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.slash.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)

                                Text("No Family Members")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Add family members in settings to enable notifications")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                        } else {
                            ForEach(familyMembers, id: \.id) { member in
                                HStack(spacing: 12) {
                                    // Avatar
                                    ZStack {
                                        Circle()
                                            .fill(
                                                Color.fromHex(member.colorHex ?? "#007AFF")
                                            )

                                        Text(member.avatarInitials ?? "?")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 44, height: 44)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.name ?? "Unknown")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }

                                    Spacer()

                                    Image(systemName: selectedMembers.contains(member.id ?? UUID()) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedMembers.contains(member.id ?? UUID()) ? .blue : .gray)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let memberId = member.id ?? UUID()
                                    if selectedMembers.contains(memberId) {
                                        selectedMembers.remove(memberId)
                                    } else {
                                        selectedMembers.insert(memberId)
                                    }
                                    NotificationManager.shared.saveSettings()
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Select Members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

#Preview {
    NotificationMemberSelectionView(selectedMembers: .constant(Set()))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
