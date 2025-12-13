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
    // Default to the "Grouped" option (index 1) as requested
    @State private var selectedDesign = 1
    
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


// MARK: - Design Option 2: "Grouped Functionality" (User Preferred)
struct DesignOption2: View {
    @State private var title = "Dinner with Grandparents"
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var allDay = false
    @State private var location = "123 Family Lane"
    @State private var meetingLink = ""
    @State private var notes = ""
    @State private var selectedDriver: MockDriver?
    
    // Recurrence State
    @State private var repeatSelection = "Does not repeat" // Visual label
    @State private var showCustomRepeatSheet = false
    
    @State private var showAsOption = "Busy"
    @State private var selectedCalendar = mockCalendars[0]
    @State private var selectedMembers: Set<UUID> = [mockMembers[0].id] // Pre-select one
    @State private var alertOption = "15 min before"
    
    var body: some View {
        NavigationView {
             ScrollView {
                VStack(spacing: 16) {
                    // Header Card (Title, Location, Link)
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Event Title", text: $title)
                            .font(.system(size: 22, weight: .semibold))
                            .padding()
                        
                        Divider().padding(.leading, 16)
                        
                        QuickRow(icon: "location.fill", title: "Location", showChevron: false, color: .red) {
                            TextField("Add Location", text: $location)
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                        }
                        
                        Divider().padding(.leading, 44)
                        
                        QuickRow(icon: "link", title: "Meeting Link", showChevron: false) {
                            TextField("https://...", text: $meetingLink)
                                .keyboardType(.URL)
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    // "When" Card (Time, AllDay, Repeat)
                    VStack(spacing: 0) {
                         // All Day Toggle (Using QuickRow for consistent sizing)
                        QuickRow(icon: "clock", title: "All-day", showChevron: false) {
                            Toggle("", isOn: $allDay)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .scaleEffect(0.8) // Make toggle slightly smaller to fit better
                        }
                        
                        Divider().padding(.leading, 44)
                        
                        // Starts
                        QuickRow(icon: "calendar", title: "Starts", showChevron: false) {
                            HStack(spacing: 8) {
                                DatePicker("", selection: $startDate, displayedComponents: [.date])
                                    .labelsHidden()
                                    .fixedSize()
                                
                                if !allDay {
                                    DatePicker("", selection: $startDate, displayedComponents: [.hourAndMinute])
                                        .labelsHidden()
                                        .fixedSize()
                                }
                            }
                            // Force date pickers to not expand vertical space
                            .scaleEffect(0.9) 
                        }
                        
                        Divider().padding(.leading, 44)
                        
                        // Ends
                        if !allDay {
                            QuickRow(icon: "calendar", title: "Ends", showChevron: false) {
                                HStack(spacing: 8) {
                                    DatePicker("", selection: $endDate, displayedComponents: [.date])
                                        .labelsHidden()
                                        .fixedSize()
                                    
                                    DatePicker("", selection: $endDate, displayedComponents: [.hourAndMinute])
                                        .labelsHidden()
                                        .fixedSize()
                                }
                                .scaleEffect(0.9)
                            }
                            Divider().padding(.leading, 44)
                        }
                        
                        // Repeat Setup
                        QuickRow(icon: "repeat", title: "Repeat", color: .purple) {
                            Menu {
                                Button("Does not repeat") { repeatSelection = "Does not repeat" }
                                Divider()
                                Button("Every day") { repeatSelection = "Every day" }
                                Button("Every week") { repeatSelection = "Every week" }
                                Button("Every month") { repeatSelection = "Every month" }
                                Button("Every year") { repeatSelection = "Every year" }
                                Divider()
                                Button("Custom...") { showCustomRepeatSheet = true }
                            } label: {
                                Text(repeatSelection).foregroundColor(.primary)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // "Who & Status" Card
                     VStack(spacing: 0) {
                        // Calendar Picker
                        QuickRow(icon: "calendar.badge.clock", title: "Calendar") {
                            Menu {
                                ForEach(mockCalendars) { cal in
                                    Button(action: { selectedCalendar = cal }) {
                                        HStack {
                                            Text(cal.title)
                                            if selectedCalendar.id == cal.id { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Circle().fill(selectedCalendar.color).frame(width: 8, height: 8)
                                    Text(selectedCalendar.title).foregroundColor(.primary)
                                }
                            }
                        }
                         
                        Divider().padding(.leading, 44)
                         
                         // Attendees Multi-Select
                         QuickRow(icon: "person.2.fill", title: "Attendees", color: .orange) {
                             Menu {
                                 Button(action: {
                                     // Toggle All Logic
                                     if selectedMembers.count == mockMembers.count { selectedMembers.removeAll() }
                                     else { selectedMembers = Set(mockMembers.map { $0.id }) }
                                 }) {
                                     Text(selectedMembers.count == mockMembers.count ? "Deselect All" : "Select Everyone")
                                 }
                                 Divider()
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
                                 Text(selectedMembers.isEmpty ? "None" : (selectedMembers.count == mockMembers.count ? "Everyone" : "\(selectedMembers.count) Selected"))
                                     .foregroundColor(.primary)
                             }
                         }
                        
                        Divider().padding(.leading, 44)
                         
                         // Driver Single Select
                        QuickRow(icon: "car.fill", title: "Driver", color: .green) {
                            Menu {
                                Button("None") { selectedDriver = nil }
                                ForEach(mockDrivers) { driver in
                                    Button(action: { selectedDriver = driver }) {
                                        HStack {
                                            Text(driver.name)
                                            if selectedDriver?.id == driver.id { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                Text(selectedDriver?.name ?? "None").foregroundColor(.primary)
                            }
                        }
                        
                        // Travel Time (Conditional)
                        if selectedDriver != nil {
                            Divider().padding(.leading, 44)
                            QuickRow(icon: "clock.fill", title: "Travel Time", color: .green) {
                                Menu {
                                    ForEach([5, 15, 30, 45, 60], id: \.self) { min in
                                        Button("\(min) Minutes") { /* Mock update */ }
                                    }
                                } label: {
                                    HStack {
                                        Text("15 min").foregroundColor(.primary)
                                        Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                         
                        Divider().padding(.leading, 44)
                         
                        QuickRow(icon: "bell.fill", title: "Alert", color: .red) {
                            Menu {
                                Button("None") { alertOption = "None" }
                                Button("At time of event") { alertOption = "At time of event" }
                                Button("15 min before") { alertOption = "15 min before" }
                                Button("1 hour before") { alertOption = "1 hour before" }
                            } label: {
                                Text(alertOption).foregroundColor(.primary)
                            }
                        }
                         
                         Divider().padding(.leading, 44)
                         
                         QuickRow(icon: "briefcase.fill", title: "Show As", color: .gray) {
                             Menu {
                                 Button("Busy") { showAsOption = "Busy" }
                                 Button("Free") { showAsOption = "Free" }
                             } label: {
                                 Text(showAsOption).foregroundColor(.primary)
                             }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // "Notes" Card
                     VStack(alignment: .leading, spacing: 10) {
                         Text("Notes")
                             .font(.subheadline.weight(.semibold))
                             .foregroundColor(.secondary)
                         
                         TextEditor(text: $notes)
                             .frame(height: 100)
                             .font(.subheadline)
                             .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                             )
                     }
                     .padding()
                     .background(Color(.systemBackground))
                     .cornerRadius(12)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Event")
             .navigationBarTitleDisplayMode(.inline)
             .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") {} }
                ToolbarItem(placement: .confirmationAction) { Button("Add") {} }
            }
            .sheet(isPresented: $showCustomRepeatSheet) {
                MockCustomRepeatSheet(selection: $repeatSelection)
            }
        }
    }
}

// MARK: - Mocks for Sheets
// MARK: - Mocks for Sheets
struct MockCustomRepeatSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selection: String
    @State private var frequency = "Weekly"
    @State private var interval = 1
    @State private var hasEndDate = false
    @State private var endDate = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Main Recurrence Card
                    VStack(spacing: 0) {
                        // Frequency
                        QuickRow(icon: "arrow.clockwise", title: "Frequency", color: .purple) {
                            Menu {
                                Button("Daily") { frequency = "Daily" }
                                Button("Weekly") { frequency = "Weekly" }
                                Button("Monthly") { frequency = "Monthly" }
                                Button("Yearly") { frequency = "Yearly" }
                            } label: {
                                HStack {
                                    Text(frequency).foregroundColor(.primary)
                                    Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                        
                        Divider().padding(.leading, 44)
                        
                        // Interval (Every X Weeks)
                        QuickRow(icon: "number", title: "Every", showChevron: false, color: .purple) {
                            HStack {
                                Text("\(interval) \(frequency.lowercased().dropLast(2))(s)")
                                    .foregroundColor(.primary)
                                Stepper("", value: $interval, in: 1...999)
                                    .labelsHidden()
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // End Date Card
                    VStack(spacing: 0) {
                        QuickRow(icon: "calendar.badge.exclamationmark", title: "End Date", showChevron: false, color: .red) {
                            Toggle("", isOn: $hasEndDate)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        
                        if hasEndDate {
                            Divider().padding(.leading, 44)
                            QuickRow(icon: "calendar", title: "Ends On", showChevron: false, color: .red) {
                                DatePicker("", selection: $endDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Custom Recurrence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selection = "Custom (\(frequency))"
                        dismiss()
                    }
                }
            }
        }
    }
}

    
// Option 1: Fidelity
struct DesignOption1: View {
    @State private var title = "Dinner with Grandparents"
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    
    var body: some View {
        // Placeholder for legacy option 1
        Text("Option 1 (Fidelity) - See Option 2 for refined Grouped view")
    }
}

// Option 3: Sectioned
struct DesignOption3: View {
    var body: some View {
        // Placeholder for legacy option 3
         Text("Option 3 (Sectioned) - See Option 2 for refined Grouped view")
    }
}

// MARK: - Preview Logic
struct EventFormPrototypingView_Previews: PreviewProvider {
    static var previews: some View {
        EventFormPrototypingView()
    }
}
