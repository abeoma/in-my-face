import SwiftUI

struct ProbeControls: View {
    @ObservedObject var coordinator: OverlayCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Overlay検証").font(.largeTitle.bold())
            Text("通常デスクトップ・Space・フルスクリーンでの表示と操作を確認します。")
                .foregroundStyle(.secondary)
            Picker("表示構成", selection: $coordinator.mode) {
                ForEach(OverlayMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            .disabled(coordinator.isPending || coordinator.isShowing)
            Text("各画面にサンプルを表示します。表示中はEsc・Dismissで全画面を閉じられます。")
            HStack {
                Button("3秒後に表示") { coordinator.schedule() }
                    .disabled(coordinator.isPending || coordinator.isShowing)
                    .keyboardShortcut(.defaultAction)
                Button("表示・予約を停止") { coordinator.stop(reason: "検証画面から停止") }
                    .disabled(!coordinator.isPending && !coordinator.isShowing)
            }
            GroupBox("状態") {
                Text(coordinator.message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            Text("15秒で自動停止します。メニューバーからも停止・終了できます。")
                .font(.callout)
            Divider()
            Text("固定のサンプルのみ使用します。カレンダーアクセス・音・通信・保存は行いません。ロック画面への表示や全アプリ上での表示は保証しません。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 620, height: 470)
    }
}

struct SampleOverlay: View {
    let screenNumber: Int
    let mode: String
    let dismiss: () -> Void
    let quit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
            VStack(spacing: 20) {
                Label("表示検証 · ディスプレイ \(screenNumber)", systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Text("サンプル会議").font(.system(size: 44, weight: .bold))
                Text("これは検証用の表示です").font(.title2)
                Text(mode).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Button("Dismiss（全画面を閉じる）", action: dismiss)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.cancelAction)
                    Button("アプリを終了", action: quit)
                        .buttonStyle(.bordered)
                }
                Text("Escで閉じる · 15秒で自動停止").font(.callout)
            }
            .padding(40)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
