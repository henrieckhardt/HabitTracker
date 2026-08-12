import XCTest
import SwiftData
import FamilyControls
@testable import HabitTracker

final class DataExportServiceTests: XCTestCase {
    private func makeContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testExportIncludesEveryEntityType() throws {
        let context = makeContext()
        let habit = Habit(title: "Read", recurrenceRule: .daily)
        context.insert(habit)
        context.insert(HabitCompletion(date: .now, habit: habit))
        context.insert(ToDo(title: "Buy milk", scheduledDate: .now))
        let session = FocusSession(title: "Deep Work", startTime: .now, endTime: .now, isOnDemand: true, durationMinutes: 30)
        context.insert(session)
        context.insert(FocusRun(sessionID: session.id, sessionTitle: session.title, startedAt: .now, plannedEnd: .now))
        try context.save()

        let export = DataExportService.makeExport(context: context)

        XCTAssertEqual(export.habits.count, 1)
        XCTAssertEqual(export.habits.first?.completions.count, 1)
        XCTAssertEqual(export.toDos.count, 1)
        XCTAssertEqual(export.focusSessions.count, 1)
        XCTAssertEqual(export.focusRuns.count, 1)
    }

    func testEncodeDecodeRoundTripsExactly() throws {
        // Whole-second timestamps, not `.now` — plain ISO-8601 (no
        // fractional-seconds option) truncates sub-second precision, so a
        // `Date` with a fractional component wouldn't compare equal to
        // itself after an encode/decode round trip regardless of whether
        // `DataExportService` does anything wrong.
        let wholeSecond = Date(timeIntervalSince1970: 1_700_000_000)
        let context = makeContext()
        let habit = Habit(title: "Read", recurrenceRule: .weekdays([.monday, .wednesday]), createdAt: wholeSecond)
        context.insert(habit)
        context.insert(HabitCompletion(date: wholeSecond, completedAt: wholeSecond, habit: habit))
        try context.save()

        let export = DataExportService.makeExport(context: context, exportedAt: wholeSecond)
        let data = try XCTUnwrap(DataExportService.encode(export))
        let decoded = try XCTUnwrap(DataExportService.decode(data))

        XCTAssertEqual(export, decoded)
    }

    func testExportedJSONNeverMentionsBlockedSelection() throws {
        let context = makeContext()
        let session = FocusSession(title: "Deep Work", startTime: .now, endTime: .now)
        // `FamilyActivitySelection` itself is freely constructible — only
        // presenting the *picker* UI requires Screen Time authorization —
        // so this is a legitimate, non-nil `blockedSelectionData` without
        // needing any entitlement in the test target.
        session.blockedSelection = FamilyActivitySelection()
        context.insert(session)
        try context.save()

        let export = DataExportService.makeExport(context: context)
        let data = try XCTUnwrap(DataExportService.encode(export))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.lowercased().contains("blockedselection"))
    }

    func testExportURLWritesAReadableJSONFile() throws {
        let context = makeContext()
        context.insert(Habit(title: "Read", recurrenceRule: .daily))
        try context.save()

        let url = try XCTUnwrap(DataExportService.exportURL(context: context))
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertNotNil(DataExportService.decode(data))
    }
}
