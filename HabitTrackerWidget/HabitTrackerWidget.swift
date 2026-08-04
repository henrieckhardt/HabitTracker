import WidgetKit
import SwiftUI
import SwiftData

struct WidgetItem: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let isCompleted: Bool
}

struct HabitTrackerWidgetEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
}

struct HabitTrackerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitTrackerWidgetEntry {
        HabitTrackerWidgetEntry(date: .now, items: [
            WidgetItem(id: UUID(), title: "Laufen", icon: "figure.run", isCompleted: false),
            WidgetItem(id: UUID(), title: "Einkaufen", icon: "checklist", isCompleted: true)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitTrackerWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitTrackerWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(3600)
        let periodicRefresh = Date.now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(min(nextMidnight, periodicRefresh))))
    }

    /// Opens its own short-lived SwiftData container against the same App
    /// Group store used by the main app and the Focus-blocking extensions —
    /// same schema-consistency requirement as those (see `AppGroup`).
    private func makeEntry() -> HabitTrackerWidgetEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        guard let container = try? ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self,
            configurations: AppGroup.makeModelConfiguration()
        ) else {
            return HabitTrackerWidgetEntry(date: .now, items: [])
        }
        let context = ModelContext(container)

        let habits = (try? context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let habitItems = habits
            .filter { !$0.isArchived && RecurrenceEngine.isScheduled($0.recurrenceRule, on: today, calendar: calendar) }
            .map { habit in
                WidgetItem(
                    id: habit.id,
                    title: habit.title,
                    icon: habit.icon,
                    isCompleted: habit.isCompleted(on: today, calendar: calendar)
                )
            }

        let toDos = (try? context.fetch(FetchDescriptor<ToDo>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let toDoItems = toDos
            .filter { calendar.isDate($0.scheduledDate, inSameDayAs: today) }
            .map { toDo in
                WidgetItem(id: toDo.id, title: toDo.title, icon: "checklist", isCompleted: toDo.isCompleted)
            }

        // Completed items sink to the bottom, keeping their relative order
        // otherwise — same convention as the Day View list.
        let items = (habitItems + toDoItems).sorted { !$0.isCompleted && $1.isCompleted }
        return HabitTrackerWidgetEntry(date: .now, items: items)
    }
}

struct HabitTrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitTrackerWidgetEntry

    private var visibleItems: [WidgetItem] {
        let limit = family == .systemSmall ? 3 : 6
        return Array(entry.items.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Heute")
                .font(.headline)

            if entry.items.isEmpty {
                Text("Nichts geplant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleItems) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? Color.accentColor : Color.secondary)
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.caption)
                }
                if entry.items.count > visibleItems.count {
                    Text("+\(entry.items.count - visibleItems.count) weitere")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HabitTrackerWidget: Widget {
    let kind = "HabitTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitTrackerWidgetProvider()) { entry in
            HabitTrackerWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Heute")
        .description("Zeigt deine heutigen Habits und ToDos.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
