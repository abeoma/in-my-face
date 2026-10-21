import Foundation
import XCTest

final class MeetingURLExtractorTests: XCTestCase {
    func testSupportedMeetingPaths() {
        let samples = [
            "https://meet.google.com/abc-defg-hij",
            "https://us02web.zoom.us/j/123456789?pwd=secret",
            "https://zoom.com/my/example",
            "https://teams.microsoft.com/l/meetup-join/19%3ameeting_example/0?context=example",
            "https://teams.live.com/meet/123456789?p=example",
            "https://example.webex.com/meet/person",
            "https://example.webex.com/example/j.php?MTID=example",
        ]
        for sample in samples {
            XCTAssertEqual(extract(sample).first?.url.absoluteString, sample, sample)
        }
    }

    func testStructuredURLPreservesPathQueryAndFragmentExactly() {
        for sample in [
            "https://zoom.us/my/example.",
            "https://zoom.us/j/123?pwd=abc!",
            "https://zoom.us/j/123?pwd=abc&amp;x=1#fragment!",
            "https://teams.live.com/meet/123?p=a'b#fragment.",
        ] {
            let links = MeetingURLExtractor.extract(
                url: URL(string: sample), location: nil, notes: nil)
            XCTAssertEqual(links.first?.url.absoluteString, sample, sample)
        }
    }

    func testProsePreservesTokenSuffixesAndDistinctWebexCandidates() {
        for sample in ["https://zoom.us/j/123?pwd=abc!", "https://zoom.us/j/123#fragment."] {
            XCTAssertEqual(extract(sample).first?.url.absoluteString, sample)
        }
        let links = extract(
            "https://example.webex.com/site/j.php?MTID=A https://example.webex.com/site/j.php?MTID=B"
        )
        XCTAssertEqual(links.count, 2)
        XCTAssertNotEqual(links.first?.url, links.last?.url)
    }

    func testRejectsUnsafeAndNonMeetingURLs() {
        for sample in [
            "http://meet.google.com/abc-defg-hij", "zoommtg://zoom.us/j/123",
            "https://zoom.us.example.com/j/123", "https://evilzoom.us/j/123",
            "https://user@zoom.us/j/123", "https://zoom.us:8443/j/123",
            "https://example.webex.com/site/jXphp?MTID=x",
            "https://example.webex.com/meet/name%0A",
            "https://example.webex.com/meet/name%09",
            "https://zoom.us/pricing", "https://meet.google.com/",
            "https://teams.microsoft.com/unknown", "https://example.webex.com/",
            "https://meet.google.com.evil.test/abc-defg-hij", "https://zoom.us./j/123",
        ] {
            XCTAssertTrue(extract(sample).isEmpty, sample)
        }
    }

    func testFieldPriorityOccurrenceOrderAndDeduplication() {
        let first = "https://meet.google.com/abc-defg-hij"
        let second = "https://zoom.us/j/123"
        let third = "https://example.webex.com/meet/person"
        let links = MeetingURLExtractor.extract(
            url: URL(string: first), location: "Join (\(second)). \(first)",
            notes: "\(third) \(second)")
        XCTAssertEqual(links.map(\.url.absoluteString), [first, second, third])
    }

    func testHTMLAndPunctuationPreserveQuery() {
        let links = extract("<a href=\"https://zoom.us/j/123?pwd=abc&amp;x=1\">Join</a>。")
        XCTAssertEqual(links.first?.url.absoluteString, "https://zoom.us/j/123?pwd=abc&x=1")
        XCTAssertEqual(extract("参加：https://meet.google.com/abc-defg-hij。").count, 1)
        XCTAssertTrue(MeetingURLExtractor.extract(url: nil, location: nil, notes: nil).isEmpty)
    }

    private func extract(_ text: String) -> [MeetingLink] {
        MeetingURLExtractor.extract(url: nil, location: nil, notes: text)
    }
}

@MainActor
final class MeetingJoinTests: XCTestCase {
    func testFailedOpenCanRetryAndSuccessDismissesOnlySelectedEvent() {
        var attempts: [URL] = []
        var shouldOpen = false
        let coordinator = AlertCoordinator { url in
            attempts.append(url)
            return shouldOpen
        }
        let links = MeetingURLExtractor.extract(
            url: nil, location: "https://zoom.us/j/123 https://zoom.us/j/456", notes: nil)
        let event = EventSnapshot(
            id: OccurrenceKey(calendarID: "test", eventID: "test", occurrenceDate: nil),
            title: "test", start: .distantFuture, end: .distantFuture,
            isAllDay: false, isCancelled: false, meetingLinks: links)
        // 画面を作らず、外部URLも開かずにJoin操作の結果を検証する。
        coordinator.synchronize([event], showsPanels: false)
        coordinator.selectedLinks[event.id] = links[1].url
        var dismissed: [OccurrenceKey] = []
        coordinator.onDismiss = { dismissed.append($0.id) }
        coordinator.join(event)
        XCTAssertEqual(attempts, [links[1].url])
        XCTAssertTrue(dismissed.isEmpty)
        XCTAssertNotNil(coordinator.joinErrors[event.id])
        shouldOpen = true
        coordinator.join(event)
        XCTAssertEqual(dismissed, [event.id])
        XCTAssertNil(coordinator.joinErrors[event.id])
    }
}
