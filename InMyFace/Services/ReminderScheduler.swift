import Foundation

/// 予定取得・時計・ウィンドウから独立した、1分前通知の状態計算。
struct ReminderScheduler {
    struct Evaluation {
        let alerts: [EventSnapshot]
        let nextDeadline: Date?
    }

    private(set) var visibleIDs: Set<OccurrenceKey> = []

    mutating func evaluate(
        events: [EventSnapshot], dismissed: Set<OccurrenceKey>, now: Date, enabled: Bool
    ) -> Evaluation {
        guard enabled else {
            visibleIDs = []
            return Evaluation(alerts: [], nextDeadline: nil)
        }
        var seen: Set<OccurrenceKey> = []
        let eligible = events.filter {
            !$0.isAllDay && !$0.isCancelled && $0.end > now && !dismissed.contains($0.id)
                && seen.insert($0.id).inserted
        }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id.eventID < $1.id.eventID
        }
        let alerts = eligible.filter {
            $0.reminderDate <= now
                && (visibleIDs.contains($0.id) || now < $0.start.addingTimeInterval(120))
        }
        visibleIDs = Set(alerts.map(\.id))
        let futureDates = eligible.filter { $0.reminderDate > now }.map(\.reminderDate)
        return Evaluation(alerts: alerts, nextDeadline: (futureDates + alerts.map(\.end)).min())
    }
}
