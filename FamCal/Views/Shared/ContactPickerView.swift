import SwiftUI
import Contacts

struct ContactPickerView: View {
    @Binding var availableContacts: [Contact]
    @Binding var isLoading: Bool
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    let onSelectContact: (Contact) -> Void

    @State private var searchText = ""

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return availableContacts
        }
        return availableContacts.filter { $0.displayName.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color(red: 0.33, green: 0.33, blue: 0.33))
                        Text("Loading Contacts...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else if availableContacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text("No Contacts")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("No contacts available in your device")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(filteredContacts) { contact in
                            Button(action: { onSelectContact(contact) }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    if let phone = contact.primaryPhone {
                                        HStack(spacing: 6) {
                                            Image(systemName: "phone.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                            Text(phone)
                                                .font(.system(size: 13))
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    if let email = contact.primaryEmail {
                                        HStack(spacing: 6) {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                            Text(email)
                                                .font(.system(size: 13))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts")
            .onAppear {
                loadContacts()
            }
        }
    }

    private func loadContacts() {
        isLoading = true

        Task {
            let hasAccess = await ContactsManager.shared.requestContactsAccess()

            if hasAccess {
                do {
                    let contacts = try ContactsManager.shared.fetchAllContacts()
                    await MainActor.run {
                        self.availableContacts = contacts
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.showingError = true
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Access to contacts is required to select from your contacts. Please enable it in Settings > FamCal > Contacts."
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContactPickerView(
        availableContacts: .constant([
            Contact(from: createTestContact(name: "John Smith", phone: "555-1234", email: "john@example.com")),
            Contact(from: createTestContact(name: "Jane Doe", phone: "555-5678", email: "jane@example.com"))
        ]),
        isLoading: .constant(false),
        showingError: .constant(false),
        errorMessage: .constant(""),
        onSelectContact: { _ in }
    )
}

private func createTestContact(name: String, phone: String, email: String) -> CNContact {
    let contact = CNMutableContact()
    let components = name.split(separator: " ")
    if components.count >= 1 {
        contact.givenName = String(components[0])
    }
    if components.count >= 2 {
        contact.familyName = String(components[1])
    }

    let phoneNumber = CNPhoneNumber(stringValue: phone)
    let phoneNumberLabel = CNLabeledValue<CNPhoneNumber>(label: CNLabelPhoneNumberMobile, value: phoneNumber)
    contact.phoneNumbers = [phoneNumberLabel]

    let emailLabel = CNLabeledValue<NSString>(label: CNLabelWork, value: email as NSString)
    contact.emailAddresses = [emailLabel]

    return contact.copy() as! CNContact
}
