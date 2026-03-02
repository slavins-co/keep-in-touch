//
//  SingleContactPickerView.swift
//  StayInTouch
//
//  Created by Claude on 3/2/26.
//

import ContactsUI
import SwiftUI

struct SingleContactPickerView: UIViewControllerRepresentable {
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (String) -> Void
        let onCancel: () -> Void

        init(onSelect: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact.identifier)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}
