import AppKit
import Combine
import EventKit
import Foundation

@MainActor
final class AppLifecycleManager: ObservableObject {
    @Published private(set) var calendars: [CalendarSnapshot] = []
    @Published private(set) var events: [EventSnapshot] = []
    @Published private(set) var selectedIDs: Set<String>
    @Published private(set) var isPaused: Bool
    @Published private(set) var authorization = EKAuthorizationStatus.notDetermined
    @Published private(set) var isRequesting = false
    @Published private(set) var message = ""
    @Published private(set) var historyWarning: String?

    let alerts: AlertCoordinator
    let loginItem: LoginItemService
    let isDemo: Bool
    private let calendar = CalendarService()
    private let settings = SettingsStore()
    private var ledger: DismissalStore
    private var scheduler = ReminderScheduler()
    private var timer: Timer?
    private var subscriptions: Set<AnyCancellable> = []
    private var suspension = SuspensionState()
    private var initialHistoryWarning: String?
    private var demoStart = Date().addingTimeInterval(90)

    init(isDemo: Bool = false) {
        self.isDemo = isDemo
        loginItem = LoginItemService(isDemo: isDemo)
        // デモの架空IDが実会議と重なっても、外部URLを開かない。
        alerts = isDemo ? AlertCoordinator(openURL: { _ in true }) : AlertCoordinator()
        selectedIDs = isDemo ? ["demo"] : settings.calendarIDs
        isPaused = isDemo ? false : settings.isPaused
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first
        ledger = DismissalStore(
            url: isDemo ? nil : support?.appendingPathComponent("InMyFace/dismissed.json"))
        if !isDemo && support == nil {
            historyWarning = "履歴の保存先を取得できません。再起動後に再表示される可能性があります。"
        }
        do { try ledger.load(now: Date()) } catch {
            historyWarning = "履歴を読み込めませんでした。以前閉じた予定が再表示される可能性があります。"
        }
        initialHistoryWarning = historyWarning
        alerts.onDismiss = { [weak self] in self?.dismiss($0) }
    }

    var nextEvent: EventSnapshot? {
        events.first { !$0.isAllDay && !$0.isCancelled && $0.start > Date() }
    }

    var todayEvents: [EventSnapshot] {
        guard let day = Calendar.current.dateInterval(of: .day, for: Date()) else { return [] }
        return events.filter { $0.start < day.end && $0.end > day.start && !$0.isCancelled }
    }

    func start() {
        observe(NotificationCenter.default, .EKEventStoreChanged, debounce: true) { $0.refresh() }
        for name in [
            NSApplication.didBecomeActiveNotification, .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange, .NSCalendarDayChanged,
        ] {
            observe(NotificationCenter.default, name) { $0.refresh() }
        }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) {
            $0.alerts.rebuildPanels()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        let transitions: [(Notification.Name, Notification.Name, SuspensionState.Reason)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, .systemSleep),
            (
                NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                .displaySleep
            ),
            (
                NSWorkspace.sessionDidResignActiveNotification,
                NSWorkspace.sessionDidBecomeActiveNotification, .inactiveSession
            ),
        ]
        for (stop, resume, reason) in transitions {
            observe(workspace, stop) { $0.suspend(reason: reason) }
            observe(workspace, resume) {
                $0.suspension.resume(reason)
                $0.refresh()
            }
        }
        refresh()
    }

    func requestAccess() async {
        guard !isDemo, !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await calendar.requestAccess()
            refresh()
        } catch {
            clearCalendarData()
            authorization = calendar.authorization
            message = "権限要求に失敗しました。システム設定のカレンダー権限を確認してください。"
        }
    }

    func selectCalendar(_ id: String, selected: Bool) {
        if selected { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
        if !isDemo { settings.calendarIDs = selectedIDs }
        refresh()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if !isDemo { settings.isPaused = paused }
        refresh()
    }

    func restartDemo() {
        guard isDemo else { return }
        demoStart = Date().addingTimeInterval(65)
        ledger = DismissalStore(url: nil)
        scheduler = ReminderScheduler()
        selectedIDs = ["demo"]
        isPaused = false
        suspension = SuspensionState()
        alerts.synchronize([])
        refresh()
    }

    func refresh() {
        loginItem.refresh()
        timer?.invalidate()
        timer = nil
        guard !suspension.isSuspended else { return }
        let now = Date()
        if isDemo {
            authorization = .fullAccess
            calendars = [CalendarSnapshot(id: "demo", title: "サンプルカレンダー")]
            events =
                selectedIDs.isEmpty
                ? []
                : ["サンプル会議", "デザインレビュー"].enumerated().map {
                    EventSnapshot(
                        id: OccurrenceKey(
                            calendarID: "demo", eventID: "sample-\($0.offset)", occurrenceDate: nil),
                        title: $0.element, start: demoStart,
                        end: demoStart.addingTimeInterval(1800),
                        isAllDay: false, isCancelled: false,
                        meetingLinks: $0.offset == 0
                            ? MeetingURLExtractor.extract(
                                url: nil,
                                location:
                                    "https://meet.google.com/abc-defg-hij https://zoom.us/j/123456789",
                                notes: nil) : [])
                }
        } else {
            authorization = calendar.authorization
            guard let result = calendar.fetch(calendarIDs: selectedIDs, now: now) else {
                clearCalendarData()
                authorization = calendar.authorization
                message =
                    authorization == .notDetermined
                    ? "カレンダーへのアクセスを許可し、対象を選択してください。"
                    : "予定の取得と通知を停止中です。システム設定のカレンダー権限を確認してください。"
                return
            }
            calendars = result.calendars
            let available = Set(calendars.map(\.id))
            let previous = selectedIDs
            selectedIDs.formIntersection(available)
            if previous != selectedIDs { settings.calendarIDs = selectedIDs }
            events = result.events
        }
        do {
            try ledger.reconcile(events: events, now: now)
            historyWarning = initialHistoryWarning
        } catch {
            historyWarning = "履歴を保存できません。再起動後に再表示される可能性があります。"
        }
        let evaluation = scheduler.evaluate(
            events: events, dismissed: ledger.dismissedIDs, now: now, enabled: !isPaused)
        alerts.synchronize(evaluation.alerts)
        message =
            isPaused
            ? "一時停止中"
            : selectedIDs.isEmpty
                ? "対象カレンダーを選択してください。"
                : evaluation.alerts.isEmpty
                    ? "開始1分前に通知します。"
                    : "\(evaluation.alerts.count)件のアラートを表示中です。"
        let deadline = min(
            evaluation.nextDeadline ?? .distantFuture, now.addingTimeInterval(30 * 60))
        let timer = Timer(timeInterval: max(0.1, deadline.timeIntervalSinceNow), repeats: false) {
            [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func shutdown() {
        suspend(reason: .shutdown)
        subscriptions = []
    }

    private func dismiss(_ event: EventSnapshot) {
        do { try ledger.dismiss(event, now: Date()) } catch {
            historyWarning = "履歴を保存できません。この起動中は抑止しますが、再起動後に再表示される可能性があります。"
        }
        refresh()
    }

    private func suspend(reason: SuspensionState.Reason) {
        suspension.suspend(reason)
        message = "スリープまたはユーザー切替中のため通知を停止しています。"
        timer?.invalidate()
        timer = nil
        _ = scheduler.evaluate(events: [], dismissed: [], now: Date(), enabled: false)
        alerts.synchronize([])
    }

    private func clearCalendarData() {
        calendars = []
        events = []
        calendar.clear()
        _ = scheduler.evaluate(events: [], dismissed: [], now: Date(), enabled: false)
        alerts.synchronize([])
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name, debounce: Bool = false,
        action: @escaping @MainActor (AppLifecycleManager) -> Void
    ) {
        let publisher = center.publisher(for: name)
        let notifications =
            debounce
            ? publisher.debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
            : publisher.eraseToAnyPublisher()
        notifications.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                action(self)
            }
        }.store(in: &subscriptions)
    }
}
