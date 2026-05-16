//
//  PhoneNormalizerTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class PhoneNormalizerTests: XCTestCase {
    func testStripsFormattingFromUSNumberWithPlus() {
        XCTAssertEqual(
            PhoneNormalizer.normalize("+1 (415) 555-1212", defaultRegion: "US"),
            "14155551212"
        )
    }

    func testPrependsUSDialingCodeWhenMissing() {
        XCTAssertEqual(
            PhoneNormalizer.normalize("(415) 555-1212", defaultRegion: "US"),
            "14155551212"
        )
    }

    func testTrustsExplicitCountryCodeOverDefaultRegion() {
        // UK number with +44 should be preserved even when caller's region is US.
        XCTAssertEqual(
            PhoneNormalizer.normalize("+44 20 7946 0958", defaultRegion: "US"),
            "442079460958"
        )
    }

    func testPrependsUKDialingCodeWhenRegionIsGB() {
        XCTAssertEqual(
            PhoneNormalizer.normalize("020 7946 0958", defaultRegion: "GB"),
            "4402079460958"
        )
    }

    func testReturnsNilForEmptyInput() {
        XCTAssertNil(PhoneNormalizer.normalize("", defaultRegion: "US"))
        XCTAssertNil(PhoneNormalizer.normalize("   ", defaultRegion: "US"))
    }

    func testReturnsNilForNonNumericInput() {
        XCTAssertNil(PhoneNormalizer.normalize("hello", defaultRegion: "US"))
    }

    func testIdempotentOnAlreadyNormalizedDigitsWithPlus() {
        // "+14155551212" → "14155551212" → already a plain digits result.
        let once = PhoneNormalizer.normalize("+14155551212", defaultRegion: "US")
        XCTAssertEqual(once, "14155551212")
        let twice = PhoneNormalizer.normalize("+" + (once ?? ""), defaultRegion: "US")
        XCTAssertEqual(twice, "14155551212")
    }

    func testUnknownRegionReturnsDigitsWithoutCountryCode() {
        // ZZ is not a real region; we fall through and return digits only.
        XCTAssertEqual(
            PhoneNormalizer.normalize("5551212", defaultRegion: "ZZ"),
            "5551212"
        )
    }

    func testNilDefaultRegionReturnsDigitsOnly() {
        XCTAssertEqual(
            PhoneNormalizer.normalize("5551212", defaultRegion: nil),
            "5551212"
        )
    }
}
