//
//  EventSearchView.swift
//  FamCal
//
//  Created by Codex on 21/11/2025.
//

import SwiftUI
import CoreData

struct EventSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @FetchRequest(
        entity: FamilyMemberCalendar.entity(),
        sortDescriptors: []
    )
    private var memberCalendarLinks: FetchedResults<FamilyMemberCalendar>

    @FetchRequest(
        entity: Checklist.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Checklist.createdAt, ascending: true)]
    )
    private var checklists: FetchedResults<Checklist>

    @State private var searchText: String = ""
    @State private var allEvents: [SearchEvent] = []
    @State private var isLoading = false
    @State private var selectedEvent: UpcomingCalendarEvent? = nil
    @State private var showingEventDetail = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func getChecklistData(for event: UpcomingCalendarEvent) -> (hasChecklist: Bool, progress: ChecklistProgress?) {
        // Use the same matching logic as FamilyView
        // Try to find a checklist that matches this event using multiple identifier strategies
        let checklist = checklists.first { candidate in
            guard candidate.deletedAt == nil, let checklistEventId = candidate.eventIdentifier else { return false }

            // Try direct match first (EventKit ID)
            if checklistEventId == event.id {
                return true
            }

            // Try stable identifier matching
            return ChecklistManager.canMatchEventIdentifier(
                checklistEventId,
                toEventKitID: event.id,
                eventTitle: event.title,
                startDate: event.startDate,
                calendarID: event.calendarID
            )
        }

        let progress = checklist.map { ChecklistManager.shared.getProgress(for: $0) }
        // Only show checklist if it has items (not empty)
        let hasChecklist = progress?.isEmpty == false
        return (hasChecklist, progress)
    }

    private var filteredEvents: [SearchEvent] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return allEvents.filter { $0.matches(query: trimmed) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                searchField
                content
            }
            .padding(20)
            .navigationTitle("Search Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: loadEvents)
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search title, person, or location", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading events from linked calendars…")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if filteredEvents.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                Text(searchText.isEmpty ? "Start typing to search your events" : "No matching events")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                if !searchText.isEmpty {
                    Text("Try another name, title, or location.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List {
                ForEach(filteredEvents) { result in
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            selectedEvent = result.event
                            showingEventDetail = true
                        }) {
                            resultRow(for: result)
                        }
                        .buttonStyle(.plain)

                        if let link = result.event.meetingLink,
                           let destination = MeetingLinkHelper.normalizedURL(from: link) {
                            Link(destination: destination) {
                                HStack(spacing: 6) {
                                    Image(systemName: "video.fill")
                                    Text(MeetingLinkHelper.displayLabel(for: link))
                                }
                                .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func resultRow(for result: SearchEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateFormatter.string(from: result.event.startDate))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)

            HStack(spacing: 6) {
                Text(result.event.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                if result.event.hasRecurrence {
                    RecurrenceIcon(color: Color(uiColor: result.event.calendarColor))
                }
            }

            DepartureRow(
                startDate: result.event.startDate,
                travelMinutes: result.event.travelTimeMinutes,
                timeRange: timeRange(for: result.event),
                fontSize: 12,
                iconColor: .orange,
                textColor: .gray
            )

            if let location = result.event.location, !location.isEmpty {
                Text(location)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(uiColor: result.event.calendarColor))
                    .frame(width: 8, height: 8)

                Text(result.event.calendarTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))

                if !result.owners.isEmpty {
                    Text("•")
                        .foregroundColor(.gray)
                    Text(result.owners.joined(separator: ", "))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                // Checklist indicator
                let checklistData = getChecklistData(for: result.event)
                if checklistData.hasChecklist, let progress = checklistData.progress {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.square")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(progress.displayString)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func timeRange(for event: UpcomingCalendarEvent) -> String {
        let start = Self.timeFormatter.string(from: event.startDate)
        let end = Self.timeFormatter.string(from: event.endDate)
        return "\(start) – \(end)"
    }

    private func loadEvents() {
        guard allEvents.isEmpty else { return }
        isLoading = true

        var calendarIDs: Set<String> = []
        var calendarOwners: [String: Set<String>] = [:]

        for link in memberCalendarLinks {
            guard let calendarID = link.calendarID else { continue }
            calendarIDs.insert(calendarID)
            if let member = link.familyMember {
                let name = member.name ?? "Unknown"
                calendarOwners[calendarID, default: []].insert(name)
            }
        }

        for member in familyMembers {
            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for sharedCal in sharedCals {
                    guard let calendarID = sharedCal.calendarID else { continue }
                    calendarIDs.insert(calendarID)
                    let name = member.name ?? "Unknown"
                    calendarOwners[calendarID, default: []].insert(name)
                }
            }
        }

        let fetchedEvents = CalendarManager.shared.fetchNextEvents(
            for: Array(calendarIDs),
            limit: 500,
            pastDays: appSettingsManager.eventsPastDays,
            futureDays: appSettingsManager.eventsFutureDays
        )

        allEvents = fetchedEvents
            .map { event in
                SearchEvent(
                    event: event,
                    owners: Array(calendarOwners[event.calendarID] ?? [])
                        .sorted()
                )
            }
            .sorted { $0.event.startDate < $1.event.startDate }

        isLoading = false
    }
}

private struct SearchEvent: Identifiable {
    let id = UUID()
    let event: UpcomingCalendarEvent
    let owners: [String]

    func matches(query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack: [String] = [
            event.title,
            event.location ?? "",
            event.meetingLink ?? "",
            event.calendarTitle,
            owners.joined(separator: " ")
        ]

        return haystack.contains { value in
            value.localizedCaseInsensitiveContains(query)
        }
    }
}
