import Foundation
import XCTest

final class ReminderSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testDisplayWakeDoesNotResumeAnInactiveSession() {
        var state = SuspensionState()
        state.suspend(.inactiveSession)
        state.suspend(.displaySleep)
        state.resume(.displaySleep)
        XCTAssertTrue(state.isSuspended)
        state.resume(.inactiveSession)
        XCTAssertFalse(state.isSuspended)
    }

    func testSystemWakeStillWaitsForDisplayWakeAndShutdownCannotResume() {
        var state = SuspensionState()
        state.suspend(.systemSleep)
        state.suspend(.displaySleep)
        state.resume(.systemSleep)
        XCTAssertTrue(state.isSuspended)
        state.resume(.displaySleep)
        XCTAssertFalse(state.isSuspended)
        state.suspend(.shutdown)
        state.resume(.systemSleep)
        state.resume(.displaySleep)
        state.resume(.inactiveSession)
        XCTAssertTrue(state.isSuspended)
    }

    private func event(
        id: String = "meeting", startOffset: TimeInterval = 60, endOffset: TimeInterval = 3600,
        allDay: Bool = false, cancelled: Bool = false, occurrence: Date? = nil
    ) -> EventSnapshot {
        EventSnapshot(
            id: OccurrenceKey(calendarID: "calendar", eventID: id, occurrenceDate: occurrence),
            title: "会議", start: now.addingTimeInterval(startOffset),
            end: now.addingTimeInterval(endOffset), isAllDay: allDay, isCancelled: cancelled)
    }

    func testFiresExactlyOneMinuteBeforeStart() {
        var scheduler = ReminderScheduler()
        let meeting = event()
        let before = scheduler.evaluate(
            events: [meeting], dismissed: [], now: now.addingTimeInterval(-1), enabled: true)
        XCTAssertTrue(before.alerts.isEmpty)
        XCTAssertEqual(before.nextDeadline, now)
        XCTAssertEqual(
            scheduler.evaluate(events: [meeting], dismissed: [], now: now, enabled: true).alerts,
            [meeting])
    }

    func testResumeIncludes119SecondsButExcludes120SecondsAfterStart() {
        var scheduler = ReminderScheduler()
        XCTAssertEqual(
            scheduler.evaluate(
                events: [event(startOffset: -119)], dismissed: [], now: now, enabled: true
            ).alerts.count, 1)
        scheduler = ReminderScheduler()
        XCTAssertTrue(
            scheduler.evaluate(
                events: [event(startOffset: -120)], dismissed: [], now: now, enabled: true
            ).alerts.isEmpty)
    }

    func testVisibleMeetingStaysUntilEndEvenAfterTwoMinutes() {
        var scheduler = ReminderScheduler()
        let meeting = event()
        _ = scheduler.evaluate(events: [meeting], dismissed: [], now: now, enabled: true)
        let later = scheduler.evaluate(
            events: [meeting], dismissed: [], now: now.addingTimeInterval(300), enabled: true)
        XCTAssertEqual(later.alerts, [meeting])
        XCTAssertEqual(later.nextDeadline, meeting.end)
        XCTAssertTrue(
            scheduler.evaluate(events: [meeting], dismissed: [], now: meeting.end, enabled: true)
                .alerts.isEmpty)
    }

    func testAllDayCancelledAndEndedEventsAreExcluded() {
        var scheduler = ReminderScheduler()
        let events = [
            event(id: "all", allDay: true), event(id: "cancelled", cancelled: true),
            event(id: "ended", endOffset: 0),
        ]
        let result = scheduler.evaluate(events: events, dismissed: [], now: now, enabled: true)
        XCTAssertTrue(result.alerts.isEmpty)
        XCTAssertNil(result.nextDeadline)
    }

    func testDismissedOccurrenceDoesNotReappearAfterEditingStart() {
        var scheduler = ReminderScheduler()
        let meeting = event()
        let edited = event(startOffset: 30)
        XCTAssertTrue(
            scheduler.evaluate(events: [edited], dismissed: [meeting.id], now: now, enabled: true)
                .alerts.isEmpty)
    }

    func testSimultaneousMeetingsAndDuplicateSnapshots() {
        var scheduler = ReminderScheduler()
        let a = event(id: "a")
        let b = event(id: "b")
        XCTAssertEqual(
            scheduler.evaluate(events: [b, a, a], dismissed: [], now: now, enabled: true).alerts,
            [a, b])
        XCTAssertEqual(
            scheduler.evaluate(events: [a, b], dismissed: [a.id], now: now, enabled: true).alerts,
            [b])
    }

    func testDeletedMeetingIsRemovedAndMovedMeetingIsRescheduled() {
        var scheduler = ReminderScheduler()
        _ = scheduler.evaluate(events: [event()], dismissed: [], now: now, enabled: true)
        XCTAssertTrue(
            scheduler.evaluate(events: [], dismissed: [], now: now, enabled: true).alerts.isEmpty)
        let moved = event(startOffset: 600)
        let result = scheduler.evaluate(events: [moved], dismissed: [], now: now, enabled: true)
        XCTAssertTrue(result.alerts.isEmpty)
        XCTAssertEqual(result.nextDeadline, now.addingTimeInterval(540))
    }

    func testPauseClearsVisibleStateAndResumeUsesGraceWindow() {
        var scheduler = ReminderScheduler()
        let meeting = event()
        _ = scheduler.evaluate(events: [meeting], dismissed: [], now: now, enabled: true)
        let paused = scheduler.evaluate(events: [meeting], dismissed: [], now: now, enabled: false)
        XCTAssertTrue(paused.alerts.isEmpty)
        XCTAssertNil(paused.nextDeadline)
        XCTAssertTrue(
            scheduler.evaluate(
                events: [meeting], dismissed: [], now: now.addingTimeInterval(181), enabled: true
            ).alerts.isEmpty)
    }

    func testRepeatingOccurrencesHaveIndependentDismissal() {
        var scheduler = ReminderScheduler()
        let first = event(occurrence: now)
        let second = event(occurrence: now.addingTimeInterval(86400))
        XCTAssertEqual(
            scheduler.evaluate(
                events: [first, second], dismissed: [first.id], now: now, enabled: true
            ).alerts, [second])
    }

    func testClockMovesBackwardsReschedulesVisibleMeeting() {
        var scheduler = ReminderScheduler()
        let meeting = event()
        _ = scheduler.evaluate(events: [meeting], dismissed: [], now: now, enabled: true)
        let result = scheduler.evaluate(
            events: [meeting], dismissed: [], now: now.addingTimeInterval(-300), enabled: true)
        XCTAssertTrue(result.alerts.isEmpty)
        XCTAssertEqual(result.nextDeadline, now)
    }

    func testNewMeetingJoinsExistingBatchWithoutClosingOldMeeting() {
        var scheduler = ReminderScheduler()
        let a = event(id: "a")
        let b = event(id: "b", startOffset: 240)
        _ = scheduler.evaluate(events: [a, b], dismissed: [], now: now, enabled: true)
        XCTAssertEqual(
            scheduler.evaluate(
                events: [a, b], dismissed: [], now: now.addingTimeInterval(180), enabled: true
            ).alerts, [a, b])
    }
}
