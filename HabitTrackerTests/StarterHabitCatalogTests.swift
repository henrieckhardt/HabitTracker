import XCTest
@testable import HabitTracker

final class StarterHabitCatalogTests: XCTestCase {
    func testCatalogIsNonEmptyWithUniqueIDsAndTitles() {
        let all = StarterHabitCatalog.all
        XCTAssertFalse(all.isEmpty)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(Set(all.map(\.title)).count, all.count)
    }

    func testEveryRecurrenceRuleIsValid() {
        for item in StarterHabitCatalog.all {
            switch item.recurrenceRule {
            case .daily:
                break
            case .weekdays(let days):
                XCTAssertFalse(days.isEmpty, "\(item.id) has an empty weekday set")
            case .monthly(let daysOfMonth):
                XCTAssertFalse(daysOfMonth.isEmpty, "\(item.id) has an empty day-of-month set")
                XCTAssertTrue(daysOfMonth.allSatisfy { (1...31).contains($0) }, "\(item.id) has an out-of-range day of month")
            }
        }
    }

    func testSortOrderIsStrictlyIncreasingAcrossTheCatalogOrder() {
        let baseline = Date.now
        let orders = (0..<StarterHabitCatalog.all.count).map { StarterHabitCatalog.sortOrder(for: $0, baseline: baseline) }
        for (previous, next) in zip(orders, orders.dropFirst()) {
            XCTAssertLessThan(previous, next)
        }
    }

    func testSortOrderIsDistinctForTheSameIndexAcrossDifferentBaselines() {
        let first = StarterHabitCatalog.sortOrder(for: 2, baseline: Date(timeIntervalSinceReferenceDate: 1000))
        let second = StarterHabitCatalog.sortOrder(for: 2, baseline: Date(timeIntervalSinceReferenceDate: 2000))
        XCTAssertNotEqual(first, second)
    }
}
