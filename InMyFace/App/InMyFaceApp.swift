import AppKit
import SwiftUI

@main
struct InMyFaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppLifecycleManager(
        isDemo: ProcessInfo.processInfo.arguments.contains("--demo"))
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private let nextItem = NSMenuItem(title: "予定なし", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "一時停止", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
            defer: false)
        window.title = "In My Face"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        self.window = window
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "calendar.badge.clock", accessibilityDescription: "In My Face")
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(nextItem)
        menu.addItem(.separator())
        addItem("設定・今日の予定", action: #selector(showWindow), to: menu)
        pauseItem.target = self
        pauseItem.action = #selector(togglePause)
        menu.addItem(pauseItem)
        addItem("予定を更新", action: #selector(refresh), to: menu)
        menu.addItem(.separator())
        addItem("In My Faceを終了", action: #selector(quit), key: "q", to: menu)
        item.menu = menu
        statusItem = item
        model.start()
        showWindow()
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let event = model.nextEvent {
            nextItem.title =
                "\(event.start.formatted(date: .omitted, time: .shortened)) \(event.displayTitle)"
        } else {
            nextItem.title = model.message
        }
        pauseItem.title = model.isPaused ? "再開" : "一時停止"
    }

    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
    private func addItem(_ title: String, action: Selector, key: String = "", to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    @objc private func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    @objc private func togglePause() { model.setPaused(!model.isPaused) }
    @objc private func refresh() { model.refresh() }
    @objc private func quit() { NSApp.terminate(nil) }
}
