import SwiftUI
import CoreData
import Contacts

struct AddDriverView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var dataManager: SupabaseDataManager

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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        Task {
            await dataManager.createDriver(
                name: trimmedName,
                phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
                email: trimmedEmail.isEmpty ? nil : trimmedEmail,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    AddDriverView()
        .environmentObject(SupabaseDataManager.shared)
}
