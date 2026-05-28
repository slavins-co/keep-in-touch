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

    func testIsToday_returnsTrue_whenMonthAndDayMatchToday() {
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        let birthday = Birthday(month: today.month!, day: today.day!, year: nil)
        XCTAssertTrue(birthday.isToday)
    }

    func testIsToday_returnsFalse_whenMonthDiffers() {
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        let differentMonth = today.month! % 12 + 1  // wraps Dec→Jan, never equals today.month
        let birthday = Birthday(month: differentMonth, day: today.day!, year: nil)
        XCTAssertFalse(birthday.isToday)
    }

    func testIsToday_returnsFalse_whenDayDiffers() {
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        let differentDay = today.day! % 28 + 1  // wraps within safe day range, never equals today.day
        let birthday = Birthday(month: today.month!, day: differentDay, year: nil)
        XCTAssertFalse(birthday.isToday)
    }

    // MARK: - nextOccurrence / daysUntil (#329)

    private var gregorian: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testDaysUntil_isZero_whenBirthdayIsToday() {
        let ref = date(2026, 6, 15)
        let birthday = Birthday(month: 6, day: 15, year: 1990)
        XCTAssertEqual(birthday.daysUntil(from: ref, calendar: gregorian), 0)
    }

    func testDaysUntil_isOne_whenBirthdayIsTomorrow() {
        let ref = date(2026, 6, 15)
        let birthday = Birthday(month: 6, day: 16, year: nil)
        XCTAssertEqual(birthday.daysUntil(from: ref, calendar: gregorian), 1)
    }

    func testDaysUntil_isSeven_whenBirthdayIsAWeekAway() {
        let ref = date(2026, 6, 15)
        let birthday = Birthday(month: 6, day: 22, year: nil)
        XCTAssertEqual(birthday.daysUntil(from: ref, calendar: gregorian), 7)
    }

    func testDaysUntil_rollsOverYearEnd() {
        let ref = date(2026, 12, 30)
        let birthday = Birthday(month: 1, day: 2, year: nil)  // next year
        XCTAssertEqual(birthday.daysUntil(from: ref, calendar: gregorian), 3)
        let next = birthday.nextOccurrence(after: ref, calendar: gregorian)
        XCTAssertEqual(gregorian.dateComponents([.year, .month, .day], from: next).year, 2027)
    }

    func testDaysUntil_handlesBirthdayEarlierThisYear() {
        let ref = date(2026, 6, 15)
        let birthday = Birthday(month: 3, day: 1, year: nil)  // already passed → next year
        let next = birthday.nextOccurrence(after: ref, calendar: gregorian)
        let comps = gregorian.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(comps.year, 2027)
        XCTAssertEqual(comps.month, 3)
        XCTAssertEqual(comps.day, 1)
    }

    func testFeb29_fallsBackToFeb28_inNonLeapYear() {
        // 2026 is not a leap year. Feb 29 → Feb 28 (same month, not Mar 1).
        let ref = date(2026, 2, 1)
        let birthday = Birthday(month: 2, day: 29, year: 2000)
        let next = birthday.nextOccurrence(after: ref, calendar: gregorian)
        let comps = gregorian.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 28)
    }

    func testFeb29_afterFeb28_inNonLeapYear_rollsToNextYear() {
        // Reference is Mar 1 2026 — this year's Feb 28 already passed, so the
        // next observed birthday is Feb 28 2027 (2027 also non-leap).
        let ref = date(2026, 3, 1)
        let birthday = Birthday(month: 2, day: 29, year: nil)
        let next = birthday.nextOccurrence(after: ref, calendar: gregorian)
        let comps = gregorian.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(comps.year, 2027)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 28)
    }

    func testFeb29_landsOnFeb29_inLeapYear() {
        // 2028 is a leap year.
        let ref = date(2028, 2, 1)
        let birthday = Birthday(month: 2, day: 29, year: nil)
        let next = birthday.nextOccurrence(after: ref, calendar: gregorian)
        let comps = gregorian.dateComponents([.month, .day], from: next)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 29)
    }

    func testNextOccurrence_isStartOfDay() {
        let ref = date(2026, 6, 15).addingTimeInterval(13 * 3600)  // mid-afternoon
        let birthday = Birthday(month: 6, day: 20, year: nil)
        let next = birthday.nextOccurrence(after: ref, calendar: gregorian)
        XCTAssertEqual(next, gregorian.startOfDay(for: next))
    }
}
