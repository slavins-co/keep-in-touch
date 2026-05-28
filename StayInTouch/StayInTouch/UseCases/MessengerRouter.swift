//
//  MessengerRouter.swift
//  KeepInTouch
//

import Foundation

/// Pure URL builder mapping a chosen messenger + phone number to the
/// URL that should be passed to `UIApplication.open(_:)`.
///
/// - iMessage uses the native `sms:` scheme (no E.164 normalization required).
/// - WhatsApp uses the universal link `https://wa.me/<digits>`. If WhatsApp
///   is not installed, iOS hands the link to Safari which renders WhatsApp's
///   own fallback page — no `canOpenURL` check needed at call sites.
/// - Signal uses `sgnl://signal.me/#p/+<E164>`. Custom scheme, so if not
///   installed `openURL(_:completionHandler:)` returns `accepted=false`.
enum MessengerRouter {
    /// Returns a URL to open for the chosen messenger + phone, or `nil` if the
    /// phone can't be normalized into something the messenger will accept.
    /// - Parameters:
    ///   - messenger: chosen messenger.
    ///   - phone: raw phone string as stored in the user's contacts.
    ///   - defaultRegion: region used to derive country code for non-`+`
    ///     prefixed numbers. Defaults to the user's current locale region.
    static func url(
        for messenger: PreferredMessenger,
        phone: String,
        defaultRegion: String? = Locale.current.region?.identifier
    ) -> URL? {
        switch messenger {
        case .iMessage:
            // Native sms: tolerates loose formatting; no E.164 normalization.
            guard let digits = PhoneNormalizer.dialableDigits(phone),
                  let encoded = digits.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return nil
            }
            return URL(string: "sms:\(encoded)")

        case .whatsapp:
            guard let normalized = PhoneNormalizer.normalize(phone, defaultRegion: defaultRegion),
                  let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return nil
            }
            return URL(string: "https://wa.me/\(encoded)")

        case .signal:
            guard let normalized = PhoneNormalizer.normalize(phone, defaultRegion: defaultRegion),
                  let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return nil
            }
            return URL(string: "sgnl://signal.me/#p/+\(encoded)")
        }
    }
}
