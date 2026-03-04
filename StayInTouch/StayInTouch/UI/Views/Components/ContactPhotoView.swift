//
//  ContactPhotoView.swift
//  KeepInTouch
//

import SwiftUI

struct ContactPhotoView: View {
    let cnIdentifier: String?
    let displayName: String
    var avatarColor: String = ""
    var size: CGFloat = 36

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?

    var body: some View {
        SwiftUI.Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(InitialsBuilder.initials(for: displayName))
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(avatarTextColor)
                    .frame(width: size, height: size)
                    .background(avatarBackgroundColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: cnIdentifier) {
            image = await loadImage()
        }
    }

    private var avatarBackgroundColor: Color {
        guard !avatarColor.isEmpty else {
            return DS.Colors.accent.opacity(0.7)
        }
        return DS.Colors.avatarColors(for: avatarColor, scheme: colorScheme).background
    }

    private var avatarTextColor: Color {
        guard !avatarColor.isEmpty else {
            return .white
        }
        return DS.Colors.avatarColors(for: avatarColor, scheme: colorScheme).text
    }

    private func loadImage() async -> UIImage? {
        guard let cnIdentifier else { return nil }

        if let cached = ContactPhotoCache.image(for: cnIdentifier) {
            return cached
        }

        return await Task.detached(priority: .utility) {
            guard let data = ContactsFetcher.fetchThumbnailImageData(identifier: cnIdentifier),
                  let uiImage = UIImage(data: data) else {
                return nil
            }
            ContactPhotoCache.setImage(uiImage, for: cnIdentifier)
            return uiImage
        }.value
    }
}

private enum ContactPhotoCache {
    static let shared = NSCache<NSString, UIImage>()

    static func image(for identifier: String) -> UIImage? {
        shared.object(forKey: identifier as NSString)
    }

    static func setImage(_ image: UIImage, for identifier: String) {
        shared.setObject(image, forKey: identifier as NSString)
    }
}
