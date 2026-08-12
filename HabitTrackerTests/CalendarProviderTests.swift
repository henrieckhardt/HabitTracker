import XCTest
@testable import HabitTracker

final class CalendarProviderTests: XCTestCase {
    func testFirstWeekdayRoundTripsThroughTheBuiltCalendar() {
        XCTAssertEqual(CalendarProvider.calendar(firstWeekday: 1).firstWeekday, 1)
        XCTAssertEqual(CalendarProvider.calendar(firstWeekday: 2).firstWeekday, 2)
    }

    func testCurrentReflectsAppSettings() {
        let original = AppSettings.weekStartWeekday
        defer { AppSettings.weekStartWeekday = original }

        AppSettings.weekStartWeekday = 1
        XCTAssertEqual(CalendarProvider.current.firstWeekday, 1)

        AppSettings.weekStartWeekday = 2
        XCTAssertEqual(CalendarProvider.current.firstWeekday, 2)
    }

    func testBuildingACalendarDoesNotMutateAppSettings() {
        let original = AppSettings.weekStartWeekday
        defer { AppSettings.weekStartWeekday = original }

        AppSettings.weekStartWeekday = 2
        _ = CalendarProvider.calendar(firstWeekday: 1)
        XCTAssertEqual(AppSettings.weekStartWeekday, 2)
    }
}
