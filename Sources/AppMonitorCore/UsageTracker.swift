import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class UsageTracker: ObservableObject {
    @Published public private(set) var activeAppName: String = "None"
    @Published public private(set) var statusText: String = "Starting"
    @Published public private(set) var isPaused: Bool = false

    public var idleThreshold: TimeInterval

    private let dataStore: AppDataStore
    private let inventoryScanner: AppInventoryScanner
    private var activeApp: MonitoredApp?
    private var activeStart: Date?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    public init(
        dataStore: AppDataStore,
        inventoryScanner: AppInventoryScanner = AppInventoryScanner(),
        idleThreshold: TimeInterval = 300
    ) {
        self.dataStore = dataStore
        self.inventoryScanner = inventoryScanner
        self.idleThreshold = idleThreshold
    }

    deinit {
        timer?.invalidate()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func start() {
        installObservers()
        if let runningApp = NSWorkspace.shared.frontmostApplication {
            activate(runningApp, at: Date())
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdleState()
            }
        }
        statusText = "Tracking"
    }

    public func stop() {
        endCurrent(at: Date())
        timer?.invalidate()
        timer = nil
        statusText = "Stopped"
    }

    public func flush() {
        endCurrent(at: Date())
        if let runningApp = NSWorkspace.shared.frontmostApplication {
            activate(runningApp, at: Date())
        }
    }

    private func installObservers() {
        guard observers.isEmpty else { return }
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.activate(app, at: Date())
            }
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pause(reason: "Screen sleeping") }
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pause(reason: "Session inactive") }
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.resumeIfPossible(reason: "Screen awake") }
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.resumeIfPossible(reason: "Session active") }
        })
    }

    private func activate(_ runningApplication: NSRunningApplication, at date: Date) {
        guard runningApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        guard let app = inventoryScanner.app(for: runningApplication) else {
            endCurrent(at: date)
            activeApp = nil
            activeStart = nil
            activeAppName = runningApplication.localizedName ?? "Unknown"
            statusText = "Tracking unknown app"
            return
        }

        if activeApp?.id == app.id, !isPaused {
            return
        }

        endCurrent(at: date)
        activeApp = app
        activeStart = date
        activeAppName = app.name
        isPaused = false
        statusText = "Tracking \(app.name)"

        try? dataStore.upsertApps([app])
    }

    private func checkIdleState() {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        if idleSeconds >= idleThreshold, !isPaused {
            let pauseAt = Date().addingTimeInterval(-idleThreshold)
            pause(reason: "Idle", at: pauseAt)
        } else if idleSeconds < idleThreshold, isPaused {
            resumeIfPossible(reason: "Activity resumed")
        }
    }

    private func pause(reason: String, at date: Date = Date()) {
        endCurrent(at: date)
        isPaused = true
        statusText = reason
    }

    private func resumeIfPossible(reason: String) {
        guard let runningApp = NSWorkspace.shared.frontmostApplication else {
            statusText = reason
            return
        }
        isPaused = false
        activate(runningApp, at: Date())
    }

    private func endCurrent(at date: Date) {
        guard let activeApp, let activeStart else { return }
        let endDate = max(date, activeStart)
        let segment = UsageSegment(
            appID: activeApp.id,
            bundleIdentifier: activeApp.bundleIdentifier,
            appName: activeApp.name,
            appPath: activeApp.path,
            startedAt: activeStart,
            endedAt: endDate
        )
        try? dataStore.insertUsageSegment(segment)
        self.activeStart = nil
    }
}
