//
//  EventPreferencesView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI

struct EventPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("eventsPerPerson") private var eventsPerPerson: Int = 3
    @AppStorage("spotlightEventsPerPerson") private var spotlightEventsPerPerson: Int = 5
    @AppStorage("eventsPastDays") private var eventsPastDays: Int = 90
    @AppStorage("eventsFutureDays") private var eventsFutureDays: Int = 180
    @AppStorage("defaultAlertOption") private var defaultAlertOptionRawValue: String = AlertOption.none.rawValue
    @AppStorage("spotlightShowGapsBetweenEvents") private var spotlightShowGapsBetweenEvents: Bool = true

    private var defaultAlertBinding: Binding<AlertOption> {
        Binding(
            get: { AlertOption(rawValue: defaultAlertOptionRawValue) ?? .none },
            set: { defaultAlertOptionRawValue = $0.rawValue }
        )
    }

    var body: some View {
        GlassyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Next Events
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Events")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Events per person")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                    Text("How many upcoming events to show")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }

                                Spacer()

                                Picker("Events", selection: $eventsPerPerson) {
                                    ForEach(1...10, id: \.self) { number in
                                        Text("\(number)").tag(number)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Spotlight events")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                    Text("Events to show in spotlight view")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }

                                Spacer()

                                Picker("Spotlight", selection: $spotlightEventsPerPerson) {
                                    ForEach(1...15, id: \.self) { number in
                                        Text("\(number)").tag(number)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .glassyCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // Event Date Range
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event Date Range")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Show past events")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                    Text("Days to look back")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }

                                Spacer()

                                Picker("Past Days", selection: $eventsPastDays) {
                                    Text("None").tag(0)
                                    Text("1 Month").tag(30)
                                    Text("2 Months").tag(60)
                                    Text("3 Months").tag(90)
                                    Text("6 Months").tag(180)
                                    Text("1 Year").tag(365)
                                }
                                .pickerStyle(.menu)
                                .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Look ahead")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                    Text("Days to look forward")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }

                                Spacer()

                                Picker("Future Days", selection: $eventsFutureDays) {
                                    Text("1 Month").tag(30)
                                    Text("3 Months").tag(90)
                                    Text("6 Months").tag(180)
                                    Text("1 Year").tag(365)
                                    Text("2 Years").tag(730)
                                }
                                .pickerStyle(.menu)
                                .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .glassyCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // Default Alert
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Events")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Default alert")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                    Text("Alert time for new events")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }

                                Spacer()

                                Picker("Default Alert", selection: defaultAlertBinding) {
                                    ForEach(AlertOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Spotlight gaps")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                    Text("Show time between same-day events")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }

                                Spacer()

                                Toggle("", isOn: $spotlightShowGapsBetweenEvents)
                                    .labelsHidden()
                                    .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .glassyCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Event Preferences")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : .primary)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : Color(red: 0.33, green: 0.33, blue: 0.33))
                }
            }
        }
    }
}

#Preview {
    EventPreferencesView()
        .environmentObject(ThemeManager())
}
