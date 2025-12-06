//
//  HelpView.swift
//  FamCal
//
//  Created by Claude on 21/11/2025.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundLayer().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Welcome Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Welcome to FamCal")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(primaryTextColor)

                            Text("Keep your family's calendar organized in one place. Add family members, sync their calendars, and never miss an important event.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(secondaryTextColor)
                                .lineSpacing(1.5)
                        }
                        .padding(16)
                        .background(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.cardStroke, lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)

                        // Getting Started Section
                        HelpSection(
                            title: "Getting Started",
                            icon: "star.fill",
                            items: [
                                HelpItem(
                                    title: "Add Family Members",
                                    description: "Go to Settings > Personal Calendars to add family members. Enter their name and FamCal will automatically link their iOS calendar."
                                ),
                                HelpItem(
                                    title: "View Family Events",
                                    description: "The Family tab displays upcoming events for all your family members. Tap any event to view details, edit, or delete it."
                                ),
                                HelpItem(
                                    title: "Switch Between Views",
                                    description: "Use the calendar icon to toggle between Family view (event list) and Calendar view (month/day layout) for different perspectives."
                                )
                            ]
                        )

                        // Managing Events Section
                        HelpSection(
                            title: "Creating & Managing Events",
                            icon: "pencil.circle.fill",
                            items: [
                                HelpItem(
                                    title: "Create New Events",
                                    description: "Tap the + button to create an event. Set the date, time, location, and select which family members will attend."
                                ),
                                HelpItem(
                                    title: "Edit or Delete Events",
                                    description: "Tap an event to open it, then use Edit or Delete buttons. For recurring events, choose to modify just this event or all future occurrences."
                                ),
                                HelpItem(
                                    title: "Quick Actions",
                                    description: "Long-press any event for quick actions: Duplicate, Move to a Different Calendar, or Delete. Recurring events show options for this event or all future events."
                                ),
                                HelpItem(
                                    title: "Assign Drivers",
                                    description: "When creating an event, assign a family member as the driver to coordinate transportation."
                                ),
                                HelpItem(
                                    title: "Add Locations & Notes",
                                    description: "Include event location for map preview and directions. Add notes for additional details or instructions."
                                )
                            ]
                        )

                        // Calendar Features Section
                        HelpSection(
                            title: "Calendar Views & Navigation",
                            icon: "calendar",
                            items: [
                                HelpItem(
                                    title: "Month & Day Views",
                                    description: "Switch between month view (overview) and day view (hourly schedule) to see events in your preferred layout."
                                ),
                                HelpItem(
                                    title: "Select & Navigate Dates",
                                    description: "Tap any date to select it. The selected date appears highlighted and creates new events for that day."
                                ),
                                HelpItem(
                                    title: "Search Events",
                                    description: "Use the search icon to find events by title, location, or attendee name. Helpful for quickly locating specific events."
                                )
                            ]
                        )

                        // Family Management Section
                        HelpSection(
                            title: "Managing Family Members",
                            icon: "person.2.fill",
                            items: [
                                HelpItem(
                                    title: "Link Multiple Calendars",
                                    description: "Each family member can have multiple calendars linked. Tap a member to expand and add additional calendars beyond the auto-matched one."
                                ),
                                HelpItem(
                                    title: "Edit Member Details",
                                    description: "Tap a family member to expand, then manage their calendars or change their name. Auto-linked calendars are marked with a lock icon."
                                ),
                                HelpItem(
                                    title: "Shared Calendars",
                                    description: "In Settings > Shared Calendars, add calendars shared with all family members (holidays, family events, etc.). These appear for everyone automatically."
                                )
                            ]
                        )

                        // Notifications Section
                        HelpSection(
                            title: "Notifications & Reminders",
                            icon: "bell.fill",
                            items: [
                                HelpItem(
                                    title: "Enable Notifications",
                                    description: "Go to Settings > Notifications to turn on event reminders. Notifications include event details, location, and family members attending."
                                ),
                                HelpItem(
                                    title: "Set Alert Timing",
                                    description: "Choose when to receive alerts: at event time, or 5/10/15/30 minutes, 1 hour, or 1 day before."
                                ),
                                HelpItem(
                                    title: "Get Directions",
                                    description: "Tap 'Get Directions' in a notification to see the event location on a map and plan your route."
                                ),
                                HelpItem(
                                    title: "Morning Briefs",
                                    description: "Enable morning briefs in Notifications settings to receive a daily summary of upcoming family events."
                                )
                            ]
                        )

                        // Customization Section
                        HelpSection(
                            title: "Customization & Settings",
                            icon: "slider.horizontal.3",
                            items: [
                                HelpItem(
                                    title: "Themes & Display",
                                    description: "Go to Settings > Themes to choose from multiple color schemes. Enable dark mode for dark theme support."
                                ),
                                HelpItem(
                                    title: "App Preferences",
                                    description: "Customize your default view (Family or Calendar), auto-refresh interval, and preferred maps app in Settings > App Settings."
                                ),
                                HelpItem(
                                    title: "Event Display Options",
                                    description: "In App Settings > Event Settings, control how many events to display per person and adjust the date range for past/future events."
                                ),
                                HelpItem(
                                    title: "Saved Locations",
                                    description: "Save frequently used addresses in Settings > Saved Places for quick selection when creating events (Pro feature)."
                                )
                            ]
                        )

                        // Tips & Tricks Section
                        HelpSection(
                            title: "Tips & Tricks",
                            icon: "lightbulb.fill",
                            items: [
                                HelpItem(
                                    title: "Recurring Events",
                                    description: "Create events that repeat daily, weekly, monthly, or yearly. Perfect for birthdays, recurring appointments, and team meetings."
                                ),
                                HelpItem(
                                    title: "Widget Support",
                                    description: "Add FamCal widgets to your home screen for quick access to upcoming events (Pro feature)."
                                ),
                                HelpItem(
                                    title: "Dark Mode Support",
                                    description: "FamCal automatically adapts to your device's dark mode setting for comfortable viewing anytime."
                                )
                            ]
                        )

                        // Troubleshooting Section
                        HelpSection(
                            title: "Troubleshooting",
                            icon: "wrench.and.screwdriver.fill",
                            items: [
                                HelpItem(
                                    title: "Calendar Not Found",
                                    description: "If a family member's calendar isn't auto-linked, verify they have a calendar on their device that matches their name exactly."
                                ),
                                HelpItem(
                                    title: "Events Not Showing",
                                    description: "Ensure the family member's calendar is linked properly. Check Event Settings to verify your date range includes the events you're looking for."
                                ),
                                HelpItem(
                                    title: "Notifications Not Working",
                                    description: "Verify notifications are enabled in Settings > Notifications and check that your device has notification permission granted for FamCal in iOS Settings."
                                ),
                                HelpItem(
                                    title: "Outdated Information",
                                    description: "Close and reopen the app to refresh. You can also adjust the auto-refresh interval in App Settings for more frequent updates."
                                )
                            ]
                        )

                        // Permissions & Privacy Section
                        HelpSection(
                            title: "Permissions & Privacy",
                            icon: "lock.shield.fill",
                            items: [
                                HelpItem(
                                    title: "Calendar Access",
                                    description: "FamCal requires access to your device calendars to display and create events. This permission is requested during initial setup."
                                ),
                                HelpItem(
                                    title: "Notification Permission",
                                    description: "Notifications are optional but recommended. You can enable or disable them anytime in Settings > Notifications."
                                ),
                                HelpItem(
                                    title: "Your Data Privacy",
                                    description: "All your family data stays on your device. FamCal never uploads, syncs, or shares your family information, calendars, or events."
                                )
                            ]
                        )

                        // Footer
                        VStack(alignment: .center, spacing: 8) {
                            Text("Need Help or Have Feedback?")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(primaryTextColor)

                            Text("Use the Feedback feature in Settings to report issues or suggest improvements.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(secondaryTextColor)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .background(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.cardStroke, lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Help")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Components

private struct HelpSection: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: String
    let icon: String
    let items: [HelpItem]
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(theme.accentColor)
                    .cornerRadius(8)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryTextColor)

                Spacer()
            }

            // Items
            VStack(alignment: .leading, spacing: 12) {
                ForEach(items, id: \.title) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(primaryTextColor)

                        Text(item.description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(secondaryTextColor)
                            .lineSpacing(1.2)
                    }

                    if item != items.last {
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(12)
            .background(theme.cardBackground.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .padding(16)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
    }
}

private struct HelpItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String

    static func == (lhs: HelpItem, rhs: HelpItem) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    HelpView()
        .environmentObject(ThemeManager())
}
