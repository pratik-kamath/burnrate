import AppKit
import SwiftUI
import BurnrateCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel!
    private var store: UsageStore!
    private var coordinator: RefreshCoordinator!
    private let dispatcher = UNNotificationDispatcher()
    private var notifier: MilestoneNotifier!

    func applicationDidFinishLaunching(_ notification: Notification) {
        dispatcher.requestAuthorization()

        store = UsageStore()
        notifier = MilestoneNotifier(dispatcher: dispatcher)
        coordinator = RefreshCoordinator(
            store: store,
            claude: ClaudeUsageProvider(tokenStore: KeychainTokenStore(), http: URLSessionHTTPClient()),
            codex: CodexUsageProvider(),
            notifier: notifier
        )

        let view = OverlayView(store: store).environment(\.colorScheme, .dark)
        panel = OverlayPanel(content: view)
        panel.orderFrontRegardless()
        attachContextMenu()
        coordinator.start()
    }

    private func attachContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        let notif = NSMenuItem(title: "Notifications", action: #selector(toggleNotifications), keyEquivalent: "")
        notif.state = .on
        menu.addItem(notif)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit burnrate", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        panel.contentView?.menu = menu
    }

    @objc private func refreshNow() { coordinator.refreshNow() }
    @objc private func toggleNotifications(_ sender: NSMenuItem) {
        notifier.enabled.toggle()
        sender.state = notifier.enabled ? .on : .off
    }
    @objc private func quit() {
        panel.savePosition()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel?.savePosition()
        coordinator?.stop()
    }
}
