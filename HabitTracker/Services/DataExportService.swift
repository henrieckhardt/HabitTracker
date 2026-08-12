import Foundation
import SwiftData

/// Builds a full JSON snapshot of everything stored locally, for the
/// "Export Data" button in `SettingsView`. Read-only and non-destructive —
/// unlike `DataDeletionService`, ordering here doesn't matter since nothing
/// is mutated.
enum DataExportService {
    struct Export: Codable, Equatable {
        struct HabitDTO: Codable, Equatable {
            let id: UUID
            let title: String
            let icon: String
            let colorTag: String
            let recurrenceRule: RecurrenceRule
            let createdAt: Date
            let isArchived: Bool
            let completions: [HabitCompletionDTO]
        }
        struct HabitCompletionDTO: Codable, Equatable {
            let date: Date
            let completedAt: Date?
        }
        struct ToDoDTO: Codable, Equatable {
            let id: UUID
            let title: String
            let notes: String?
            let scheduledDate: Date
            let createdAt: Date
            let isCompleted: Bool
            let completedAt: Date?
            let startTime: Date?
            let endTime: Date?
        }
        // Deliberately no `blockedSelectionData`/`blockedSelection` field:
        // `FamilyActivitySelection` tokens are opaque and bound to this
        // specific install, so exporting them wouldn't produce anything
        // usable — not on re-import (there is none), not read by a human,
        // not portable to another device.
        struct FocusSessionDTO: Codable, Equatable {
            let id: UUID
            let title: String
            let startTime: Date
            let endTime: Date
            let recurrenceRule: RecurrenceRule
            let createdAt: Date
            let isArchived: Bool
            let isOnDemand: Bool
            let durationMinutes: Int
            let isBlockingEnabled: Bool
        }
        struct FocusRunDTO: Codable, Equatable {
            let id: UUID
            let sessionTitle: String
            let startedAt: Date
            let plannedEnd: Date
            let endedAt: Date?
            let wasEndedEarly: Bool
            let wasBlockingApps: Bool
            let linkedTitle: String?
        }

        let exportedAt: Date
        let habits: [HabitDTO]
        let toDos: [ToDoDTO]
        let focusSessions: [FocusSessionDTO]
        let focusRuns: [FocusRunDTO]
    }

    static func makeExport(context: ModelContext, exportedAt: Date = .now) -> Export {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let toDos = (try? context.fetch(FetchDescriptor<ToDo>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        let runs = (try? context.fetch(FetchDescriptor<FocusRun>())) ?? []

        return Export(
            exportedAt: exportedAt,
            habits: habits.map { habit in
                Export.HabitDTO(
                    id: habit.id,
                    title: habit.title,
                    icon: habit.icon,
                    colorTag: habit.colorTag,
                    recurrenceRule: habit.recurrenceRule,
                    createdAt: habit.createdAt,
                    isArchived: habit.isArchived,
                    completions: habit.completions.map {
                        Export.HabitCompletionDTO(date: $0.date, completedAt: $0.completedAt)
                    }
                )
            },
            toDos: toDos.map { toDo in
                Export.ToDoDTO(
                    id: toDo.id,
                    title: toDo.title,
                    notes: toDo.notes,
                    scheduledDate: toDo.scheduledDate,
                    createdAt: toDo.createdAt,
                    isCompleted: toDo.isCompleted,
                    completedAt: toDo.completedAt,
                    startTime: toDo.startTime,
                    endTime: toDo.endTime
                )
            },
            focusSessions: sessions.map { session in
                Export.FocusSessionDTO(
                    id: session.id,
                    title: session.title,
                    startTime: session.startTime,
                    endTime: session.endTime,
                    recurrenceRule: session.recurrenceRule,
                    createdAt: session.createdAt,
                    isArchived: session.isArchived,
                    isOnDemand: session.isOnDemand,
                    durationMinutes: session.durationMinutes,
                    isBlockingEnabled: session.isBlockingEnabled
                )
            },
            focusRuns: runs.map { run in
                Export.FocusRunDTO(
                    id: run.id,
                    sessionTitle: run.sessionTitle,
                    startedAt: run.startedAt,
                    plannedEnd: run.plannedEnd,
                    endedAt: run.endedAt,
                    wasEndedEarly: run.wasEndedEarly,
                    wasBlockingApps: run.wasBlockingApps,
                    linkedTitle: run.linkedTitle
                )
            }
        )
    }

    static func encode(_ export: Export) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(export)
    }

    static func decode(_ data: Data) -> Export? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Export.self, from: data)
    }

    /// Writes a fresh export to a temp file and returns its URL, for
    /// `ShareLink`. `nil` if encoding or the write itself fails.
    static func exportURL(context: ModelContext) -> URL? {
        guard let data = encode(makeExport(context: context)) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("habiz-export-\(Int(Date.now.timeIntervalSince1970))")
            .appendingPathExtension("json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
