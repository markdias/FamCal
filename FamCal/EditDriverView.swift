import SwiftUI
import CoreData
import Contacts

struct EditDriverView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let driver: Driver

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    @State private var showingContactPicker = false
    @State private var availableContacts: [Contact] = []
    @State private var isLoadingContacts = false
    @State private var showingContactError = false
    @State private var contactErrorMessage = ""
    @State private var showingDeleteConfirmation = false

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Driver Information") {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                Button(action: { showingContactPicker = true }) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill.badge.plus")
                            .foregroundColor(.blue)
                        Text("Update from Contacts")
                            .foregroundColor(.blue)
                    }
                }
            }
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(height: 100)
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete Driver")
                    }
                }
            }
        }
        .navigationTitle("Edit Driver")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    updateDriver()
                }
                .disabled(!isFormValid)
            }
        }
        .alert("Delete Driver", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteDriver()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this driver? This action cannot be undone.")
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView(
                availableContacts: $availableContacts,
                isLoading: $isLoadingContacts,
                showingError: $showingContactError,
                errorMessage: $contactErrorMessage,
                onSelectContact: { contact in
                    name = contact.displayName
                    if let phone = contact.primaryPhone {
                        self.phone = phone
                    }
                    if let email = contact.primaryEmail {
                        self.email = email
                    }
                    showingContactPicker = false
                }
            )
        }
        .alert("Error", isPresented: $showingContactError) {
            Button("OK") { }
        } message: {
            Text(contactErrorMessage)
        }
        .onAppear {
            name = driver.name ?? ""
            phone = driver.phone ?? ""
            email = driver.email ?? ""
            notes = driver.notes ?? ""
        }
    }

    private func updateDriver() {
        driver.name = name.trimmingCharacters(in: .whitespaces)
        driver.phone = phone.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phone
        driver.email = email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email
        driver.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes

        print("🚗 Updating driver: \(driver.name ?? "nil")")
        print("   Driver ID: \(driver.id?.uuidString ?? "nil")")
        print("   Has changes: \(viewContext.hasChanges)")

        do {
            try viewContext.save()
            print("✅ Driver updated successfully")
            dismiss()
        } catch {
            print("❌ Failed to update driver: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   Error domain: \(nsError.domain)")
            print("   Error code: \(nsError.code)")
        }
    }

    private func deleteDriver() {
        viewContext.delete(driver)

        do {
            try viewContext.save()
            print("✅ Driver deleted successfully: \(driver.name ?? "Unknown")")
            dismiss()
        } catch {
            print("❌ Failed to delete driver: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   Error domain: \(nsError.domain)")
            print("   Error code: \(nsError.code)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let driver = Driver(context: context)
    driver.id = UUID()
    driver.name = "John Doe"
    driver.phone = "555-1234"
    driver.email = "john@example.com"
    driver.notes = "Prefers morning drives"

    return NavigationStack {
        EditDriverView(driver: driver)
            .environment(\.managedObjectContext, context)
    }
}
