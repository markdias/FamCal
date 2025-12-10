//
//  EventFormPrototypingView.swift
//  FamCal
//
//  Created for Prototyping purposes.
//  Do not include in production build unless finalized.
//

import SwiftUI
import MapKit

// MARK: - Mocks for Prototyping
private struct MockCalendar: Identifiable, Hashable {
    let idString: String
    var id: String { idString }
    let title: String
    let color: Color
}

private struct MockMember: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
}

private struct MockDriver: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

private let mockCalendars = [
    MockCalendar(idString: "1", title: "Family", color: .blue),
    MockCalendar(idString: "2", title: "Work", color: .purple),
    MockCalendar(idString: "3", title: "Kids", color: .orange)
]

private let mockMembers = [
    MockMember(name: "Dad", color: .blue),
    MockMember(name: "Mom", color: .pink),
    MockMember(name: "Timmy", color: .green)
]

private let mockDrivers = [
    MockDriver(name: "Dad"),
    MockDriver(name: "Mom"),
    MockDriver(name: "Nanny")
]

// MARK: - Main Prototyping View
struct EventFormPrototypingView: View {
    @State private var selectedDesign = 0
    
    var body: some View {
        TabView(selection: $selectedDesign) {
            DesignOption1()
                .tabItem { Label("Fidelity", systemImage: "1.circle") }
                .tag(0)
            
            DesignOption2()
                .tabItem { Label("Grouped", systemImage: "2.circle") }
                .tag(1)
            
            DesignOption3()
                .tabItem { Label("Sectioned", systemImage: "3.circle") }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Shared Components matching EventDetailView Style
struct QuickRow<Content: View>: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let color: Color
    @ViewBuilder let content: () -> Content

    init(icon: String, title: String, showChevron: Bool = true, color: Color = .blue, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.showChevron = showChevron
        self.color = color
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            content()
                .font(.subheadline)
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Design Option 1: "High Fidelity"
// Maps fields exactly to where they appear in the Read-Only View, inserting new fields (Meeting, Show As) into logical slots within that same structure.
struct DesignOption1: View {
    @State private var title = "Dinner with Grandparents"
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var location = "123 Family Lane"
    @State private var meetingLink = ""
    @State private var selectedCalendar = mockCalendars[0]
    @State private var selectedMembers: Set<UUID> = []
    @State private var selectedDriver: MockDriver?
    @State private var travelTime = 15
    @State private var repeatOption = "None"
    @State private var alertOption = "15 min before"
    @State private var showAs = "Busy"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    // 1. Primary Info Card (Title, Time, Location, Repeat)
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Event Title", text: $title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        // Date & Time
                        HStack(spacing: 16) {
                            Label {
                                DatePicker("", selection: $startDate, displayedComponents: [.date])
                                    .labelsHidden()
                            } icon: {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                            }
                            
                            Label {
                                DatePicker("", selection: $startDate, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                            } icon: {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.subheadline)
                        
                        // Location
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.red)
                                .frame(width: 20) // Align with Label icons
                            TextField("Add Location", text: $location)
                                .font(.subheadline)
                        }
                        
                        // Meeting Link (New Field)
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            TextField("Add Meeting Link", text: $meetingLink)
                                .font(.subheadline)
                                .keyboardType(.URL)
                        }

                        // Repeat (New Field in Title Card context)
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(.purple)
                                .frame(width: 20)
                            Menu {
                                Button("None") { repeatOption = "None" }
                                Button("Daily") { repeatOption = "Daily" }
                                Button("Weekly") { repeatOption = "Weekly" }
                            } label: {
                                Text(repeatOption)
                                    .foregroundColor(.primary)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // 2. Action Grid Card
                    VStack(spacing: 0) {
                        // Calendar
                        QuickRow(icon: "calendar.badge.clock", title: "Calendar") {
                            Menu {
                                ForEach(mockCalendars) { cal in
                                    Button(cal.title) { selectedCalendar = cal }
                                }
                            } label: {
                                HStack {
                                    Circle().fill(selectedCalendar.color).frame(width: 8, height: 8)
                                    Text(selectedCalendar.title).foregroundColor(.primary)
                                }
                            }
                        }
                        
                        Divider().padding(.leading, 44)
                        
                        // Driver
                        QuickRow(icon: "car.fill", title: "Driver") {
                            Menu {
                                Button("None") { selectedDriver = nil }
                                ForEach(mockDrivers) { driver in
                                    Button(driver.name) { selectedDriver = driver }
                                }
                            } label: {
                                Text(selectedDriver?.name ?? "None")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Divider().padding(.leading, 44)
                        
                        // Alert
                        QuickRow(icon: "bell.fill", title: "Alert") {
                            Menu {
                                Button("None") { alertOption = "None" }
                                Button("15 min before") { alertOption = "15 min before" }
                            } label: {
                                Text(alertOption).foregroundColor(.primary)
                            }
                        }
                        
                        Divider().padding(.leading, 44)

                        // Attendees
                         QuickRow(icon: "person.2.fill", title: "Attendees") {
                             Menu {
                                 ForEach(mockMembers) { member in
                                     Button(action: {
                                         if selectedMembers.contains(member.id) { selectedMembers.remove(member.id) }
                                         else { selectedMembers.insert(member.id) }
                                     }) {
                                         HStack {
                                             Text(member.name)
                                             if selectedMembers.contains(member.id) { Image(systemName: "checkmark") }
                                         }
                                     }
                                 }
                             } label: {
                                 Text(selectedMembers.isEmpty ? "None" : "\(selectedMembers.count) Selected")
                                     .foregroundColor(.primary)
                             }
                         }
                        
                        Divider().padding(.leading, 44)

                        // Show As (New)
                        QuickRow(icon: "briefcase.fill", title: "Show As", color: .gray) {
                             Menu {
                                 Button("Busy") { showAs = "Busy" }
                                 Button("Free") { showAs = "Free" }
                             } label: {
                                 Text(showAs).foregroundColor(.primary)
                             }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // 3. Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: .constant("Don't forget the gift!"))
                            .frame(height: 80)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Design Option 2: "Grouped Functionality"
// Similar aesthetic, but groups "When" (Time/Repeat), "Where" (Location/Link), and "Who" (Calendar/People/Driver) into separate cards.
struct DesignOption2: View {
    @State private var title = ""
    @State private var startDate = Date()
    @State private var location = ""
    @State private var selectedDriver: MockDriver?
    
    var body: some View {
        NavigationView {
             ScrollView {
                VStack(spacing: 16) {
                    // Header Card (Title only)
                    VStack(alignment: .leading) {
                         TextField("Event Title", text: $title)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    // "When" Card
                    VStack(spacing: 0) {
                        QuickRow(icon: "calendar", title: "Starts", showChevron: false) {
                            DatePicker("", selection: $startDate).labelsHidden()
                        }
                        Divider().padding(.leading, 44)
                        QuickRow(icon: "calendar", title: "Ends", showChevron: false) {
                             DatePicker("", selection: $startDate).labelsHidden()
                        }
                        Divider().padding(.leading, 44)
                        QuickRow(icon: "repeat", title: "Repeat", color: .purple) {
                            Text("Weekly")
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // "Where" Card
                    VStack(spacing: 0) {
                        QuickRow(icon: "location.fill", title: "Location", showChevron: false, color: .red) {
                            TextField("Add Location", text: $location)
                                .multilineTextAlignment(.trailing)
                        }
                         Divider().padding(.leading, 44)
                        QuickRow(icon: "link", title: "Meeting Link", showChevron: false) {
                            TextField("https://...", text: .constant(""))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .background(Color(.systemBackground))
                     .cornerRadius(12)
                    
                    // "Who & How" Card
                     VStack(spacing: 0) {
                        QuickRow(icon: "calendar.badge.clock", title: "Calendar") { Text("Family") }
                        Divider().padding(.leading, 44)
                        QuickRow(icon: "person.2.fill", title: "Attendees") { Text("Everyone") }
                        Divider().padding(.leading, 44)
                        QuickRow(icon: "car.fill", title: "Driver") { Text("None") }
                         Divider().padding(.leading, 44)
                        QuickRow(icon: "bell.fill", title: "Alert") { Text("15 min before") }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Event")
             .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// MARK: - Design Option 3: "Expanded Card"
// Uses the Card aesthetic but expands the rows slightly to be more touch-friendly and "Form-like" while keeping the blue icons/white background.
struct DesignOption3: View {
    @State private var title = ""
    @State private var startDate = Date()
    @State private var allDay = false
    
    var body: some View {
        NavigationView {
             ScrollView {
                VStack(spacing: 20) {
                    
                    // Title Input
                    TextField("Title", text: $title)
                        .font(.title3.weight(.medium))
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    
                    // Details Stack
                    VStack(spacing: 0) {
                        // Row 1: All Day
                        HStack {
                            Image(systemName: "clock").foregroundColor(.blue).frame(width: 24)
                            Toggle("All-day", isOn: $allDay)
                        }
                        .padding()
                        
                        Divider().padding(.leading, 50)
                        
                        // Row 2: Starts
                        HStack {
                            Text("Starts").padding(.leading, 40).foregroundColor(.secondary)
                            Spacer()
                            DatePicker("", selection: $startDate).labelsHidden()
                        }
                        .padding()
                        
                         Divider().padding(.leading, 50)
                        
                        // Row 3: Ends
                        HStack {
                            Text("Ends").padding(.leading, 40).foregroundColor(.secondary)
                            Spacer()
                            DatePicker("", selection: $startDate).labelsHidden()
                        }
                         .padding()
                        
                         Divider().padding(.leading, 50)

                         // Row 4: Repeat
                         HStack {
                             Image(systemName: "repeat").foregroundColor(.purple).frame(width: 24)
                             Text("Repeat")
                             Spacer()
                             Text("Never").foregroundColor(.secondary)
                         }
                         .padding()
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Configuration Stack
                    VStack(spacing: 0) {
                         // Calendar
                        HStack {
                             Image(systemName: "calendar.badge.clock").foregroundColor(.blue).frame(width: 24)
                             Text("Calendar")
                             Spacer()
                             Circle().fill(Color.blue).frame(width: 8, height: 8)
                             Text("Family").foregroundColor(.secondary)
                         }
                         .padding()
                        
                        Divider().padding(.leading, 50)
                        
                        // Location
                        HStack {
                             Image(systemName: "location.fill").foregroundColor(.red).frame(width: 24)
                             TextField("Add Location", text: .constant(""))
                         }
                         .padding()

                         Divider().padding(.leading, 50)
                        
                         // Attendees
                         HStack {
                             Image(systemName: "person.2.fill").foregroundColor(.orange).frame(width: 24)
                             Text("Attendees")
                             Spacer()
                             Text("Select").foregroundColor(.secondary)
                         }
                         .padding()
                        
                        Divider().padding(.leading, 50)
                        
                        // Driver
                        HStack {
                             Image(systemName: "car.fill").foregroundColor(.green).frame(width: 24)
                             Text("Driver")
                             Spacer()
                             Text("None").foregroundColor(.secondary)
                         }
                         .padding()
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
             .background(Color(.systemGroupedBackground))
             .navigationTitle("New Event")
             .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview Logic
struct EventFormPrototypingView_Previews: PreviewProvider {
    static var previews: some View {
        EventFormPrototypingView()
    }
}
