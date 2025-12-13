//
//  MemberScheduleSettingsView.swift
//  FamCal
//
//  Settings for configuring a family member's daily wake and bed times
//

import SwiftUI
import CoreData

struct MemberScheduleSettingsView: View {
    @ObservedObject var member: FamilyMember
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var useCustomSchedule: Bool
    @State private var wakeTime: Date
    @State private var bedTime: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(member: FamilyMember) {
        self.member = member
        _useCustomSchedule = State(initialValue: member.useCustomSchedule)

        // Initialize dates from stored hour/minute
        let calendar = Calendar.current
        let now = Date()
        _wakeTime = State(initialValue: calendar.date(
            bySettingHour: Int(member.wakeTimeHour),
            minute: Int(member.wakeTimeMinute),
            second: 0,
            of: now
        ) ?? now)
        _bedTime = State(initialValue: calendar.date(
            bySettingHour: Int(member.bedTimeHour),
            minute: Int(member.bedTimeMinute),
            second: 0,
            of: now
        ) ?? now)
    }

    var body: some View {
        Form {
            Section(header: Text("Daily Schedule")) {
                Toggle("Use Custom Schedule", isOn: $useCustomSchedule)

                if useCustomSchedule {
                    DatePicker(
                        "Wake Time",
                        selection: $wakeTime,
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "Bed Time",
                        selection: $bedTime,
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            if useCustomSchedule {
                Section {
                    schedulePreview
                }
            }

            Section(footer: Text("These times define your available hours for analytics calculations. Default is 7:00 AM to 10:00 PM.")) {
                EmptyView()
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                }
            }
        }
        .navigationTitle("\(member.name ?? "Member") Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        saveSchedule()
                    }
                }
            }
        }
    }

    private var schedulePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Hours")
                .font(.system(size: 14, weight: .semibold))

            let calendar = Calendar.current
            let wakeHour = calendar.component(.hour, from: wakeTime)
            let wakeMinute = calendar.component(.minute, from: wakeTime)
            let bedHour = calendar.component(.hour, from: bedTime)
            let bedMinute = calendar.component(.minute, from: bedTime)

            let availableMinutes = calculateAvailableMinutes(
                wakeHour: wakeHour,
                wakeMinute: wakeMinute,
                bedHour: bedHour,
                bedMinute: bedMinute
            )

            Text("\(formatMinutes(availableMinutes)) per day")
                .font(.system(size: 16, weight: .medium))

            Text("From \(formatTime(wakeHour, wakeMinute)) to \(formatTime(bedHour, bedMinute))")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private func saveSchedule() {
        isSaving = true
        errorMessage = nil

        let calendar = Calendar.current
        let wakeHour = calendar.component(.hour, from: wakeTime)
        let wakeMinute = calendar.component(.minute, from: wakeTime)
        let bedHour = calendar.component(.hour, from: bedTime)
        let bedMinute = calendar.component(.minute, from: bedTime)

        // Validate times
        let wakeTotal = wakeHour * 60 + wakeMinute
        let bedTotal = bedHour * 60 + bedMinute

        if wakeTotal >= bedTotal {
            errorMessage = "Wake time must be before bed time"
            isSaving = false
            return
        }

        // Update CoreData
        member.useCustomSchedule = useCustomSchedule
        member.wakeTimeHour = Int16(wakeHour)
        member.wakeTimeMinute = Int16(wakeMinute)
        member.bedTimeHour = Int16(bedHour)
        member.bedTimeMinute = Int16(bedMinute)
        member.modifiedAt = Date()

        do {
            try viewContext.save()

            // Sync to Supabase
            Task {
                do {
                    try await SupabaseManager.shared.updateFamilyMemberSchedule(
                        memberId: member.id?.uuidString ?? "",
                        wakeTimeHour: wakeHour,
                        wakeTimeMinute: wakeMinute,
                        bedTimeHour: bedHour,
                        bedTimeMinute: bedMinute,
                        useCustomSchedule: useCustomSchedule
                    )

                    await MainActor.run {
                        isSaving = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "Failed to sync schedule: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            isSaving = false
            errorMessage = "Failed to save schedule: \(error.localizedDescription)"
        }
    }

    private func calculateAvailableMinutes(wakeHour: Int, wakeMinute: Int, bedHour: Int, bedMinute: Int) -> Int {
        let totalWakeMinutes = wakeHour * 60 + wakeMinute
        let totalBedMinutes = bedHour * 60 + bedMinute
        return totalBedMinutes - totalWakeMinutes
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if mins > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(hours)h"
        }
    }

    private func formatTime(_ hour: Int, _ minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    let member = FamilyMember(context: context)
    member.id = UUID()
    member.name = "John Doe"
    member.wakeTimeHour = 7
    member.wakeTimeMinute = 0
    member.bedTimeHour = 22
    member.bedTimeMinute = 0
    member.useCustomSchedule = false

    return NavigationStack {
        MemberScheduleSettingsView(member: member)
    }
    .environment(\.managedObjectContext, context)
}
