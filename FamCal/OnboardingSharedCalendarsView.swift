//
//  OnboardingSharedCalendarsView.swift
//  FamCal
//
//  Created by ChatGPT on 19/11/2025.
//

import SwiftUI
import CoreData

struct OnboardingSharedCalendarsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    var onNext: () -> Void

    @State private var showingAddSharedCalendar = false

    var body: some View {
        ZStack {
            OnboardingGradientBackground()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                OnboardingGlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 70))
                            .foregroundColor(.white)

                        Text("Share calendars")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Choose the calendars everyone should see so FamCal can spotlight what's next.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                OnboardingGlassCard {
                    if sharedCalendars.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 42))
                                .foregroundColor(.white)

                            Text("No shared calendars yet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Add the schedules your family relies on so everything is in one place.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(sharedCalendars, id: \.self) { calendar in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.fromHex(calendar.calendarColorHex ?? "#555555"))
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(calendar.calendarName ?? "Untitled")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)

                                        Text("Shared family calendar")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.7))
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 10)

                                if calendar.id != sharedCalendars.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                }

                VStack(spacing: 14) {
                    OnboardingPrimaryButton(title: "Add shared calendar") {
                        showingAddSharedCalendar = true
                    }

                    OnboardingSecondaryButton(
                        title: sharedCalendars.isEmpty ? "Skip for now" : "Continue",
                        action: onNext
                    )
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showingAddSharedCalendar) {
            AddSharedCalendarView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

#Preview {
    OnboardingSharedCalendarsView(onNext: {})
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
