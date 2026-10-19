import Combine
import EventKit
import Foundation

@MainActor
final class CalendarProbe: ObservableObject {
    @Published private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var calendars: [CalendarSnapshot] = []
    @Published private(set) var events: [EventSnapshot] = []
    @Published private(set) var message = "カレンダーへのアクセスは、下のボタンで要求します。"
    @Published private(set) var isRequesting = false
    @Published private(set) var lastRefresh: Date?
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var day = Date()

    private let store = EKEventStore()

    var authorizationLabel: String {
        switch authorization {
        case .notDetermined: "未決定"
        case .restricted: "制限あり"
        case .denied: "拒否"
        case .fullAccess: "Full Access（読み取り可能）"
        case .writeOnly: "Write Only（読み取り不可）"
        @unknown default: "不明（読み取り停止）"
        }
    }

    func requestAccess() async {
        guard !isRequesting, authorization == .notDetermined else { return }
        isRequesting = true
        defer { isRequesting = false }
        do {
            _ = try await store.requestFullAccessToEvents()
            refresh()
        } catch {
            clearData()
            authorization = EKEventStore.authorizationStatus(for: .event)
            message = "権限要求に失敗しました。システム設定を確認し、再度状態を確認してください。"
        }
    }

    func refresh() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        guard authorization == .fullAccess else {
            clearData()
            message = "予定の読み取りにはFull Accessが必要です。システム設定のプライバシーとセキュリティでカレンダー権限を確認してください。"
            return
        }

        // 変更通知後に古いEventKitオブジェクトを再利用しない。
        store.reset()
        let available = store.calendars(for: .event)
        calendars = available.map { CalendarSnapshot(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        selectedCalendarIDs.formIntersection(Set(calendars.map(\.id)))
        let selected = available.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty else {
            events = []
            lastRefresh = Date()
            message = "検証用のカレンダーを選択してください（初期選択なし）。"
            return
        }
        guard let interval = Calendar.current.dateInterval(of: .day, for: day) else {
            events = []
            message = "取得期間を計算できませんでした。日付を選び直してください。"
            return
        }
        let predicate = store.predicateForEvents(
            withStart: interval.start, end: interval.end, calendars: selected)
        let fetched = store.events(matching: predicate)
        // EventKitオブジェクトはMainActor内で値へ変換し、保持しない。
        let snapshots = fetched.map {
            EventSnapshot(
                title: $0.title ?? "名称未設定", start: $0.startDate, end: $0.endDate,
                isAllDay: $0.isAllDay, isDetached: $0.isDetached,
                eventIdentifier: $0.eventIdentifier ?? "（なし）",
                calendarIdentifier: $0.calendar.calendarIdentifier,
                occurrenceDate: $0.occurrenceDate)
        }.sorted { $0.start < $1.start }
        authorization = EKEventStore.authorizationStatus(for: .event)
        guard authorization == .fullAccess else {
            clearData()
            message = "権限が変更されたため取得結果を破棄しました。"
            return
        }
        events = snapshots
        lastRefresh = Date()
        message = "選択日の予定を取得しました。終日・例外回も検証用に表示します。"
    }

    private func clearData() {
        calendars = []
        events = []
        selectedCalendarIDs = []
        lastRefresh = nil
        store.reset()
    }
}
