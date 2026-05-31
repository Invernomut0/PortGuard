// PortGuardCore/Sources/PortGuardCore/ProcessMonitor.swift
import AppKit

@MainActor
public final class ProcessMonitor {
    public var onLaunch: ((ProcessRecord) -> Void)?
    public var onTerminate: ((ProcessRecord) -> Void)?

    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func start() {
        let ws = NSWorkspace.shared.notificationCenter

        let launchObs = ws.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let record = ProcessRecord(
                pid: Int(app.processIdentifier),
                name: app.localizedName ?? app.executableURL?.lastPathComponent ?? "unknown",
                bundleIdentifier: app.bundleIdentifier
            )
            self?.onLaunch?(record)
        }

        let terminateObs = ws.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let record = ProcessRecord(
                pid: Int(app.processIdentifier),
                name: app.localizedName ?? app.executableURL?.lastPathComponent ?? "unknown",
                bundleIdentifier: app.bundleIdentifier
            )
            self?.onTerminate?(record)
        }

        observers = [launchObs, terminateObs]
    }

    public func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
    }
}
