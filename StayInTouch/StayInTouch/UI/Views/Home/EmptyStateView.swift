//
//  EmptyStateView.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var emoji: String = ""
    var systemImage: String = ""
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, message: String, emoji: String = "", systemImage: String = "", actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.emoji = emoji
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            if !systemImage.isEmpty {
                Image(systemName: systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(DS.Colors.tertiaryText)
            } else if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 44))
            }

            Text(title)
                .font(DS.Typography.title)

            Text(message)
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(DS.Colors.accent)
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(.horizontal)
    }
}
