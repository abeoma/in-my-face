import Foundation

struct CalendarSnapshot: Identifiable {
    let id: String
    let title: String
}

struct EventSnapshot: Identifiable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let isDetached: Bool
    let eventIdentifier: String
    let calendarIdentifier: String
    let occurrenceDate: Date?
}
