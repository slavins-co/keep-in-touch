//
//  MessengerAvailability.swift
//  KeepInTouch
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Reports which messengers are reachable from the device (installed and
/// declared in `LSApplicationQueriesSchemes`). Abstracted so ViewModels stay
/// UIKit-free and tests can inject fakes.
protocol MessengerAvailabilityChecking {
    func isAvailable(_ messenger: PreferredMessenger) -> Bool
}

extension MessengerAvailabilityChecking {
    /// Returns the messengers that are reachable from this device.
    /// iMessage is always considered available — `sms:` works through the
    /// system Messages app on iPhone; on iPad-without-cellular the
    /// `openURL` callback will surface a graceful failure.
    func availableMessengers() -> [PreferredMessenger] {
        PreferredMessenger.allCases.filter { isAvailable($0) }
    }
}

/// Production implementation backed by `UIApplication.canOpenURL`.
struct SystemMessengerAvailability: MessengerAvailabilityChecking {
    func isAvailable(_ messenger: PreferredMessenger) -> Bool {
        switch messenger {
        case .iMessage:
            return true
        case .whatsapp:
            return canOpen("whatsapp://")
        case .signal:
            return canOpen("sgnl://")
        }
    }

    private func canOpen(_ scheme: String) -> Bool {
        #if canImport(UIKit)
        guard let url = URL(string: scheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
        #else
        return false
        #endif
    }
}
