import EventKit
import Foundation

@MainActor
final class CalendarService {
    struct Result {
        let calendars: [CalendarSnapshot]
        let events: [EventSnapshot]
    }

    private let store = EKEventStore()

    var authorization: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .event) }

    func requestAccess() async throws { _ = try await store.requestFullAccessToEvents() }

    func clear() { store.reset() }

    func fetch(calendarIDs: Set<String>, now: Date) -> Result? {
        guard authorization == .fullAccess else { return nil }
        store.reset()
        let calendars = store.calendars(for: .event)
        let calendarSnapshots = calendars.map {
            CalendarSnapshot(id: $0.calendarIdentifier, title: $0.title)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let selected = calendars.filter { calendarIDs.contains($0.calendarIdentifier) }
        // 空配列をEventKitに渡して全カレンダー取得になることを防ぐ。
        guard !selected.isEmpty else { return Result(calendars: calendarSnapshots, events: []) }
        let start = min(Calendar.current.startOfDay(for: now), now.addingTimeInterval(-120))
        let end = now.addingTimeInterval(48 * 60 * 60)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selected)
        let snapshots = store.events(matching: predicate).compactMap { event -> EventSnapshot? in
            guard let identifier = event.eventIdentifier,
                let start = event.startDate, let end = event.endDate,
                let calendar = event.calendar
            else { return nil }
            // 単発の開始時刻編集ではキーを変えない。繰り返しは元の回日時で分離する。
            let recurring =
                event.hasRecurrenceRules || event.isDetached || event.occurrenceDate != nil
            guard !recurring || event.occurrenceDate != nil else { return nil }
            return EventSnapshot(
                id: OccurrenceKey(
                    calendarID: calendar.calendarIdentifier, eventID: identifier,
                    occurrenceDate: recurring ? event.occurrenceDate : nil),
                title: event.title ?? "", start: start, end: end, isAllDay: event.isAllDay,
                isCancelled: event.status == .canceled,
                meetingLinks: MeetingURLExtractor.extract(
                    url: event.url, location: event.location, notes: event.notes))
        }.sorted { $0.start < $1.start }
        guard authorization == .fullAccess else { return nil }
        return Result(calendars: calendarSnapshots, events: snapshots)
    }
}
