import AppKit
import EventKit
import SwiftUI

@main
struct EventKitProbeApp: App {
    @StateObject private var probe = CalendarProbe()

    var body: some Scene {
        WindowGroup("EventKit検証") {
            ProbeView(probe: probe)
                .frame(minWidth: 780, minHeight: 580)
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    probe.refresh()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.didBecomeActiveNotification)
                ) { _ in
                    probe.refresh()
                }
                .onReceive(
                    NSWorkspace.shared.notificationCenter.publisher(
                        for: NSWorkspace.didWakeNotification)
                ) { _ in
                    probe.refresh()
                }
        }
        .defaultSize(width: 920, height: 680)
        .windowResizability(.contentMinSize)
    }
}

struct ProbeView: View {
    @ObservedObject var probe: CalendarProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EventKit検証").font(.largeTitle.bold())
            Text("権限と予定取得を確認するための試作です。予定の編集・通知は行いません。")
                .foregroundStyle(.secondary)
            GroupBox("カレンダー権限") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("状態：\(probe.authorizationLabel)").font(.headline)
                    Text("macOSのFull Accessは書き込み権限も含みますが、このアプリは読み取りのみ行います。")
                    HStack {
                        Button("Full Accessを要求") {
                            Task { await probe.requestAccess() }
                        }
                        .disabled(
                            probe.isRequesting
                                || probe.authorization != .notDetermined)
                        Button("状態を確認・再取得") { probe.refresh() }
                            .disabled(probe.isRequesting)
                        Spacer()
                        if probe.isRequesting { ProgressView().controlSize(.small) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            Text(probe.message).foregroundStyle(.secondary)
                .accessibilityLabel("取得状態：\(probe.message)")
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("対象カレンダー").font(.headline)
                    Text("選択は保存されません。検証用データを使用してください。")
                        .font(.caption).foregroundStyle(.secondary)
                    List(probe.calendars) { calendar in
                        Toggle(
                            calendar.title,
                            isOn: Binding(
                                get: { probe.selectedCalendarIDs.contains(calendar.id) },
                                set: { enabled in
                                    if enabled {
                                        probe.selectedCalendarIDs.insert(calendar.id)
                                    } else {
                                        probe.selectedCalendarIDs.remove(calendar.id)
                                    }
                                    probe.refresh()
                                }))
                    }
                }
                .frame(width: 240)
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("取得日", selection: $probe.day, displayedComponents: .date)
                        .onChange(of: probe.day) { _, _ in probe.refresh() }
                    HStack {
                        Text("\(probe.events.count)件（開始時刻順）")
                        Spacer()
                        if let date = probe.lastRefresh {
                            Text("更新 \(date.formatted(date: .omitted, time: .standard))")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(probe.events) { event in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(event.title.isEmpty ? "名称未設定" : event.title)
                                        .font(.headline)
                                    Text("\(event.start.formatted()) → \(event.end.formatted())")
                                    Text(
                                        "終日：\(event.isAllDay ? "はい" : "いいえ") ／ 例外回：\(event.isDetached ? "はい" : "いいえ")"
                                    )
                                    Text("eventIdentifier: \(event.eventIdentifier)")
                                    Text("calendarIdentifier: \(event.calendarIdentifier)")
                                    Text(
                                        "occurrenceDate: \(event.occurrenceDate?.formatted(.iso8601) ?? "なし")"
                                    )
                                }
                                .font(.caption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Divider()
                            }
                        }
                    }
                    .overlay {
                        if probe.events.isEmpty {
                            ContentUnavailableView("表示する予定がありません", systemImage: "calendar")
                        }
                    }
                }
            }
            Divider()
            Text("予定はメモリ内のみで扱い、ログ・ファイルへの出力やネットワーク通信は行いません。終了は⌘Q。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
