import EventKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppLifecycleManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("In My Face").font(.largeTitle.bold())
                if model.isDemo {
                    Text("デモ").font(.caption).padding(6).background(.quaternary, in: Capsule())
                }
                Spacer()
                Toggle("一時停止", isOn: Binding(get: { model.isPaused }, set: model.setPaused))
                    .toggleStyle(.switch)
            }
            Text(model.message).foregroundStyle(.secondary)
            if model.authorization != .fullAccess {
                Text("予定の読み取りにはFull Accessが必要です。予定の編集や外部送信は行いません。")
                if model.authorization == .notDetermined || model.authorization == .writeOnly {
                    Button("カレンダーへのアクセスを許可") { Task { await model.requestAccess() } }
                        .disabled(model.isRequesting)
                }
            }
            if let warning = model.historyWarning {
                Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("通知するカレンダー").font(.headline)
                    List(model.calendars) { calendar in
                        Toggle(
                            calendar.title,
                            isOn: Binding(
                                get: { model.selectedIDs.contains(calendar.id) },
                                set: { model.selectCalendar(calendar.id, selected: $0) }))
                    }
                }.frame(width: 240)
                VStack(alignment: .leading, spacing: 10) {
                    Text("次の予定").font(.headline)
                    if let event = model.nextEvent {
                        Text(event.displayTitle).font(.title3.bold())
                        Text(event.start.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("予定なし").foregroundStyle(.secondary)
                    }
                    Divider()
                    Text("今日の予定").font(.headline)
                    List(model.todayEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.displayTitle)
                            Text(
                                event.isAllDay
                                    ? "終日（通知対象外）"
                                    : event.start.formatted(date: .omitted, time: .shortened)
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            HStack {
                Button("予定を更新") { model.refresh() }
                if model.isDemo { Button("5秒後にデモ通知") { model.restartDemo() } }
                Spacer()
                Text("通知は1分前・音なし").font(.caption).foregroundStyle(.secondary)
            }
            LoginItemSettingsView(service: model.loginItem)
            Text("ウィンドウを閉じてもメニューバーに常駐します。終了はメニューバーから。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 620)
    }
}
