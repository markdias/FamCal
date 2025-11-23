import Foundation
import Contacts

class ContactsManager: NSObject {
    static let shared = ContactsManager()

    enum ContactsError: LocalizedError {
        case accessDenied
        case noContacts
        case fetchFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Access to contacts is denied. Please enable it in Settings."
            case .noContacts:
                return "No contacts found."
            case .fetchFailed(let message):
                return "Failed to fetch contacts: \(message)"
            }
        }
    }

    /// Request access to contacts
    func requestContactsAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            do {
                return try await CNContactStore().requestAccess(for: .contacts)
            } catch {
                print("Error requesting contacts access: \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }

    /// Get current authorization status for contacts
    func getContactsAuthorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Fetch all contacts with phone and email
    func fetchAllContacts() throws -> [Contact] {
        let contactStore = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var contacts: [Contact] = []
        do {
            try contactStore.enumerateContacts(with: request) { cnContact, _ in
                let contact = Contact(from: cnContact)
                if !contact.name.isEmpty {
                    contacts.append(contact)
                }
            }
            return contacts
        } catch {
            throw ContactsError.fetchFailed(error.localizedDescription)
        }
    }

    /// Search contacts by name
    func searchContacts(query: String) throws -> [Contact] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return try fetchAllContacts()
        }

        let allContacts = try fetchAllContacts()
        let lowercaseQuery = query.lowercased()

        return allContacts.filter { contact in
            contact.name.lowercased().contains(lowercaseQuery)
        }
    }
}

struct Contact: Identifiable {
    let id = UUID()
    let name: String
    let phones: [String]
    let emails: [String]

    init(from cnContact: CNContact) {
        let firstName = cnContact.givenName
        let lastName = cnContact.familyName
        self.name = ([firstName, lastName].filter { !$0.isEmpty }).joined(separator: " ")

        // Extract phone numbers
        self.phones = cnContact.phoneNumbers.compactMap { $0.value.stringValue }

        // Extract email addresses
        self.emails = cnContact.emailAddresses.compactMap { $0.value as String }
    }

    var displayName: String {
        return name
    }

    var primaryPhone: String? {
        return phones.first
    }

    var primaryEmail: String? {
        return emails.first
    }
}
