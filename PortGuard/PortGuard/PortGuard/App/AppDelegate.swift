import AppKit
import SwiftUI
import PortGuardCore
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dataStore = DataStore()
    let licenseManager = LicenseManager()
    let alertEngine = AlertEngine()
    let exportManager = ExportManager()
    private let poller = LsofPoller()
    private let processMonitor = ProcessMonitor()
    private var menuBarManager: MenuBarManager?
    private var quickLookupWindow: NSPanel?
    private var quickLookupQuery = ""
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager(
            dataStore: dataStore,
            licenseManager: licenseManager,
            alertEngine: alertEngine,
            exportManager: exportManager
        )

        poller.onDiff = { [weak self] diff in
            Task { @MainActor in
                self?.dataStore.apply(diff: diff)
                if self?.licenseManager.isPro == true {
                    self?.alertEngine.evaluate(diff: diff)
                }
            }
        }
        processMonitor.onLaunch = { _ in }
        processMonitor.onTerminate = { _ in }

        poller.start()
        processMonitor.start()
        registerGlobalShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        poller.stop()
        processMonitor.stop()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }

    private func registerGlobalShortcut() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, refCon in
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refCon!).takeUnretainedValue()
                Task { @MainActor in delegate.showQuickLookup() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
        var hotKeyID = EventHotKeyID(signature: OSType(0x5047_5244), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    @MainActor
    func showQuickLookup() {
        if let win = quickLookupWindow, win.isVisible {
            win.orderOut(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 60),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false

        panel.contentView = NSHostingView(rootView:
            QuickLookupView(
                query: Binding(
                    get: { self.quickLookupQuery },
                    set: { self.quickLookupQuery = $0 }
                ),
                onDismiss: { [weak panel] in panel?.orderOut(nil) }
            )
            .environment(dataStore)
        )
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        quickLookupWindow = panel
    }
}
