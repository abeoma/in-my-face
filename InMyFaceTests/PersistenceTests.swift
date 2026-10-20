import Foundation
import XCTest

final class PersistenceTests: XCTestCase {
    private var directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private func event(end: Date? = nil) -> EventSnapshot {
        EventSnapshot(
            id: OccurrenceKey(calendarID: "calendar", eventID: "id", occurrenceDate: nil),
            title: "private-title-not-to-store", start: now,
            end: end ?? now.addingTimeInterval(3600),
            isAllDay: false, isCancelled: false)
    }

    func testDismissedOccurrenceSurvivesReloadWithoutSavingTitle() throws {
        let url = directory.appendingPathComponent("ledger.json")
        let store = DismissalStore(url: url)
        try store.dismiss(event(), now: now)
        let reloaded = DismissalStore(url: url)
        try reloaded.load(now: now)
        XCTAssertEqual(reloaded.dismissedIDs, [event().id])
        XCTAssertFalse(try String(contentsOf: url, encoding: .utf8).contains(event().title))
    }

    func testExpiredEntriesArePrunedAndMovedEventsExtendRetention() throws {
        let url = directory.appendingPathComponent("ledger.json")
        let store = DismissalStore(url: url)
        try store.dismiss(event(), now: now)
        let later = now.addingTimeInterval(6 * 86400)
        let moved = event(end: now.addingTimeInterval(30 * 86400))
        try store.reconcile(events: [moved], now: later)
        let reloaded = DismissalStore(url: url)
        try reloaded.load(now: now.addingTimeInterval(8 * 86400))
        XCTAssertTrue(reloaded.dismissedIDs.contains(moved.id))
        try reloaded.reconcile(events: [], now: now.addingTimeInterval(37 * 86400))
        XCTAssertTrue(reloaded.dismissedIDs.isEmpty)
    }

    func testCorruptLedgerIsReportedAndBackedUp() throws {
        let url = directory.appendingPathComponent("ledger.json")
        try Data("invalid-json".utf8).write(to: url)
        let store = DismissalStore(url: url)
        XCTAssertThrowsError(try store.load(now: now))
        XCTAssertTrue(store.dismissedIDs.isEmpty)
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(backups.filter { $0.hasPrefix("dismissed-corrupt-") }.count, 1)
        try store.dismiss(event(), now: now)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testWriteFailureStillSuppressesWithinProcess() throws {
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blocker)
        let store = DismissalStore(url: blocker.appendingPathComponent("ledger.json"))
        XCTAssertThrowsError(try store.dismiss(event(), now: now))
        XCTAssertTrue(store.dismissedIDs.contains(event().id))
    }

    func testSettingsKeepSelectionAndPauseAcrossReload() throws {
        let suite = "InMyFaceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.calendarIDs.isEmpty)
        XCTAssertFalse(store.isPaused)
        store.calendarIDs = ["a", "b"]
        store.isPaused = true
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.calendarIDs, ["a", "b"])
        XCTAssertTrue(reloaded.isPaused)
    }
}
