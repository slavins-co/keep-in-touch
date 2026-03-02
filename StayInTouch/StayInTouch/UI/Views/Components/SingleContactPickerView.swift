//
//  SingleContactPickerView.swift
//  StayInTouch
//
//  Created by Claude on 3/2/26.
//

import ContactsUI
import SwiftUI

/// Presents CNContactPickerViewController imperatively from UIKit,
/// bypassing SwiftUI's sheet stack to avoid the known dismiss-cascade
/// issue where the picker's auto-dismiss propagates up and closes
/// parent sheets.
enum ContactPickerPresenter {
    static func present(onSelect: @escaping (String) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        // Walk to the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let picker = CNContactPickerViewController()
        let delegate = PickerDelegate(onSelect: onSelect)
        picker.delegate = delegate

        // Retain the delegate for the lifetime of the picker
        objc_setAssociatedObject(picker, &PickerDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        topVC.present(picker, animated: true)
    }

    private final class PickerDelegate: NSObject, CNContactPickerDelegate {
        static var associatedKey: UInt8 = 0

        let onSelect: (String) -> Void

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact.identifier)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Picker auto-dismisses; nothing to do
        }
    }
}
