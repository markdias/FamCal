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

                            Text("FamCal helps you keep track of your family's events and calendars in one place. Here's how to get the most out of the app.")
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
                            icon: "rocket.fill",
                            items: [
                                HelpItem(
                                    title: "Add Family Members",
                                    description: "Go to Settings > My Family to add your family members. Link them to their iOS calendars so their events appear in FamCal."
                                ),
                                HelpItem(
                                    title: "View Events",
                                    description: "The Family tab shows upcoming events for all your family members. Tap any event to see more details like time, location, and attendees."
                                ),
                                HelpItem(
                                    title: "Switch Views",
                                    description: "Use the calendar icon in the toolbar to switch between the Family view (event list) and Calendar view (month/day grid)."
                                )
                            ]
                        )

                        // Calendar Features Section
                        HelpSection(
                            title: "Calendar Features",
                            icon: "calendar",
                            items: [
                                HelpItem(
                                    title: "Month & Day Views",
                                    description: "Tap the grid icon to open the calendar. Switch between month view (see the full month) and day view (see hourly details)."
                                ),
                                HelpItem(
                                    title: "Select a Date",
                                    description: "Tap any date in the calendar to select it. The date will be highlighted with a blue circle."
                                ),
                                HelpItem(
                                    title: "Create Events",
                                    description: "Select a date, then tap the + button to create a new event. The selected date will automatically be used as the event start date."
                                ),
                                HelpItem(
                                    title: "View Event Details",
                                    description: "Tap any event in the calendar to see full details including time, location, and assigned driver."
                                )
                            ]
                        )

                        // Event Management Section
                        HelpSection(
                            title: "Managing Events",
                            icon: "pencil.circle.fill",
                            items: [
                                HelpItem(
                                    title: "Create Events",
                                    description: "Tap the + button from the Family view or Calendar view. Fill in the event details and select who should attend."
                                ),
                                HelpItem(
                                    title: "Edit Events",
                                    description: "Tap an event to view details, then tap Edit to make changes. You can update the time, location, attendees, and more."
                                ),
                                HelpItem(
                                    title: "Delete Events",
                                    description: "Open an event and tap the delete button. For recurring events, choose whether to delete just this event or all future occurrences."
                                ),
                                HelpItem(
                                    title: "Set Drivers",
                                    description: "When creating or editing an event, you can assign a driver. This helps organize who's responsible for transportation."
                                ),
                                HelpItem(
                                    title: "Quick Actions",
                                    description: "Long-press any event to see quick actions: Duplicate, Move to Calendar, or Delete with special options for recurring events."
                                )
                            ]
                        )

                        // Family Settings Section
                        HelpSection(
                            title: "Family Settings",
                            icon: "person.2.fill",
                            items: [
                                HelpItem(
                                    title: "Add Family Members",
                                    description: "Go to Settings > My Family. Tap 'Add Family Member' and enter their name. FamCal will automatically find their iOS calendar."
                                ),
                                HelpItem(
                                    title: "Link Calendars",
                                    description: "When you add a member, their matching iOS calendar is automatically linked. You can add more calendars for each member in the expanded view."
                                ),
                                HelpItem(
                                    title: "Edit Members",
                                    description: "Tap a family member to expand their details. You can edit their name, manage their calendars, or delete them."
                                ),
                                HelpItem(
                                    title: "Shared Calendars",
                                    description: "Add calendars that are shared with all family members (like holidays or family events) in Settings > App Settings > Shared Calendars."
                                )
                            ]
                        )

                        // Notifications Section
                        HelpSection(
                            title: "Notifications",
                            icon: "bell.fill",
                            items: [
                                HelpItem(
                                    title: "Event Reminders",
                                    description: "Enable notifications in Settings > Notifications. You'll get alerts before events with a map preview and directions option."
                                ),
                                HelpItem(
                                    title: "Set Alert Times",
                                    description: "When creating an event, choose a default alert time. Options include at time of event, 5/10/15/30 minutes, 1 hour, or 1 day before."
                                ),
                                HelpItem(
                                    title: "Get Directions",
                                    description: "Tap 'Get Directions' in a notification to open the map and get route information to an event location."
                                )
                            ]
                        )

                        // Customization Section
                        HelpSection(
                            title: "Customization",
                            icon: "slider.horizontal.3",
                            items: [
                                HelpItem(
                                    title: "App Settings",
                                    description: "Customize your experience in Settings > App Settings. Choose your default home screen, auto-refresh interval, and maps app."
                                ),
                                HelpItem(
                                    title: "Choose a Theme",
                                    description: "Select from multiple themes in App Settings > Display > Theme. Each theme has a unique color scheme and feel."
                                ),
                                HelpItem(
                                    title: "Dark Mode",
                                    description: "Toggle dark mode in App Settings > Display > Dark Mode to apply dark colors to your selected theme."
                                ),
                                HelpItem(
                                    title: "Event Display Options",
                                    description: "Control how many events to show per person, spotlight events, and how far back/ahead to look for events in Event Settings."
                                )
                            ]
                        )

                        // Tips & Tricks Section
                        HelpSection(
                            title: "Tips & Tricks",
                            icon: "lightbulb.fill",
                            items: [
                                HelpItem(
                                    title: "Search Events",
                                    description: "Use the search icon to find events by name, location, or attendee. Great for finding that one event quickly."
                                ),
                                HelpItem(
                                    title: "Recurring Events",
                                    description: "Create events that repeat daily, weekly, monthly, or yearly. Perfect for birthdays, recurring appointments, and regular activities."
                                ),
                                HelpItem(
                                    title: "Driver Events",
                                    description: "Assign family members as drivers. The app can automatically create separate driving events for coordinating transportation."
                                ),
                                HelpItem(
                                    title: "Saved Locations",
                                    description: "Save frequently used locations in App Settings > Saved Places for quick selection when creating events."
                                ),
                                HelpItem(
                                    title: "Event Notes",
                                    description: "Add notes to events for additional details like what to bring, special instructions, or important information."
                                )
                            ]
                        )

                        // Permissions Section
                        HelpSection(
                            title: "Permissions & Privacy",
                            icon: "lock.shield.fill",
                            items: [
                                HelpItem(
                                    title: "Calendar Access",
                                    description: "FamCal needs access to your device calendars to display events and create new ones. This is requested during setup."
                                ),
                                HelpItem(
                                    title: "Notification Permission",
                                    description: "Enable notifications to receive reminders about upcoming events. You can manage this in Settings > Notifications."
                                ),
                                HelpItem(
                                    title: "Privacy",
                                    description: "Your data stays on your device. FamCal doesn't upload or share your family information, calendars, or events."
                                )
                            ]
                        )

                        // Troubleshooting Section
                        HelpSection(
                            title: "Troubleshooting",
                            icon: "wrench.and.screwdriver.fill",
                            items: [
                                HelpItem(
                                    title: "Events Not Showing",
                                    description: "Make sure family members' calendars are properly linked in My Family. Check that events fall within your configured date range in Event Settings."
                                ),
                                HelpItem(
                                    title: "Calendar Not Found",
                                    description: "If a family member's calendar isn't found automatically, check that they have a calendar in their device that matches their name exactly."
                                ),
                                HelpItem(
                                    title: "Notifications Not Working",
                                    description: "Verify that notifications are enabled in Settings > Notifications and that you've granted notification permission in Settings > Permissions."
                                ),
                                HelpItem(
                                    title: "Refresh Issues",
                                    description: "If events seem out of date, try closing and reopening the app. You can also adjust the auto-refresh interval in App Settings."
                                )
                            ]
                        )

                        // Footer
                        VStack(alignment: .center, spacing: 8) {
                            Text("Need More Help?")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)

                            Text("For additional support or feature requests, please reach out to us.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
