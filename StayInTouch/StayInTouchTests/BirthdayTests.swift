//
//  BirthdayTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/1/26.
//

import XCTest
@testable import StayInTouch

final class BirthdayTests: XCTestCase {

    func testJsonRoundTrip() {
        let birthday = Birthday(month: 3, day: 15, year: 1990)
        let json = birthday.toJsonString()
        XCTAssertNotNil(json)

        let decoded = Birthday.from(jsonString: json!)
        XCTAssertEqual(decoded, birthday)
    }

    func testJsonRoundTripWithoutYear() {
        let birthday = Birthday(month: 12, day: 25, year: nil)
        let json = birthday.toJsonString()
        XCTAssertNotNil(json)

        let decoded = Birthday.from(jsonString: json!)
        XCTAssertEqual(decoded, birthday)
        XCTAssertNil(decoded?.year)
    }

    func testFormattedOutput() {
        XCTAssertEqual(Birthday(month: 3, day: 15, year: nil).formatted, "Mar 15")
        XCTAssertEqual(Birthday(month: 12, day: 1, year: 1990).formatted, "Dec 1")
        XCTAssertEqual(Birthday(month: 1, day: 31, year: nil).formatted, "Jan 31")
    }

    func testFromDateComponents() {
        var components = DateComponents()
        components.month = 7
        components.day = 4
        components.year = 1776

        let birthday = Birthday.from(dateComponents: components)
        XCTAssertEqual(birthday?.month, 7)
        XCTAssertEqual(birthday?.day, 4)
        XCTAssertEqual(birthday?.year, 1776)
    }

    func testFromDateComponentsWithoutYear() {
        var components = DateComponents()
        components.month = 2
        components.day = 29

        let birthday = Birthday.from(dateComponents: components)
        XCTAssertEqual(birthday?.month, 2)
        XCTAssertEqual(birthday?.day, 29)
        XCTAssertNil(birthday?.year)
    }

    func testFromDateComponentsMissingMonthReturnsNil() {
        var components = DateComponents()
        components.day = 15

        XCTAssertNil(Birthday.from(dateComponents: components))
    }

    func testFromDateComponentsMissingDayReturnsNil() {
        var components = DateComponents()
        components.month = 3

        XCTAssertNil(Birthday.from(dateComponents: components))
    }

    func testFromInvalidJsonReturnsNil() {
        XCTAssertNil(Birthday.from(jsonString: "not json"))
        XCTAssertNil(Birthday.from(jsonString: ""))
        XCTAssertNil(Birthday.from(jsonString: "{}"))
    }
}
