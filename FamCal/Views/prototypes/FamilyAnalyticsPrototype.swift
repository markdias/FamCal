//
//  FamilyAnalyticsPrototype.swift
//  FamCal
//
//  Prototype B: Horizontal scroll of compact analytics cards for each family member
//  Displayed in FamilyView, shows at-a-glance free time percentage for today
//

import SwiftUI
import CoreData
import EventKit

struct FamilyAnalyticsPrototype: View {
    let familyMembers: [FamilyMember]
    var onMemberSelected: ((FamilyMember) -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: PersonalCalendar.entity(),
        sortDescriptors: []
    )
    private var personalCalendars: FetchedResults<PersonalCalendar>

    @State private var analytics: [UUID: TimeAnalytics] = [:]
    @State private var eventStore = EKEventStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Availability")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(familyMembers, id: \.id) { member in
                        compactAnalyticsCard(for: member)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func compactAnalyticsCard(for member: FamilyMember) -> some View {
        Button(action: {
            onMemberSelected?(member)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Member name
                Text(member.name ?? "Member")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Mini timeline
                miniTimeline(for: member)

                // Free time percentage
                if let memberAnalytics = analytics[member.id ?? UUID()] {
                    HStack(spacing: 4) {
                        Text("\(memberAnalytics.freePercentage)%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)

                        Text("free")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)

                        Text("Calculating...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 140)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            calculateAnalytics(for: member)
        }
    }

    private func miniTimeline(for member: FamilyMember) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))

                // Busy block representation
                if let memberAnalytics = analytics[member.id ?? UUID()] {
                    let busyPercentage = memberAnalytics.totalAvailableMinutes > 0
                        ? Double(memberAnalytics.busyMinutes) / Double(memberAnalytics.totalAvailableMinutes)
                        : 0

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.fromHex(member.colorHex ?? "#007AFF"))
                        .frame(width: geometry.size.width * busyPercentage)
                }
            }
        }
        .frame(height: 6)
    }

    private func calculateAnalytics(for member: FamilyMember) {
        let calculator = TimeAnalyticsCalculator()

        // Get wake/bed times from member settings
        let wakeHour = member.useCustomSchedule ? Int(member.wakeTimeHour) : 7
        let wakeMinute = member.useCustomSchedule ? Int(member.wakeTimeMinute) : 0
        let bedHour = member.useCustomSchedule ? Int(member.bedTimeHour) : 22
        let bedMinute = member.useCustomSchedule ? Int(member.bedTimeMinute) : 0

        // Fetch all events from shared and personal calendars
        let calendarEvents = fetchAllEventsForMember(member)

        // Calculate analytics for today
        let todayAnalytics = calculator.calculate(
            for: member.id ?? UUID(),
            date: Date(),
            wakeTime: (hour: wakeHour, minute: wakeMinute),
            bedTime: (hour: bedHour, minute: bedMinute),
            events: calendarEvents
        )

        analytics[member.id ?? UUID()] = todayAnalytics
    }

    /// Fetches all events from shared and personal calendars for the given member
    private func fetchAllEventsForMember(_ member: FamilyMember) -> [UpcomingCalendarEvent] {
        let localCalendars = eventStore.calendars(for: .event)
        let calendarById = Dictionary(uniqueKeysWithValues: localCalendars.map { ($0.calendarIdentifier, $0) })
        let calendarByTitle = Dictionary(grouping: localCalendars, by: { $0.title }).mapValues { $0.first! }

        var calendarIDs = Set<String>()

        // Personal calendars (linked to this member's family member record)
        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
            for cal in memberCals {
                if let storedID = cal.calendarID {
                    var resolvedID = storedID
                    if calendarById[storedID] == nil, let name = cal.calendarName, let localCal = calendarByTitle[name] {
                        resolvedID = localCal.calendarIdentifier
                    }
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        // Shared calendars (family calendars shared with this member)
        if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
            for cal in sharedCals {
                if let storedID = cal.calendarID {
                    var resolvedID = storedID
                    if calendarById[storedID] == nil, let name = cal.calendarName, let localCal = calendarByTitle[name] {
                        resolvedID = localCal.calendarIdentifier
                    }
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        // Personal calendars - only include if this member is the logged-in user
        if let linkedMemberId = appSettingsManager.linkedFamilyMemberId,
           member.id?.uuidString.lowercased() == linkedMemberId.lowercased() {
            for personalCal in personalCalendars {
                // Only include if toggled for family view
                let shouldInclude = personalCal.showInSpotlight
                guard shouldInclude else { continue }

                var resolvedID: String?
                if let storedID = personalCal.calendarID {
                    resolvedID = storedID
                    if calendarById[storedID] == nil, let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                        resolvedID = localCal.calendarIdentifier
                    }
                } else if let name = personalCal.calendarName, let localCal = calendarByTitle[name] {
                    resolvedID = localCal.calendarIdentifier
                }

                if let resolvedID {
                    calendarIDs.insert(resolvedID)
                }
            }
        }

        guard !calendarIDs.isEmpty else { return [] }

        // Fetch all events
        let upcomingEvents = CalendarManager.shared.fetchNextEvents(
            for: Array(calendarIDs),
            limit: 0,
            pastDays: appSettingsManager.eventsPastDays,
            futureDays: appSettingsManager.eventsFutureDays
        )

        return upcomingEvents.map { event in
            UpcomingCalendarEvent(
                id: event.id,
                title: event.title,
                location: event.location,
                meetingLink: event.meetingLink,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarID: event.calendarID,
                calendarColor: event.calendarColor,
                calendarTitle: event.calendarTitle,
                hasRecurrence: event.hasRecurrence,
                recurrenceRule: nil,
                isAllDay: event.isAllDay
            )
        }
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    let appSettings = AppSettingsManager()

    let member1 = FamilyMember(context: context)
    member1.id = UUID()
    member1.name = "John"
    member1.colorHex = "#FF6B6B"
    member1.wakeTimeHour = 7
    member1.bedTimeHour = 22
    member1.useCustomSchedule = false

    let member2 = FamilyMember(context: context)
    member2.id = UUID()
    member2.name = "Sarah"
    member2.colorHex = "#4ECDC4"
    member2.wakeTimeHour = 6
    member2.bedTimeHour = 23
    member2.useCustomSchedule = true

    return FamilyAnalyticsPrototype(
        familyMembers: [member1, member2]
    )
    .environment(\.managedObjectContext, context)
    .environmentObject(appSettings)
    .padding()
}
