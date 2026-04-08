//
//  ContactsFetcher.swift
//  KeepInTouch
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
    let nickname: String?
    let initials: String
    let birthday: Birthday?

    init(identifier: String, displayName: String, nickname: String? = nil, initials: String, birthday: Birthday? = nil) {
        self.id = identifier
        self.identifier = identifier
        self.displayName = displayName
        self.nickname = nickname
        self.initials = initials
        self.birthday = birthday
    }
}

enum ContactsFetcher {
    struct LabeledValue: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let value: String

        static func == (lhs: LabeledValue, rhs: LabeledValue) -> Bool {
            lhs.label == rhs.label && lhs.value == rhs.value
        }
    }

    struct ContactInfo: Equatable {
        let phoneNumbers: [LabeledValue]
        let emailAddresses: [LabeledValue]
        let birthday: DateComponents?

        var phone: String? { phoneNumbers.first?.value }
        var email: String? { emailAddresses.first?.value }
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
        case .notDetermined, .authorized, .limited:
            break
        @unknown default:
            break
        }

        let store = CNContactStore()
        let formatterKeys = CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            formatterKeys
        ]

        var results: [ContactSummary] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let displayName = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? contact.organizationName
                let nickname = contact.nickname.isEmpty ? nil : contact.nickname
                let initials = InitialsBuilder.initials(for: displayName)
                let birthday = contact.birthday.flatMap { Birthday.from(dateComponents: $0) }
                results.append(ContactSummary(
                    identifier: contact.identifier,
                    displayName: displayName,
                    nickname: nickname,
                    initials: initials,
                    birthday: birthday
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
        case .notDetermined, .authorized, .limited:
            break
        @unknown default:
            break
        }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]

        do {
            let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
            let phones = contact.phoneNumbers.map { labeled in
                let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: labeled.label ?? "")
                return LabeledValue(label: label, value: labeled.value.stringValue)
            }
            let emails = contact.emailAddresses.map { labeled in
                let label = CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? "")
                return LabeledValue(label: label, value: labeled.value as String)
            }
            return ContactInfo(phoneNumbers: phones, emailAddresses: emails, birthday: contact.birthday)
        } catch let error as NSError {
            if error.domain == CNErrorDomain && error.code == CNError.recordDoesNotExist.rawValue {
                AppLogger.logWarning("Contact not found: \(identifier)", category: AppLogger.contacts)
                throw ContactsFetcherError.contactNotFound(identifier)
            }
            AppLogger.logError(error, category: AppLogger.contacts, context: "ContactsFetcher.fetchContactInfo")
            throw ContactsFetcherError.fetchFailed(error)
        }
    }

    // MARK: - Name-Based Matching

    enum ContactMatchResult {
        case matched(personId: UUID, displayName: String, cnIdentifier: String)
        case multipleMatches(personId: UUID, displayName: String, matchCount: Int)
        case noMatch(personId: UUID, displayName: String)
    }

    static func matchByDisplayName(people: [(id: UUID, displayName: String)]) throws -> [ContactMatchResult] {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .denied:
            throw ContactsFetcherError.permissionDenied
        case .restricted:
            throw ContactsFetcherError.permissionRestricted
        case .notDetermined, .authorized, .limited:
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

        // Build lookup: normalized display name → [contact identifiers]
        var contactsByName: [String: [String]] = [:]
        let request = CNContactFetchRequest(keysToFetch: keys)
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let name = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? contact.organizationName
                let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else { return }
                contactsByName[normalized, default: []].append(contact.identifier)
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.contacts, context: "ContactsFetcher.matchByDisplayName")
            throw ContactsFetcherError.fetchFailed(error)
        }

        // Match each person
        var results: [ContactMatchResult] = []
        for person in people {
            let normalized = person.displayName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let matches = contactsByName[normalized] ?? []
            switch matches.count {
            case 0:
                results.append(.noMatch(personId: person.id, displayName: person.displayName))
            case 1:
                results.append(.matched(personId: person.id, displayName: person.displayName, cnIdentifier: matches[0]))
            default:
                results.append(.multipleMatches(personId: person.id, displayName: person.displayName, matchCount: matches.count))
            }
        }
        return results
    }

    static func fetchThumbnailImageData(identifier: String) -> Data? {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .denied, .restricted, .notDetermined:
            return nil
        case .authorized, .limited:
            break
        @unknown default:
            break
        }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [CNContactThumbnailImageDataKey as CNKeyDescriptor]

        guard let contact = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keys) else {
            return nil
        }
        return contact.thumbnailImageData
    }

    static func fetchBirthday(identifier: String) -> Birthday? {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .denied, .restricted, .notDetermined:
            return nil
        case .authorized, .limited:
            break
        @unknown default:
            break
        }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [CNContactBirthdayKey as CNKeyDescriptor]

        guard let contact = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keys) else {
            return nil
        }
        guard let dateComponents = contact.birthday else {
            return nil
        }
        return Birthday.from(dateComponents: dateComponents)
    }
}
