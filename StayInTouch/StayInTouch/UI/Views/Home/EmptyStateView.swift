//
//  EmptyStateView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let emoji: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, message: String, emoji: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.emoji = emoji
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 48))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }
}
