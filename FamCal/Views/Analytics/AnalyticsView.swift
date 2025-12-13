//
//  AnalyticsView.swift
//  FamCal
//
//  Prototype C: Standalone full-featured analytics dashboard
//  Can be accessed via navigation as a dedicated view
//  Shows detailed analytics for selected member and date
//

import SwiftUI
import CoreData

struct AnalyticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FamilyMember.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)
        ]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @State private var selectedMember: FamilyMember?
    @State private var selectedDate: Date = Date()
    @State private var analytics: TimeAnalytics?
    @State private var isCalculating = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if selectedMember != nil {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Member and date selection
                            selectionSection

                            if isCalculating {
                                loadingView
                            } else if let analytics = analytics {
                                // Analytics content
                                analyticsContent(analytics)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Daily Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            // Select first member by default
            if selectedMember == nil, let firstMember = familyMembers.first {
                selectedMember = firstMember
            }
        }
        .onChange(of: selectedMember) { _, newMember in
            if newMember != nil {
                calculateAnalytics()
            }
        }
        .onChange(of: selectedDate) { _, _ in
            calculateAnalytics()
        }
    }

    // MARK: - View Components

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Member picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Member")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Picker("Select Member", selection: $selectedMember) {
                    ForEach(familyMembers, id: \.self) { member in
                        Text(member.name ?? "Unknown").tag(member as FamilyMember?)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Date picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Date")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                    }

                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)

                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                    }
                }

                // Quick date buttons
                HStack(spacing: 8) {
                    quickDateButton("Today", date: Date())
                    quickDateButton(
                        "Tomorrow",
                        date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func quickDateButton(_ label: String, date: Date) -> some View {
        Button(action: { selectedDate = date }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Calendar.current.isDate(selectedDate, inSameDayAs: date) ? .white : .blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Calendar.current.isDate(selectedDate, inSameDayAs: date)
                        ? Color.blue
                        : Color(.tertiarySystemBackground)
                )
                .cornerRadius(8)
        }
    }

    private func analyticsContent(_ analytics: TimeAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Timeline visualization
            VStack(alignment: .leading, spacing: 8) {
                Text("Timeline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                TimelineVisualizationView(
                    analytics: analytics,
                    memberColor: UIColorFromHex(selectedMember?.colorHex ?? "#007AFF")
                )
            }

            // Metrics cards
            AnalyticsMetricsView(analytics: analytics)

            // Detailed events list
            if !analytics.busyBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Events Today")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(analytics.busyBlocks) { block in
                            eventBlockView(block)
                        }
                    }
                }
            }

            // Free gaps section
            if !analytics.gaps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Free Time Blocks")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(analytics.gaps) { gap in
                            gapBlockView(gap)
                        }
                    }
                }
            }

            // Insights section (placeholder for future features)
            VStack(alignment: .leading, spacing: 12) {
                Text("Insights")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(insightMessage(analytics: analytics))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
            }
        }
    }

    private func eventBlockView(_ block: BusyBlock) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatTime(block.start))
                    .font(.system(size: 13, weight: .semibold))

                Text("–")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Text(formatTime(block.end))
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(formatDuration(block.durationMinutes))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if !block.eventTitles.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(block.eventTitles, id: \.self) { title in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue.opacity(0.5))
                                .frame(width: 4, height: 4)

                            Text(title)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func gapBlockView(_ gap: TimeGap) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(gap.formattedTimeRange)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(gap.formattedDuration)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Member Selected")
                .font(.system(size: 16, weight: .semibold))

            Text("Select a family member to view their daily analytics.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Calculating analytics...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func calculateAnalytics() {
        guard let member = selectedMember else { return }

        isCalculating = true

        let calculator = TimeAnalyticsCalculator()

        // Get wake/bed times
        let wakeHour = member.useCustomSchedule ? Int(member.wakeTimeHour) : 7
        let wakeMinute = member.useCustomSchedule ? Int(member.wakeTimeMinute) : 0
        let bedHour = member.useCustomSchedule ? Int(member.bedTimeHour) : 22
        let bedMinute = member.useCustomSchedule ? Int(member.bedTimeMinute) : 0

        // TODO: Get events for this member from calendar data
        // For now, using empty array - should be integrated with event fetching
        let events: [UpcomingCalendarEvent] = []

        analytics = calculator.calculate(
            for: member.id ?? UUID(),
            date: selectedDate,
            wakeTime: (hour: wakeHour, minute: wakeMinute),
            bedTime: (hour: bedHour, minute: bedMinute),
            events: events
        )

        isCalculating = false
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    private func insightMessage(analytics: TimeAnalytics) -> String {
        if analytics.freePercentage >= 80 {
            return "✓ Lots of free time! Room for additional events."
        } else if analytics.freePercentage >= 50 {
            return "~ Moderate schedule. Some room for additional events."
        } else if analytics.freePercentage >= 25 {
            return "⚠ Busy day. Limited availability for new events."
        } else {
            return "⚠ Very busy day. Minimal free time available."
        }
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)

    let member = FamilyMember(context: context)
    member.id = UUID()
    member.name = "Sarah"
    member.colorHex = "#4ECDC4"
    member.wakeTimeHour = 7
    member.bedTimeHour = 22
    member.useCustomSchedule = false

    return AnalyticsView()
        .environment(\.managedObjectContext, context)
}
