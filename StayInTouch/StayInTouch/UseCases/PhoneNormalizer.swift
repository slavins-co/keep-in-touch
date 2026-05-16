//
//  PhoneNormalizer.swift
//  KeepInTouch
//

import Foundation

/// Normalizes phone-number strings to digits-only with a country code, suitable
/// for messenger universal links (e.g. https://wa.me/14155551212).
///
/// This is deliberately lightweight — no libphonenumber. If the input starts
/// with `+`, we trust the digits that follow. If it doesn't, we prepend the
/// dialing code derived from `defaultRegion` (typically `Locale.current.region`).
///
/// Edge case: a US user messaging a UK contact whose stored number lacks
/// `+44` will get a `+1`-prefixed number — wrong, but a documented limitation.
/// Mitigation is contact-side: store numbers with explicit country code.
enum PhoneNormalizer {
    /// Returns E.164-style digits (no `+`) or `nil` if input has no extractable digits.
    /// - Parameters:
    ///   - raw: phone number as stored (any format).
    ///   - defaultRegion: ISO 3166-1 alpha-2 region code used to derive country
    ///     code when `raw` lacks an explicit `+` prefix. Defaults to the user's
    ///     current locale region.
    static func normalize(_ raw: String, defaultRegion: String? = Locale.current.region?.identifier) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hasExplicitCountryCode = trimmed.hasPrefix("+")
        let digits = trimmed.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        if hasExplicitCountryCode {
            return digits
        }
        guard let region = defaultRegion?.uppercased(),
              let dialingCode = dialingCode(forRegion: region) else {
            // Couldn't determine country code; return digits as-is.
            // The messenger link may still resolve for the user's own region.
            return digits
        }
        return dialingCode + digits
    }

    /// Minimal map of common region codes to dialing codes. Add entries as needed.
    private static func dialingCode(forRegion region: String) -> String? {
        switch region {
        case "US", "CA": return "1"
        case "GB": return "44"
        case "AU": return "61"
        case "DE": return "49"
        case "FR": return "33"
        case "ES": return "34"
        case "IT": return "39"
        case "NL": return "31"
        case "BE": return "32"
        case "CH": return "41"
        case "AT": return "43"
        case "SE": return "46"
        case "NO": return "47"
        case "DK": return "45"
        case "FI": return "358"
        case "IE": return "353"
        case "PT": return "351"
        case "MX": return "52"
        case "BR": return "55"
        case "AR": return "54"
        case "JP": return "81"
        case "KR": return "82"
        case "CN": return "86"
        case "IN": return "91"
        case "SG": return "65"
        case "HK": return "852"
        case "NZ": return "64"
        case "ZA": return "27"
        default: return nil
        }
    }
}
