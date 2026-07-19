import XCTest
@testable import PetitesDents

final class CalendarAgeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCamillesExampleUsesFullCalendarMonths() throws {
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2025, month: 10, day: 2))
        )
        let eventDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )

        XCTAssertEqual(
            CalendarAgeCalculator.between(
                birthDate: birthDate,
                eventDate: eventDate,
                calendar: calendar
            ),
            CalendarAge(months: 9, days: 16)
        )
    }

    func testEndOfMonthUsesCalendarAnniversary() throws {
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 31))
        )
        let eventDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2025, month: 2, day: 28))
        )

        XCTAssertEqual(
            CalendarAgeCalculator.between(
                birthDate: birthDate,
                eventDate: eventDate,
                calendar: calendar
            ),
            CalendarAge(months: 1, days: 0)
        )
    }

    func testLeapDayToFollowingFebruaryIsTwelveMonths() throws {
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))
        )
        let eventDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2025, month: 2, day: 28))
        )

        XCTAssertEqual(
            CalendarAgeCalculator.between(
                birthDate: birthDate,
                eventDate: eventDate,
                calendar: calendar
            ),
            CalendarAge(months: 12, days: 0)
        )
    }

    func testEventBeforeBirthDateHasNoAge() throws {
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 19))
        )
        let eventDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )

        XCTAssertNil(
            CalendarAgeCalculator.between(
                birthDate: birthDate,
                eventDate: eventDate,
                calendar: calendar
            )
        )
    }

    func testCivilDatesRemainStableAcrossTimeZones() throws {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let birthSelection = try XCTUnwrap(
            paris.date(from: DateComponents(year: 2025, month: 10, day: 2))
        )
        let eventSelection = try XCTUnwrap(
            paris.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )
        let birthDate = CivilDate.normalized(birthSelection, sourceCalendar: paris)
        let eventDate = CivilDate.normalized(eventSelection, sourceCalendar: paris)

        XCTAssertEqual(
            CalendarAgeCalculator.between(birthDate: birthDate, eventDate: eventDate),
            CalendarAge(months: 9, days: 16)
        )

        for identifier in ["Pacific/Honolulu", "Pacific/Kiritimati"] {
            var displayCalendar = Calendar(identifier: .gregorian)
            displayCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
            let displayed = CivilDate.pickerDate(
                from: eventDate,
                displayCalendar: displayCalendar
            )
            let components = displayCalendar.dateComponents(
                [.year, .month, .day],
                from: displayed
            )
            XCTAssertEqual(components.year, 2026)
            XCTAssertEqual(components.month, 7)
            XCTAssertEqual(components.day, 18)
        }
    }
}
