import SwiftUI

enum RecurrencePreset: String, CaseIterable, Identifiable {
    case daily = "Täglich"
    case weekly = "Wöchentlich"
    case weekdays = "An Wochentagen"
    case custom = "Individuell"

    var id: String { rawValue }
}

enum CustomRecurrenceKind: String, CaseIterable, Identifiable {
    case weekdays = "Wochentage"
    case monthly = "Tag im Monat"

    var id: String { rawValue }
}

/// Editable state backing the 4 user-facing recurrence presets. Converts
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
            return RecurrenceEditorState(preset: days.count <= 1 ? .weekly : .weekdays, selectedWeekdays: days)
        case .monthly(let days):
            return RecurrenceEditorState(preset: .custom, customKind: .monthly, selectedMonthDays: days)
        }
    }

    func buildRule() -> RecurrenceRule {
        switch preset {
        case .daily:
            return .daily
        case .weekly, .weekdays:
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
        case .weekly, .weekdays:
            return !selectedWeekdays.isEmpty
        case .custom:
            switch customKind {
            case .weekdays: return !selectedWeekdays.isEmpty
            case .monthly: return !selectedMonthDays.isEmpty
            }
        }
    }
}

/// Lets the user pick one of the 4 user-facing recurrence presets, editing
/// the bound `RecurrenceEditorState` in place.
struct RecurrencePickerView: View {
    @Binding var state: RecurrenceEditorState

    var body: some View {
        Section("Wiederholung") {
            Picker("Turnus", selection: $state.preset) {
                ForEach(RecurrencePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            switch state.preset {
            case .daily:
                EmptyView()
            case .weekly:
                WeekdaySelector(selection: $state.selectedWeekdays, allowsMultiple: false)
                    .onAppear { ensureExactlyOneWeekday() }
            case .weekdays:
                WeekdaySelector(selection: $state.selectedWeekdays, allowsMultiple: true)
            case .custom:
                Picker("Art", selection: $state.customKind) {
                    ForEach(CustomRecurrenceKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
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
