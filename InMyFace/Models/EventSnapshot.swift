import Foundation

struct OccurrenceKey: Hashable, Codable, Sendable {
    let calendarID: String
    let eventID: String
    let occurrenceDate: Date?
}

struct CalendarSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
}

struct EventSnapshot: Identifiable, Equatable, Sendable {
    let id: OccurrenceKey
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let isCancelled: Bool

    var reminderDate: Date { start.addingTimeInterval(-60) }
    var displayTitle: String { title.isEmpty ? "名称未設定" : title }
}
