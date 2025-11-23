//
//  RecurrenceConfiguration.swift
//  FamCal
//
//  Created by Codex on 2026-02-26.
//

import Foundation
import EventKit

enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var id: String { rawValue }

    var unitLabel: String {
        switch self {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }
}

enum RecurrenceEnd: Equatable {
    case never
    case endDate(Date)
    case afterOccurrences(Int)
}

enum MonthlyPattern: Equatable {
    case dayOfMonth(Int)
    case weekdayOrdinal(WeekdayOrdinal)
}

struct WeekdayOrdinal: Equatable {
    let ordinal: Int // 1...4 or -1 (last)
    let weekday: Weekday

    var readableDescription: String {
        "\(ordinalDescription) \(weekday.fullName)"
    }

    private var ordinalDescription: String {
        switch ordinal {
        case 1: return "First"
        case 2: return "Second"
        case 3: return "Third"
        case 4: return "Fourth"
        case -1: return "Last"
        default: return "Every"
        }
    }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    static func from(date: Date, calendar: Calendar = .current) -> Weekday? {
        let value = calendar.component(.weekday, from: date)
        return Weekday(rawValue: value)
    }
}

struct RecurrenceConfiguration: Equatable {
    var isEnabled: Bool
    var frequency: RecurrenceFrequency
    var interval: Int
    var selectedWeekdays: Set<Weekday>
    var monthlyPattern: MonthlyPattern
    var end: RecurrenceEnd

    static func none(anchor: Date) -> RecurrenceConfiguration {
        RecurrenceConfiguration(
            isEnabled: false,
            frequency: .weekly,
            interval: 1,
            selectedWeekdays: Weekday.from(date: anchor).map { [$0] } ?? [.monday],
            monthlyPattern: RecurrenceConfiguration.defaultMonthlyPattern(for: anchor),
            end: .never
        )
    }

    static func quick(option: RepeatOption, anchor: Date) -> RecurrenceConfiguration? {
        switch option {
        case .none:
            return RecurrenceConfiguration.none(anchor: anchor)
        case .daily:
            return RecurrenceConfiguration(
                isEnabled: true,
                frequency: .daily,
                interval: 1,
                selectedWeekdays: Weekday.from(date: anchor).map { [$0] } ?? [.monday],
                monthlyPattern: RecurrenceConfiguration.defaultMonthlyPattern(for: anchor),
                end: .never
            )
        case .weekly:
            let weekday = Weekday.from(date: anchor) ?? .monday
            return RecurrenceConfiguration(
                isEnabled: true,
                frequency: .weekly,
                interval: 1,
                selectedWeekdays: [weekday],
                monthlyPattern: RecurrenceConfiguration.defaultMonthlyPattern(for: anchor),
                end: .never
            )
        case .monthly:
            return RecurrenceConfiguration(
                isEnabled: true,
                frequency: .monthly,
                interval: 1,
                selectedWeekdays: Weekday.from(date: anchor).map { [$0] } ?? [.monday],
                monthlyPattern: RecurrenceConfiguration.defaultMonthlyPattern(for: anchor),
                end: .never
            )
        case .yearly:
            return RecurrenceConfiguration(
                isEnabled: true,
                frequency: .yearly,
                interval: 1,
                selectedWeekdays: Weekday.from(date: anchor).map { [$0] } ?? [.monday],
                monthlyPattern: RecurrenceConfiguration.defaultMonthlyPattern(for: anchor),
                end: .never
            )
        case .custom:
            return nil
        }
    }

    static func from(rule: EKRecurrenceRule, anchor: Date) -> RecurrenceConfiguration? {
        let frequency: RecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default:
            return nil
        }

        let interval = max(rule.interval, 1)
        let weekdays = Set(rule.daysOfTheWeek?.compactMap { Weekday(rawValue: Int($0.dayOfTheWeek.rawValue)) } ?? [])

        let monthlyPattern: MonthlyPattern
        if let monthDays = rule.daysOfTheMonth, let day = monthDays.first?.intValue {
            let normalizedDay = max(1, min(abs(day), 31))
            monthlyPattern = .dayOfMonth(normalizedDay)
        } else if let dayOfWeek = rule.daysOfTheWeek?.first,
                  let weekday = Weekday(rawValue: Int(dayOfWeek.dayOfTheWeek.rawValue)) {
            let ordinal = dayOfWeek.weekNumber
            if ordinal != 0 {
                monthlyPattern = .weekdayOrdinal(WeekdayOrdinal(ordinal: ordinal, weekday: weekday))
            } else {
                monthlyPattern = RecurrenceConfiguration.defaultMonthlyPattern(for: anchor)
            }
        } else {
            monthlyPattern = RecurrenceConfiguration.defaultMonthlyPattern(for: anchor)
        }

        let end: RecurrenceEnd
        if let recurrenceEnd = rule.recurrenceEnd {
            if let endDate = recurrenceEnd.endDate {
                end = .endDate(endDate)
            } else if recurrenceEnd.occurrenceCount > 0 {
                end = .afterOccurrences(recurrenceEnd.occurrenceCount)
            } else {
                end = .never
            }
        } else {
            end = .never
        }

        return RecurrenceConfiguration(
            isEnabled: true,
            frequency: frequency,
            interval: interval,
            selectedWeekdays: weekdays.isEmpty ? (Weekday.from(date: anchor).map { [$0] } ?? [.monday]) : weekdays,
            monthlyPattern: monthlyPattern,
            end: end
        )
    }

    func suggestedRepeatOption(anchor: Date) -> RepeatOption {
        guard isEnabled else { return .none }

        let isDefaultEnd = {
            switch end {
            case .never: return true
            default: return false
            }
        }()

        switch frequency {
        case .daily:
            return interval == 1 && isDefaultEnd ? .daily : .custom
        case .weekly:
            let anchorWeekday = Weekday.from(date: anchor)
            let singleAnchorDay = selectedWeekdays.count <= 1 && selectedWeekdays.contains(anchorWeekday ?? .monday)
            return interval == 1 && singleAnchorDay && isDefaultEnd ? .weekly : .custom
        case .monthly:
            if interval == 1 && isDefaultEnd {
                switch monthlyPattern {
                case .dayOfMonth: return .monthly
                case .weekdayOrdinal: return .custom
                }
            }
            return .custom
        case .yearly:
            return interval == 1 && isDefaultEnd ? .yearly : .custom
        }
    }

    func summary(anchor: Date) -> String {
        guard isEnabled else { return "Does not repeat" }

        var parts: [String] = []

        let intervalText = interval == 1 ? "Every" : "Every \(interval)"

        switch frequency {
        case .daily:
            parts.append("\(intervalText) day\(interval == 1 ? "" : "s")")
        case .weekly:
            let dayList = selectedWeekdays.sorted { $0.rawValue < $1.rawValue }
                .map { $0.shortName }
                .joined(separator: ", ")
            let dayText = dayList.isEmpty ? "" : " on \(dayList)"
            parts.append("\(intervalText) week\(interval == 1 ? "" : "s")\(dayText)")
        case .monthly:
            switch monthlyPattern {
            case .dayOfMonth(let day):
                parts.append("\(intervalText) month\(interval == 1 ? "" : "s") on day \(day)")
            case .weekdayOrdinal(let ordinal):
                parts.append("\(intervalText) month\(interval == 1 ? "" : "s") on the \(ordinal.readableDescription)")
            }
        case .yearly:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            let dateText = formatter.string(from: anchor)
            parts.append("\(intervalText) year\(interval == 1 ? "" : "s") on \(dateText)")
        }

        switch end {
        case .never:
            parts.append("Does not end")
        case .endDate(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("Ends \(formatter.string(from: date))")
        case .afterOccurrences(let count):
            parts.append("Ends after \(count) time\(count == 1 ? "" : "s")")
        }

        return parts.joined(separator: " • ")
    }

    func toRecurrenceRule(anchor: Date) -> EKRecurrenceRule? {
        guard isEnabled else { return nil }

        let endRule: EKRecurrenceEnd?
        switch end {
        case .never:
            endRule = nil
        case .endDate(let date):
            endRule = EKRecurrenceEnd(end: date)
        case .afterOccurrences(let count):
            endRule = EKRecurrenceEnd(occurrenceCount: count)
        }

        let frequency: EKRecurrenceFrequency
        switch self.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }

        let clampedInterval = max(interval, 1)

        switch self.frequency {
        case .weekly:
            let days = selectedWeekdays.sorted { $0.rawValue < $1.rawValue }
                .map { EKRecurrenceDayOfWeek(Weekday.toEKDay($0)) }
            return EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: clampedInterval,
                daysOfTheWeek: days.isEmpty ? nil : days,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: endRule
            )
        case .monthly:
            switch monthlyPattern {
            case .dayOfMonth(let day):
                return EKRecurrenceRule(
                    recurrenceWith: frequency,
                    interval: clampedInterval,
                    daysOfTheWeek: nil,
                    daysOfTheMonth: [NSNumber(value: day)],
                    monthsOfTheYear: nil,
                    weeksOfTheYear: nil,
                    daysOfTheYear: nil,
                    setPositions: nil,
                    end: endRule
                )
            case .weekdayOrdinal(let ordinal):
                let day = EKRecurrenceDayOfWeek(Weekday.toEKDay(ordinal.weekday), weekNumber: ordinal.ordinal)
                return EKRecurrenceRule(
                    recurrenceWith: frequency,
                    interval: clampedInterval,
                    daysOfTheWeek: [day],
                    daysOfTheMonth: nil,
                    monthsOfTheYear: nil,
                    weeksOfTheYear: nil,
                    daysOfTheYear: nil,
                    setPositions: nil,
                    end: endRule
                )
            }
        default:
            return EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: clampedInterval,
                end: endRule
            )
        }
    }

    static func defaultMonthlyPattern(for date: Date, calendar: Calendar = .current) -> MonthlyPattern {
        let day = calendar.component(.day, from: date)
        return .dayOfMonth(day)
    }
}

private extension Weekday {
    static func toEKDay(_ weekday: Weekday) -> EKWeekday {
        switch weekday {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }
}
