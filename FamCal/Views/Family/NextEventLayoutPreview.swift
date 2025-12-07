//
//  NextEventLayoutPreview.swift
//  FamCal
//
//  Preview view to test different next event card layouts
//

import SwiftUI

struct NextEventLayoutPreview: View {
    @State private var selectedLayout: LayoutOption = .square

    enum LayoutOption: String, CaseIterable, Identifiable {
        case square = "Square 1:1"
        case rectangle = "Rectangle 3:2"
        case wide = "Wide 2:1"
        case golden = "Golden 1.6:1"
        case tall = "Tall 2:3"
        case dynamic = "Dynamic"
        case compact = "Compact"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .square: return "Current design - equal width & height"
            case .rectangle: return "Slightly wider - more horizontal space"
            case .wide: return "Very wide - emphasizes horizontal layout"
            case .golden: return "Golden ratio - aesthetically balanced"
            case .tall: return "Portrait orientation - more vertical space"
            case .dynamic: return "Height adjusts to content"
            case .compact: return "Minimal height - fits more on screen"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Layout description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedLayout.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(selectedLayout.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Layout selector
                    Menu {
                        ForEach(LayoutOption.allCases) { option in
                            Button {
                                selectedLayout = option
                            } label: {
                                Label(option.rawValue, systemImage: selectedLayout == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack {
                            Text("Layout Style")
                                .font(.headline)
                            Spacer()
                            Text(selectedLayout.rawValue)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    // Preview grid
                    Text("2 Columns")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(0..<2) { index in
                            sampleCard(layout: selectedLayout, index: index)
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.vertical)

                    Text("3 Columns")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(0..<3) { index in
                            sampleCard(layout: selectedLayout, index: index)
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.vertical)

                    Text("4 Columns")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(0..<4) { index in
                            sampleCard(layout: selectedLayout, index: index)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical)
            }
            .navigationTitle("Event Card Layouts")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func sampleCard(layout: LayoutOption, index: Int) -> some View {
        let titleSize: CGFloat = 14
        let detailSize: CGFloat = 12
        let barWidth: CGFloat = 4

        // Different sample data for each card
        let sampleData: [(name: String, event: String, date: String, time: String?, status: String, color: Color, location: String?)] = [
            ("John", "Team Meeting", "Today", "2:00 PM - 3:00 PM", "In 2h 30m", .blue, "Conference Room A"),
            ("Sarah", "Doctor Appointment", "Tomorrow", "9:00 AM - 10:00 AM", "Tomorrow at 9:00 AM", .green, nil),
            ("Emma", "School Presentation on Climate Change", "Today", "3:00 PM - 4:00 PM", "In Progress", .orange, "Room 204, Main Building"),
            ("Michael", "Soccer Practice", "Today", nil, "Starts in 45m", .purple, nil),
            ("Dad", "Business Conference Call with International Team", "Today", "4:30 PM - 5:30 PM", "In 3h", .red, nil),
            ("Mom", "Yoga Class", "Tomorrow", "6:00 PM - 7:00 PM", "Tomorrow at 6:00 PM", .teal, "Downtown Studio")
        ]

        let data = sampleData[index % sampleData.count]
        let barColor = data.color

        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))

            // Card content
            VStack(alignment: .leading, spacing: 6) {
                // Member name
                Text(data.name)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Event title
                Text(data.event)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                // Date
                Text(data.date)
                    .font(.system(size: detailSize, weight: .semibold))
                    .foregroundColor(.secondary)

                // Time (if available)
                if let time = data.time {
                    Text(time)
                        .font(.system(size: detailSize, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                // Location (if available and not in compact mode)
                if let location = data.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: detailSize - 1, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.system(size: detailSize, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Time until/remaining - directly below time (no bubble)
                Text(data.status)
                    .font(.system(size: detailSize, weight: .semibold))
                    .foregroundColor(data.color)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
        }
        .modifier(LayoutModifier(option: layout))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .overlay(
            // Left side bar
            Rectangle()
                .fill(barColor)
                .frame(width: barWidth)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 12
                ))
                .frame(maxHeight: .infinity, alignment: .center),
            alignment: .leading
        )
    }
}

struct LayoutModifier: ViewModifier {
    let option: NextEventLayoutPreview.LayoutOption

    func body(content: Content) -> some View {
        switch option {
        case .square:
            // Current implementation - square aspect ratio (1:1)
            content
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)

        case .rectangle:
            // 3:2 aspect ratio - slightly wider than tall
            content
                .aspectRatio(3/2, contentMode: .fill)
                .frame(maxWidth: .infinity)

        case .wide:
            // 2:1 aspect ratio - much wider, like a landscape card
            content
                .aspectRatio(2, contentMode: .fill)
                .frame(maxWidth: .infinity)

        case .golden:
            // Golden ratio (1.618:1) - aesthetically pleasing proportion
            content
                .aspectRatio(1.618, contentMode: .fill)
                .frame(maxWidth: .infinity)

        case .tall:
            // 2:3 aspect ratio - taller than wide (portrait)
            content
                .aspectRatio(2/3, contentMode: .fill)
                .frame(maxWidth: .infinity)

        case .dynamic:
            // No fixed aspect ratio - let content determine height
            // Grid rows will automatically align to tallest card
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 120)

        case .compact:
            // Compact fixed height - fits more cards on screen
            content
                .frame(maxWidth: .infinity)
                .frame(height: 100)
        }
    }
}

#Preview {
    NextEventLayoutPreview()
}
