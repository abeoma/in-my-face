import AppKit
import SwiftUI

struct AlertView: View {
    @ObservedObject var coordinator: AlertCoordinator

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
            VStack(spacing: 18) {
                Label("会議の時間です", systemImage: "calendar.badge.clock")
                    .font(.title2.bold())
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(coordinator.events) { event in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(event.displayTitle).font(.system(size: 32, weight: .bold))
                                Text(event.start.formatted(date: .omitted, time: .shortened))
                                    .font(.title2)
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(remaining(event: event, now: context.date)).font(.title3)
                                }
                                if !event.meetingLinks.isEmpty {
                                    Picker(
                                        "参加先",
                                        selection: Binding(
                                            get: {
                                                coordinator.selectedLinks[event.id]
                                                    ?? event.meetingLinks[0].url
                                            },
                                            set: { coordinator.selectedLinks[event.id] = $0 }
                                        )
                                    ) {
                                        ForEach(
                                            Array(event.meetingLinks.enumerated()),
                                            id: \.element.url
                                        ) { index, link in
                                            Text(
                                                "候補\(index + 1) — \(link.service) — \(link.host) — \(link.url.path)"
                                            )
                                            .tag(link.url)
                                        }
                                    }
                                } else {
                                    Text("対応する会議URLがありません").foregroundStyle(.secondary)
                                }
                                if let error = coordinator.joinErrors[event.id] {
                                    Text(error).foregroundStyle(.orange)
                                }
                                Button("Join") { coordinator.join(event) }
                                    .disabled(event.meetingLinks.isEmpty)
                                    .accessibilityLabel("\(event.displayTitle)に参加")
                                Button("Dismiss") { coordinator.onDismiss?(event) }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityLabel("\(event.displayTitle)を閉じる")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        coordinator.selectedID == event.id
                                            ? Color.accentColor : .clear, lineWidth: 3)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { coordinator.selectedID = event.id }
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 580)
                Text("Esc：選択中の予定を閉じる").foregroundStyle(.secondary)
                Button("アプリを終了") { NSApp.terminate(nil) }.buttonStyle(.bordered)
            }
            .padding(32)
            .frame(maxWidth: 640)
        }
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func remaining(event: EventSnapshot, now: Date) -> String {
        let seconds = max(0, Int(ceil(event.start.timeIntervalSince(now))))
        return seconds == 0 ? "開始済み" : "開始まで \(seconds / 60)分\(seconds % 60)秒"
    }
}
