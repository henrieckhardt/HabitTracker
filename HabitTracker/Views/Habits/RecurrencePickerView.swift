import SwiftUI

enum RecurrencePreset: String, CaseIterable, Identifiable {
    case daily = "Täglich"
    case weekly = "Wöchentlich"
    case custom = "Individuell"

    var id: String { rawValue }

    /// `rawValue` is only a stable German internal identifier — this is the
    /// actual user-facing text, resolved through the string catalog.
    var displayName: String {
        switch self {
        case .daily: return String(localized: "Täglich")
        case .weekly: return String(localized: "Wöchentlich")
        case .custom: return String(localized: "Individuell")
        }
    }
}

enum CustomRecurrenceKind: String, CaseIterable, Identifiable {
    case weekdays = "Wochentage"
    case monthly = "Tag im Monat"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekdays: return String(localized: "Wochentage")
        case .monthly: return String(localized: "Tag im Monat")
        }
    }
}

/// Editable state backing the 3 user-facing recurrence presets. Converts
/// to/from the underlying `RecurrenceRule` used for persistence.
struct RecurrenceEditorState {
    var preset: RecurrencePreset
    var selectedWeekdays: Set<Weekday>
    var customKind: CustomRecurrenceKind
    var selectedMonthDays: Set<Int>

    init(
        preset: RecurrencePreset = .daily,
        selectedWeekdays: Set<Weekday> = [],
        customKind: CustomRecurrenceKind = .weekdays,
        selectedMonthDays: Set<Int> = []
    ) {
        self.preset = preset
        self.selectedWeekdays = selectedWeekdays
        self.customKind = customKind
        self.selectedMonthDays = selectedMonthDays
    }

    static func from(_ rule: RecurrenceRule) -> RecurrenceEditorState {
        switch rule {
        case .daily:
            return RecurrenceEditorState(preset: .daily)
        case .weekdays(let days):
            if days.count <= 1 {
                return RecurrenceEditorState(preset: .weekly, selectedWeekdays: days)
            }
            return RecurrenceEditorState(preset: .custom, selectedWeekdays: days, customKind: .weekdays)
        case .monthly(let days):
            return RecurrenceEditorState(preset: .custom, customKind: .monthly, selectedMonthDays: days)
        }
    }

    func buildRule() -> RecurrenceRule {
        switch preset {
        case .daily:
            return .daily
        case .weekly:
            return .weekdays(selectedWeekdays)
        case .custom:
            switch customKind {
            case .weekdays:
                return .weekdays(selectedWeekdays)
            case .monthly:
                return .monthly(daysOfMonth: selectedMonthDays)
            }
        }
    }

    var isValid: Bool {
        switch preset {
        case .daily:
            return true
        case .weekly:
            return !selectedWeekdays.isEmpty
        case .custom:
            switch customKind {
            case .weekdays: return !selectedWeekdays.isEmpty
            case .monthly: return !selectedMonthDays.isEmpty
            }
        }
    }
}

/// Lets the user pick one of the 3 user-facing recurrence presets, editing
/// the bound `RecurrenceEditorState` in place.
///
/// Intentionally has no `Section` of its own — a custom View whose body IS a
/// `Section` used directly as a `Form` child confuses List's hit-testing for
/// whatever sibling section follows it (the next Section's rows become
/// untappable). The caller wraps this in its own `Section("Wiederholung")`.
struct RecurrencePickerView: View {
    @Binding var state: RecurrenceEditorState

    var body: some View {
        Group {
            Picker("Turnus", selection: $state.preset) {
                ForEach(RecurrencePreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            switch state.preset {
            case .daily:
                EmptyView()
            case .weekly:
                WeekdaySelector(selection: $state.selectedWeekdays, allowsMultiple: false)
                    .onAppear { ensureExactlyOneWeekday() }
            case .custom:
                Picker("Art", selection: $state.customKind) {
                    ForEach(CustomRecurrenceKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                switch state.customKind {
                case .weekdays:
                    WeekdaySelector(selection: $state.selectedWeekdays, allowsMultiple: true)
                case .monthly:
                    MonthDaySelector(selection: $state.selectedMonthDays)
                }
            }
        }
    }

    private func ensureExactlyOneWeekday() {
        if state.selectedWeekdays.isEmpty {
            state.selectedWeekdays = [Weekday(calendarWeekday: Calendar.current.component(.weekday, from: .now))]
        } else if state.selectedWeekdays.count > 1 {
            state.selectedWeekdays = [state.selectedWeekdays.first!]
        }
    }
}
