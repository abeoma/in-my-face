import AppKit
import SwiftUI

@main
struct OverlayProbeApp: App {
    @NSApplicationDelegateAdaptor(ProbeAppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class ProbeAppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = OverlayCoordinator()
    private var controlWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 470),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Overlay検証"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ProbeControls(coordinator: coordinator))
        window.center()
        controlWindow = window

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Overlay検証")
        let menu = NSMenu()
        addItem("検証画面を開く", action: #selector(showControls), to: menu)
        addItem("表示・予約を停止", action: #selector(stop), to: menu)
        menu.addItem(.separator())
        addItem("OverlayProbeを終了", action: #selector(quit), key: "q", to: menu)
        item.menu = menu
        statusItem = item
        showControls()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop(reason: "終了")
    }

    private func addItem(_ title: String, action: Selector, key: String = "", to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func showControls() {
        controlWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func stop() { coordinator.stop(reason: "メニューバーから停止") }

    @objc private func quit() { NSApp.terminate(nil) }
}
