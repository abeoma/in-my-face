import AppKit
import Combine
import SwiftUI

// 排他的なCollectionBehaviorを同時に指定しない、比較用の2構成。
enum OverlayMode: String, CaseIterable, Identifiable {
    case spaces = "全Space + Full Screen Auxiliary"
    case applications = "全Space + Can Join All Applications"

    var id: String { rawValue }

    var behavior: NSWindow.CollectionBehavior {
        switch self {
        case .spaces: [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .applications: [.canJoinAllSpaces, .canJoinAllApplications]
        }
    }
}

@MainActor
final class OverlayCoordinator: ObservableObject {
    @Published var mode: OverlayMode = .spaces
    @Published private(set) var isPending = false
    @Published private(set) var isShowing = false
    @Published private(set) var screenCount = 0
    @Published private(set) var message = "サンプル表示を手動で開始してください。"

    private var panels: [ProbePanel] = []
    private var pendingTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var subscriptions: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isShowing else { return }
                self.rebuildPanels()
            }
        }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.stop(reason: "スリープ前に停止") }
            }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.sessionDidResignActiveNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop(reason: "ユーザーセッション非アクティブ") }
        }.store(in: &subscriptions)
    }

    func schedule() {
        stop(reason: "前の表示を停止")
        isPending = true
        message = "3秒後に表示します。検証したいアプリやSpaceへ移動してください。"
        pendingTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.isPending = false
            self.pendingTask = nil
            self.show()
        }
    }

    func stop(reason: String = "Dismiss") {
        pendingTask?.cancel()
        pendingTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        isPending = false
        isShowing = false
        closePanels()
        message = reason
    }

    private func show() {
        isShowing = true
        rebuildPanels()
        guard isShowing else { return }
        message = "\(screenCount)画面へ表示要求中。15秒で自動停止します。"
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
            } catch { return }
            guard !Task.isCancelled else { return }
            self?.stop(reason: "15秒経過で自動停止")
        }
    }

    private func rebuildPanels() {
        closePanels()
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            stop(reason: "利用可能なディスプレイがありません。")
            return
        }
        for (index, screen) in screens.enumerated() {
            let panel = ProbePanel(
                contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.title = "Overlay検証 \(index + 1)"
            panel.level = .floating
            panel.collectionBehavior = mode.behavior
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            panel.isReleasedWhenClosed = false
            panel.onDismiss = { [weak self] in self?.stop(reason: "Esc / Dismiss") }
            panel.contentView = NSHostingView(
                rootView: SampleOverlay(
                    screenNumber: index + 1, mode: mode.rawValue,
                    dismiss: { [weak self] in self?.stop() },
                    quit: { NSApp.terminate(nil) }))
            panels.append(panel)
            panel.orderFrontRegardless()
        }
        screenCount = panels.count
        // 最初に一度だけキー対象を設定し、以後はユーザーのクリックに任せる。
        panels.first?.makeKey()
    }

    private func closePanels() {
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.onDismiss = nil
            panel.close()
        }
        panels = []
        screenCount = 0
    }
}

@MainActor
final class ProbePanel: NSPanel {
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { onDismiss?() }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && !isKeyWindow { makeKey() }
        super.sendEvent(event)
    }
}
