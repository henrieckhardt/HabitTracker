import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct WidgetItem: Identifiable {
    enum Kind {
        case habit
        case toDo
    }

    let id: UUID
    let title: String
    let icon: String
    let isCompleted: Bool
    let kind: Kind
}

struct HabitTrackerWidgetEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
}

struct HabitTrackerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitTrackerWidgetEntry {
        HabitTrackerWidgetEntry(date: .now, items: [
            WidgetItem(id: UUID(), title: "Run", icon: "figure.run", isCompleted: false, kind: .habit),
            WidgetItem(id: UUID(), title: "Groceries", icon: "checklist", isCompleted: true, kind: .toDo)
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
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
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
                    isCompleted: habit.isCompleted(on: today, calendar: calendar),
                    kind: .habit
                )
            }

        let toDos = (try? context.fetch(FetchDescriptor<ToDo>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let toDoItems = toDos
            .filter { calendar.isDate($0.scheduledDate, inSameDayAs: today) }
            .map { toDo in
                WidgetItem(id: toDo.id, title: toDo.title, icon: "checklist", isCompleted: toDo.isCompleted, kind: .toDo)
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
            Text("Today")
                .font(.headline)

            if entry.items.isEmpty {
                Text("Nothing planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleItems) { item in
                    HStack(spacing: 6) {
                        // A widget's rows aren't inside a List, so none of
                        // this codebase's documented List/NavigationLink
                        // hit-testing hazards around nested Buttons apply
                        // here — WidgetKit gives every interactive control
                        // its own tap target regardless.
                        toggleButton(for: item)
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.caption)
                }
                if entry.items.count > visibleItems.count {
                    Text("+\(entry.items.count - visibleItems.count) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // `Button(intent:)`'s generic parameter is constrained to a concrete
    // `AppIntent`-conforming type, not the `any AppIntent` existential — an
    // existential doesn't satisfy that constraint, since `AppIntent` isn't
    // usable as such (it has associated-type requirements). `@ViewBuilder`
    // branching, rather than a function returning one shared type, is what
    // lets each case build its own concrete `Button<Image>` over its own
    // concrete intent type.
    @ViewBuilder
    private func toggleButton(for item: WidgetItem) -> some View {
        let icon = Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(item.isCompleted ? Color.accentColor : Color.secondary)
        switch item.kind {
        case .habit:
            Button(intent: ToggleHabitIntent(habitID: item.id)) { icon }
                .buttonStyle(.plain)
        case .toDo:
            Button(intent: ToggleToDoIntent(toDoID: item.id)) { icon }
                .buttonStyle(.plain)
        }
    }
}

struct HabitTrackerWidget: Widget {
    let kind = "HabitTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitTrackerWidgetProvider()) { entry in
            HabitTrackerWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Shows your habits and to-dos for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
