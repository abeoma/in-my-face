import Foundation

final class SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var calendarIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "selectedCalendarIDs") ?? []) }
        set { defaults.set(newValue.sorted(), forKey: "selectedCalendarIDs") }
    }

    var isPaused: Bool {
        get { defaults.bool(forKey: "isPaused") }
        set { defaults.set(newValue, forKey: "isPaused") }
    }
}
