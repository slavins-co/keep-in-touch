//
//  CallerRouterTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class CallerRouterTests: XCTestCase {
    // MARK: - tel: URL

    func testTelURLPreservesDigitsAndPlus() {
        let url = CallerRouter.telURL(phone: "+1 (415) 555-1212")
        XCTAssertEqual(url?.scheme, "tel")
        XCTAssertTrue(url?.absoluteString.contains("14155551212") ?? false)
    }

    func testTelURLReturnsNilForEmptyInput() {
        XCTAssertNil(CallerRouter.telURL(phone: ""))
    }

    func testTelURLReturnsNilForGarbage() {
        XCTAssertNil(CallerRouter.telURL(phone: "hello"))
    }

    // MARK: - facetime: URL

    func testFaceTimeURLProducesPlusE164() {
        let url = CallerRouter.faceTimeURL(phone: "+14155551212", defaultRegion: "US")
        XCTAssertEqual(url?.scheme, "facetime")
        XCTAssertTrue(url?.absoluteString.contains("+14155551212") ?? false)
    }

    func testFaceTimeURLPrependsCountryCodeForLocalNumber() {
        let url = CallerRouter.faceTimeURL(phone: "415-555-1212", defaultRegion: "US")
        XCTAssertEqual(url?.scheme, "facetime")
        XCTAssertTrue(url?.absoluteString.contains("+14155551212") ?? false)
    }

    func testFaceTimeURLReturnsNilForEmptyInput() {
        XCTAssertNil(CallerRouter.faceTimeURL(phone: "", defaultRegion: "US"))
    }

    func testFaceTimeURLReturnsNilForGarbage() {
        XCTAssertNil(CallerRouter.faceTimeURL(phone: "hello", defaultRegion: "US"))
    }
}
