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

    init(
        title: String,
        notes: String? = nil,
        scheduledDate: Date,
        createdAt: Date = .now,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
