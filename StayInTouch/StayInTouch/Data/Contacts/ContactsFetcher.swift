//
//  ContactsFetcher.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Contacts
import Foundation

enum ContactsFetcherError: Error {
    case permissionDenied
    case permissionRestricted
    case contactNotFound(String)
    case fetchFailed(Error)

    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Access to contacts was denied. Please enable in Settings."
        case .permissionRestricted:
            return "Access to contacts is restricted."
        case .contactNotFound(let id):
            return "Contact with identifier \(id) not found."
        case .fetchFailed(let error):
            return "Failed to fetch contacts: \(error.localizedDescription)"
        }
    }
}

struct ContactSummary: Identifiable, Equatable {
    let id: String
    let identifier: String
    let displayName: String
    let initials: String

    init(identifier: String, displayName: String, initials: String) {
        self.id = identifier
        self.identifier = identifier
        self.displayName = displayName
        self.initials = initials
    }
}

enum ContactsFetcher {
    struct ContactInfo: Equatable {
        let phone: String?
        let email: String?
    }

    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        return await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    static func fetchAll() throws -> [ContactSummary] {
        // Check permission status first
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .denied:
            throw ContactsFetcherError.permissionDenied
        case .restricted:
            throw ContactsFetcherError.permissionRestricted
        case .notDetermined, .authorized:
            break
        @unknown default:
            break
        }

        let store = CNContactStore()
        let formatterKeys = CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            formatterKeys
        ]

        var results: [ContactSummary] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let displayName = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? contact.organizationName
                let initials = InitialsBuilder.initials(for: displayName)
                results.append(ContactSummary(
                    identifier: contact.identifier,
                    displayName: displayName,
                    initials: initials
                ))
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.contacts, context: "ContactsFetcher.fetchAll")
            throw ContactsFetcherError.fetchFailed(error)
        }

        return results
    }

    static func fetchContactInfo(identifier: String) throws -> ContactInfo {
        // Check permission status first
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .denied:
            throw ContactsFetcherError.permissionDenied
        case .restricted:
            throw ContactsFetcherError.permissionRestricted
        case .notDetermined, .authorized:
            break
        @unknown default:
            break
        }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        do {
            let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
            let phone = contact.phoneNumbers.first?.value.stringValue
            let email = contact.emailAddresses.first?.value as String?
            return ContactInfo(phone: phone, email: email)
        } catch let error as NSError {
            if error.domain == CNErrorDomain && error.code == CNError.recordDoesNotExist.rawValue {
                AppLogger.logWarning("Contact not found: \(identifier)", category: AppLogger.contacts)
                throw ContactsFetcherError.contactNotFound(identifier)
            }
            AppLogger.logError(error, category: AppLogger.contacts, context: "ContactsFetcher.fetchContactInfo")
            throw ContactsFetcherError.fetchFailed(error)
        }
    }
}
