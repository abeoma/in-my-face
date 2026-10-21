import AppKit
import Combine
import SwiftUI

@MainActor
final class AlertCoordinator: ObservableObject {
    @Published private(set) var events: [EventSnapshot] = []
    @Published var selectedID: OccurrenceKey?
    var onDismiss: ((EventSnapshot) -> Void)?
    @Published private(set) var joinErrors: [OccurrenceKey: String] = [:]
    @Published var selectedLinks: [OccurrenceKey: URL] = [:]
    private var panels: [AlertPanel] = []
    private let openURL: (URL) -> Bool

    init(openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.openURL = openURL
    }

    func synchronize(_ events: [EventSnapshot], showsPanels: Bool = true) {
        self.events = events
        let ids = Set(events.map(\.id))
        joinErrors = joinErrors.filter { ids.contains($0.key) }
        selectedLinks = selectedLinks.filter { key, url in
            events.contains { $0.id == key && $0.meetingLinks.contains { $0.url == url } }
        }
        if !events.contains(where: { $0.id == selectedID }) { selectedID = events.first?.id }
        if events.isEmpty {
            closePanels()
        } else if showsPanels && panels.isEmpty {
            rebuildPanels()
        }
    }

    func join(_ event: EventSnapshot) {
        guard let current = events.first(where: { $0.id == event.id }),
            let url = selectedLinks[event.id] ?? current.meetingLinks.first?.url,
            current.meetingLinks.contains(where: { $0.url == url })
        else { return }
        if openURL(url) {
            joinErrors[event.id] = nil
            onDismiss?(current)
        } else {
            joinErrors[event.id] = "会議URLを開けませんでした。もう一度Joinを押してください。"
        }
    }

    func dismissSelected() {
        guard let event = events.first(where: { $0.id == selectedID }) else { return }
        onDismiss?(event)
    }

    func rebuildPanels() {
        closePanels()
        guard !events.isEmpty else { return }
        for screen in NSScreen.screens {
            let panel = AlertPanel(
                contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.title = "In My Face — 会議リマインダー"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            panel.isReleasedWhenClosed = false
            panel.onEscape = { [weak self] in self?.dismissSelected() }
            panel.contentView = NSHostingView(rootView: AlertView(coordinator: self))
            panels.append(panel)
            panel.orderFrontRegardless()
        }
        // 一度だけキー対象を指定し、以後はユーザーの操作に任せる。
        panels.first?.makeKey()
    }

    private func closePanels() {
        for panel in panels {
            panel.orderOut(nil)
            panel.onEscape = nil
            panel.contentView = nil
            panel.close()
        }
        panels = []
    }
}

@MainActor
final class AlertPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && !isKeyWindow { makeKey() }
        super.sendEvent(event)
    }
}
