import AppKit
import PortGuardCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dataStore = DataStore()
    private let poller = LsofPoller()
    private let processMonitor = ProcessMonitor()
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager(dataStore: dataStore)

        poller.onDiff = { [weak self] diff in
            Task { @MainActor in self?.dataStore.apply(diff: diff) }
        }
        processMonitor.onLaunch = { _ in }
        processMonitor.onTerminate = { _ in }

        poller.start()
        processMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        poller.stop()
        processMonitor.stop()
    }
}
