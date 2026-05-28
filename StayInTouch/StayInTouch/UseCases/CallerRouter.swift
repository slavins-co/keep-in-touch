//
//  CallerRouter.swift
//  KeepInTouch
//

import Foundation

/// Pure URL builder for native calling actions: phone (`tel:`) and FaceTime
/// (`facetime:`). Mirrors `MessengerRouter`'s shape for the Call button side.
///
/// Phone uses a permissive digits+`+` filter (matching the native dialer's
/// own tolerance). FaceTime runs through `PhoneNormalizer` so the URL
/// always carries an E.164 number with the `+` prefix FaceTime expects.
enum CallerRouter {
    /// Builds a `tel:<digits>` URL for the native phone dialer.
    static func telURL(phone: String) -> URL? {
        guard let digits = PhoneNormalizer.dialableDigits(phone),
              let encoded = digits.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "tel:\(encoded)")
    }

    /// Builds a `facetime://+<E.164>` URL. Returns `nil` when the phone
    /// can't be normalized (empty / all-garbage input).
    static func faceTimeURL(
        phone: String,
        defaultRegion: String? = Locale.current.region?.identifier
    ) -> URL? {
        guard let normalized = PhoneNormalizer.normalize(phone, defaultRegion: defaultRegion),
              let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "facetime://+\(encoded)")
    }
}
