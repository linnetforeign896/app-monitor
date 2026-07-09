import AppKit
import SwiftUI

enum AppLifecycleSettings {
    private static let keepRunningWhenClosedKey = "AppMonitorKeepRunningWhenClosed"

    static var keepRunningWhenClosed: Bool {
        get {
            UserDefaults.standard.bool(forKey: keepRunningWhenClosedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keepRunningWhenClosedKey)
            NotificationCenter.default.post(name: .appMonitorKeepRunningWhenClosedChanged, object: nil)
        }
    }
}

@MainActor
final class DashboardWindowLifecycleController: NSObject, NSWindowDelegate {
    static let shared = DashboardWindowLifecycleController()

    private weak var dashboardWindow: NSWindow?

    func attach(to window: NSWindow?) {
        guard let window, window !== dashboardWindow else { return }
        dashboardWindow = window
        window.identifier = NSUserInterfaceItemIdentifier(appMonitorDashboardWindowID)
        window.isReleasedWhenClosed = false
        window.delegate = self
        installCloseButtonHandler(for: window)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard AppLifecycleSettings.keepRunningWhenClosed else {
            return true
        }

        hideDashboardWindow(sender)
        return false
    }

    @objc private func closeDashboardWindow(_ sender: Any?) {
        guard let window = dashboardWindow else { return }

        guard AppLifecycleSettings.keepRunningWhenClosed else {
            window.delegate = nil
            window.close()
            return
        }

        hideDashboardWindow(window)
    }

    private func installCloseButtonHandler(for window: NSWindow) {
        guard let closeButton = window.standardWindowButton(.closeButton) else { return }
        closeButton.target = self
        closeButton.action = #selector(closeDashboardWindow(_:))
    }

    private func hideDashboardWindow(_ sender: NSWindow) {
        sender.orderOut(nil)
        if NSApp.windows.allSatisfy({ !$0.isVisible || $0 == sender || $0 is NSPanel }) {
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.async {
                MenuBarController.shared.rebuildStatusItem()
            }
        }
    }
}

struct DashboardWindowLifecycleInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onWindowChanged = { window in
            DashboardWindowLifecycleController.shared.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowReaderView, context: Context) {
        nsView.onWindowChanged = { window in
            DashboardWindowLifecycleController.shared.attach(to: window)
        }
        DispatchQueue.main.async {
            DashboardWindowLifecycleController.shared.attach(to: nsView.window)
        }
    }

    final class WindowReaderView: NSView {
        var onWindowChanged: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChanged?(window)
        }
    }
}
