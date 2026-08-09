import XCTest
@testable import HabitTracker

final class DisplayOrderReorderingTests: XCTestCase {
    func testBetweenTwoNeighborsReturnsMidpoint() {
        let result = DisplayOrderReordering.newSortOrder(before: 10, after: 20)
        XCTAssertEqual(result, 15)
    }

    func testAtStartWithNoBeforeNeighborReturnsAfterMinusOne() {
        let result = DisplayOrderReordering.newSortOrder(before: nil, after: 10)
        XCTAssertEqual(result, 9)
    }

    func testAtEndWithNoAfterNeighborReturnsBeforePlusOne() {
        let result = DisplayOrderReordering.newSortOrder(before: 10, after: nil)
        XCTAssertEqual(result, 11)
    }

    func testOnlyItemInListReturnsZero() {
        let result = DisplayOrderReordering.newSortOrder(before: nil, after: nil)
        XCTAssertEqual(result, 0)
    }

    func testRepeatedInsertionBetweenSameNeighborsConverges() {
        var before = 0.0
        let after = 10.0
        for _ in 0..<10 {
            before = DisplayOrderReordering.newSortOrder(before: before, after: after)
        }
        XCTAssertLessThan(before, after)
        XCTAssertGreaterThan(before, 0)
    }
}
