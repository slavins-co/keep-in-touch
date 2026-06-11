//
//  ContactsChangeObserver.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Contacts
import Foundation

@MainActor
final class ContactsChangeObserver {
    static let shared = ContactsChangeObserver()

    private var observer: NSObjectProtocol?
    private var syncTask: Task<Void, Never>?

    private init() {}

    func start() {
        // Remove existing observer first to prevent duplicates
        stop()

        observer = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleSync()
            }
        }
    }

    func stop() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        syncTask?.cancel()
        syncTask = nil
    }

    private func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                await ContactsSyncService.syncExistingContacts()
            } catch {
                // Task was cancelled or sleep failed
                AppLogger.logDebug("Sync task cancelled or failed: \(error.localizedDescription)", category: AppLogger.contacts)
            }
        }
    }

    // `isolated deinit` (SE-0371): cleanup touches MainActor-isolated state.
    isolated deinit {
        stop()
    }
}
