//
//  CustomRepeatView.swift
//  FamCal
//
//  Created by Codex on 2026-02-26.
//

import SwiftUI

struct CustomRepeatView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var recurrence: RecurrenceConfiguration
    let anchorDate: Date
    var onSave: (RecurrenceConfiguration) -> Void = { _ in }

    @State private var draft: RecurrenceConfiguration
    @State private var endSelection: EndSelection
    @State private var occurrencesCount: Int
    @State private var endDate: Date

    init(recurrence: Binding<RecurrenceConfiguration>, anchorDate: Date, onSave: @escaping (RecurrenceConfiguration) -> Void = { _ in }) {
        _recurrence = recurrence
        self.anchorDate = anchorDate
        self.onSave = onSave

        let initial = recurrence.wrappedValue
        _draft = State(initialValue: initial)
        _endSelection = State(initialValue: EndSelection(from: initial.end))
        _occurrencesCount = State(initialValue: initial.end.occurrenceCountFallback)
        _endDate = State(initialValue: initial.end.endDateFallback(anchor: anchorDate))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    toggleRow
                    frequencyPicker
                    intervalStepper
                    if draft.frequency == .weekly { weeklySelector }
                    if draft.frequency == .monthly { monthlyPatternSelector }
                    endSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground)) // Grey background
            .navigationTitle("Custom Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyDraft()
                        dismiss()
                    }
                }
            }
            .onChange(of: recurrence) { _, newValue in
                draft = newValue
                endSelection = EndSelection(from: newValue.end)
                occurrencesCount = newValue.end.occurrenceCountFallback
                endDate = newValue.end.endDateFallback(anchor: anchorDate)
            }
            .tint(.accentColor)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary")
                .font(.headline)
            Text(draft.isEnabled ? draft.summary(anchor: anchorDate) : "Does not repeat")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var toggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Repeat")
                    .font(.headline)
                Text(draft.isEnabled ? "Recurrence enabled" : "No repeat")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $draft.isEnabled)
                .labelsHidden()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequency")
                .font(.headline)

            Picker("Frequency", selection: $draft.frequency) {
                ForEach(RecurrenceFrequency.allCases) { frequency in
                    Text(frequency.rawValue).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!draft.isEnabled)
            .animation(.easeInOut, value: draft.frequency)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var intervalStepper: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interval")
                .font(.headline)
            Stepper {
                let unit = draft.frequency.unitLabel
                Text("Every \(draft.interval) \(unit)\(draft.interval == 1 ? "" : "s")")
            } onIncrement: {
                draft.interval = min(draft.interval + 1, 365)
            } onDecrement: {
                draft.interval = max(draft.interval - 1, 1)
            }
            .disabled(!draft.isEnabled)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var weeklySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat on")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Weekday.allCases) { weekday in
                    let isSelected = draft.selectedWeekdays.contains(weekday)
                    Button {
                        toggleWeekday(weekday)
                    } label: {
                        Text(weekday.shortName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                            )
                    }
                    .disabled(!draft.isEnabled)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var monthlyPatternSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly pattern")
                .font(.headline)

            Picker("Pattern", selection: monthlyPatternBinding) {
                Text("By date").tag(MonthlyMode.date)
                Text("By weekday").tag(MonthlyMode.weekday)
            }
            .pickerStyle(.segmented)
            .disabled(!draft.isEnabled)

            switch draft.monthlyPattern {
            case .dayOfMonth(let day):
                Stepper {
                    Text("On day \(day)")
                } onIncrement: {
                    let next = min(day + 1, 31)
                    draft.monthlyPattern = .dayOfMonth(next)
                } onDecrement: {
                    let next = max(day - 1, 1)
                    draft.monthlyPattern = .dayOfMonth(next)
                }
                .disabled(!draft.isEnabled)
            case .weekdayOrdinal(_):
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Week", selection: ordinalWeekBinding) {
                        ForEach(Ordinals.supported, id: \.self) { ord in
                            Text(Ordinals.describe(ord)).tag(ord)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!draft.isEnabled)

                    Picker("Weekday", selection: ordinalWeekdayBinding) {
                        ForEach(Weekday.allCases) { weekday in
                            Text(weekday.fullName).tag(weekday)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!draft.isEnabled)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var endSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("End")
                .font(.headline)

            Picker("Ends", selection: $endSelection) {
                ForEach(EndSelection.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!draft.isEnabled)
            .onChange(of: endSelection) { _, newValue in
                switch newValue {
                case .never:
                    draft.end = .never
                case .onDate:
                    draft.end = .endDate(endDate)
                case .after:
                    draft.end = .afterOccurrences(occurrencesCount)
                }
            }

            switch endSelection {
            case .never:
                EmptyView()
            case .onDate:
                DatePicker("End date", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .disabled(!draft.isEnabled)
                    .onChange(of: endDate) { _, newValue in
                        draft.end = .endDate(newValue)
                    }
            case .after:
                Stepper {
                    Text("After \(occurrencesCount) time\(occurrencesCount == 1 ? "" : "s")")
                } onIncrement: {
                    occurrencesCount = min(occurrencesCount + 1, 999)
                    draft.end = .afterOccurrences(occurrencesCount)
                } onDecrement: {
                    occurrencesCount = max(occurrencesCount - 1, 1)
                    draft.end = .afterOccurrences(occurrencesCount)
                }
                .disabled(!draft.isEnabled)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var monthlyPatternBinding: Binding<MonthlyMode> {
        Binding {
            switch draft.monthlyPattern {
            case .dayOfMonth: return .date
            case .weekdayOrdinal: return .weekday
            }
        } set: { newValue in
            switch newValue {
            case .date:
                let day = Calendar.current.component(.day, from: anchorDate)
                draft.monthlyPattern = .dayOfMonth(day)
            case .weekday:
                let weekday = Weekday.from(date: anchorDate) ?? .monday
                let ordinal = Ordinals.ordinal(for: anchorDate)
                draft.monthlyPattern = .weekdayOrdinal(WeekdayOrdinal(ordinal: ordinal, weekday: weekday))
            }
        }
    }

    private var ordinalWeekBinding: Binding<Int> {
        Binding {
            if case .weekdayOrdinal(let ordinal) = draft.monthlyPattern {
                return ordinal.ordinal
            }
            return Ordinals.ordinal(for: anchorDate)
        } set: { newValue in
            if case .weekdayOrdinal(let ordinal) = draft.monthlyPattern {
                draft.monthlyPattern = .weekdayOrdinal(WeekdayOrdinal(ordinal: newValue, weekday: ordinal.weekday))
            } else {
                let weekday = Weekday.from(date: anchorDate) ?? .monday
                draft.monthlyPattern = .weekdayOrdinal(WeekdayOrdinal(ordinal: newValue, weekday: weekday))
            }
        }
    }

    private var ordinalWeekdayBinding: Binding<Weekday> {
        Binding {
            if case .weekdayOrdinal(let ordinal) = draft.monthlyPattern {
                return ordinal.weekday
            }
            return Weekday.from(date: anchorDate) ?? .monday
        } set: { newValue in
            if case .weekdayOrdinal(let ordinal) = draft.monthlyPattern {
                draft.monthlyPattern = .weekdayOrdinal(WeekdayOrdinal(ordinal: ordinal.ordinal, weekday: newValue))
            } else {
                draft.monthlyPattern = .weekdayOrdinal(WeekdayOrdinal(ordinal: Ordinals.ordinal(for: anchorDate), weekday: newValue))
            }
        }
    }

    private func toggleWeekday(_ weekday: Weekday) {
        if draft.selectedWeekdays.contains(weekday) {
            draft.selectedWeekdays.remove(weekday)
        } else {
            draft.selectedWeekdays.insert(weekday)
        }

        if draft.selectedWeekdays.isEmpty, let anchor = Weekday.from(date: anchorDate) {
            draft.selectedWeekdays.insert(anchor)
        }
    }

    private func applyDraft() {
        recurrence = draft
        onSave(draft)
    }
}

private enum EndSelection: String, CaseIterable, Hashable {
    case never, onDate, after

    init(from end: RecurrenceEnd) {
        switch end {
        case .never: self = .never
        case .endDate: self = .onDate
        case .afterOccurrences: self = .after
        }
    }

    var title: String {
        switch self {
        case .never: return "Never"
        case .onDate: return "On date"
        case .after: return "After"
        }
    }
}

private extension RecurrenceEnd {
    var occurrenceCountFallback: Int {
        switch self {
        case .afterOccurrences(let count): return max(count, 1)
        default: return 1
        }
    }

    func endDateFallback(anchor: Date) -> Date {
        switch self {
        case .endDate(let date): return date
        default:
            return Calendar.current.date(byAdding: .month, value: 1, to: anchor) ?? anchor
        }
    }
}

private enum MonthlyMode: String, Hashable {
    case date
    case weekday
}

private enum Ordinals {
    static let supported: [Int] = [1, 2, 3, 4, -1]

    static func describe(_ value: Int) -> String {
        switch value {
        case 1: return "First"
        case 2: return "Second"
        case 3: return "Third"
        case 4: return "Fourth"
        case -1: return "Last"
        default: return "Every"
        }
    }

    static func ordinal(for date: Date, calendar: Calendar = .current) -> Int {
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: date) ?? date
        let isLastWeek = !calendar.isDate(nextWeek, equalTo: date, toGranularity: .month)
        if isLastWeek { return -1 }
        return calendar.component(.weekOfMonth, from: date)
    }
}
