//
//  MessengerRouterTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class MessengerRouterTests: XCTestCase {
    // MARK: - iMessage (sms:)

    func testiMessageProducesSmsUrl() {
        let url = MessengerRouter.url(for: .iMessage, phone: "+1 (415) 555-1212", defaultRegion: "US")
        XCTAssertEqual(url?.scheme, "sms")
        XCTAssertTrue(url?.absoluteString.contains("14155551212") ?? false)
    }

    func testiMessagePreservesPlusForRouting() {
        let url = MessengerRouter.url(for: .iMessage, phone: "+44 20 7946 0958", defaultRegion: "US")
        // sms: tolerates loose formatting; we keep digits and +.
        XCTAssertEqual(url?.scheme, "sms")
        XCTAssertTrue(url?.absoluteString.contains("+44") ?? false || url?.absoluteString.contains("4420") ?? false)
    }

    // MARK: - WhatsApp (https://wa.me/...)

    func testWhatsAppProducesWaMeUniversalLink() {
        let url = MessengerRouter.url(for: .whatsapp, phone: "+1 (415) 555-1212", defaultRegion: "US")
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "wa.me")
        XCTAssertEqual(url?.path, "/14155551212")
    }

    func testWhatsAppPrependsCountryCodeForLocalNumber() {
        let url = MessengerRouter.url(for: .whatsapp, phone: "415-555-1212", defaultRegion: "US")
        XCTAssertEqual(url?.absoluteString, "https://wa.me/14155551212")
    }

    func testWhatsAppRespectsExplicitInternationalNumber() {
        let url = MessengerRouter.url(for: .whatsapp, phone: "+44 20 7946 0958", defaultRegion: "US")
        XCTAssertEqual(url?.absoluteString, "https://wa.me/442079460958")
    }

    // MARK: - Signal (sgnl://signal.me/#p/+...)

    func testSignalProducesSgnlSignalMeLink() {
        let url = MessengerRouter.url(for: .signal, phone: "+1 (415) 555-1212", defaultRegion: "US")
        XCTAssertEqual(url?.scheme, "sgnl")
        XCTAssertTrue(url?.absoluteString.contains("signal.me") ?? false)
        XCTAssertTrue(url?.absoluteString.contains("14155551212") ?? false)
    }

    // MARK: - Failure cases

    func testReturnsNilForEmptyPhoneAcrossAllMessengers() {
        XCTAssertNil(MessengerRouter.url(for: .iMessage, phone: "", defaultRegion: "US"))
        XCTAssertNil(MessengerRouter.url(for: .whatsapp, phone: "", defaultRegion: "US"))
        XCTAssertNil(MessengerRouter.url(for: .signal, phone: "", defaultRegion: "US"))
    }

    func testReturnsNilForNonNumericPhoneAcrossAllMessengers() {
        XCTAssertNil(MessengerRouter.url(for: .iMessage, phone: "hello", defaultRegion: "US"))
        XCTAssertNil(MessengerRouter.url(for: .whatsapp, phone: "hello", defaultRegion: "US"))
        XCTAssertNil(MessengerRouter.url(for: .signal, phone: "hello", defaultRegion: "US"))
    }
}
