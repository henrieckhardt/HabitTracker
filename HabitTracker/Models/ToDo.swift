import Foundation
import SwiftData

@Model
final class ToDo {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var scheduledDate: Date = Date.now
    var createdAt: Date = Date.now
    var isCompleted: Bool = false
    var completedAt: Date?
    var reminderTime: Date?

    /// Optional, purely informational time window — only hour/minute matter,
    /// same convention as `FocusSession.startTime`/`endTime`. Never touches
    /// `NotificationService` or any app-blocking mechanism; ToDos are one-off
    /// (no recurrence), unlike `Habit`/`FocusSession`.
    var startTime: Date?
    var endTime: Date?

    init(
        title: String,
        notes: String? = nil,
        scheduledDate: Date,
        createdAt: Date = .now,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        reminderTime: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.reminderTime = reminderTime
        self.startTime = startTime
        self.endTime = endTime
    }
}
