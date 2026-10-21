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

    var meetingLinks: [MeetingLink] = []

    var reminderDate: Date { start.addingTimeInterval(-60) }
    var displayTitle: String { title.isEmpty ? "名称未設定" : title }
}

/// 独立した停止理由を、対応する復帰通知だけで解除する。
struct SuspensionState {
    enum Reason: Hashable {
        case systemSleep, displaySleep, inactiveSession, shutdown
    }

    private var reasons: Set<Reason> = []
    var isSuspended: Bool { !reasons.isEmpty }

    mutating func suspend(_ reason: Reason) { reasons.insert(reason) }
    mutating func resume(_ reason: Reason) { reasons.remove(reason) }
}
