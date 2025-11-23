import SwiftUI
import CoreData
import Contacts

struct AddDriverView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    @State private var showingContactPicker = false
    @State private var availableContacts: [Contact] = []
    @State private var isLoadingContacts = false
    @State private var showingContactError = false
    @State private var contactErrorMessage = ""

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
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
                            Text("Add from Contacts")
                                .foregroundColor(.blue)
                        }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDriver()
                    }
                    .disabled(!isFormValid)
                }
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
        }
    }

    private func saveDriver() {
        let newDriver = Driver(context: viewContext)
        newDriver.id = UUID()
        newDriver.name = name.trimmingCharacters(in: .whitespaces)
        newDriver.phone = phone.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phone
        newDriver.email = email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email
        newDriver.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes

        print("🚗 Saving driver: \(newDriver.name ?? "nil")")
        print("   Driver ID: \(newDriver.id?.uuidString ?? "nil")")
        print("   Context: \(viewContext)")
        print("   Has changes: \(viewContext.hasChanges)")

        do {
            try viewContext.save()
            print("✅ Driver saved successfully")

            // Verify save by fetching back
            let request = Driver.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", newDriver.id! as NSUUID)
            if let saved = try viewContext.fetch(request).first {
                print("✅ Verified: Driver \(saved.name ?? "nil") exists in database")
            }

            dismiss()
        } catch {
            print("❌ Failed to save driver: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   Error domain: \(nsError.domain)")
            print("   Error code: \(nsError.code)")
            print("   User info: \(nsError.userInfo)")
        }
    }
}

#Preview {
    AddDriverView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
