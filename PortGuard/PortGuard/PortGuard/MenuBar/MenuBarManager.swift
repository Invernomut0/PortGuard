import AppKit
import SwiftUI
import PortGuardCore

@MainActor
final class MenuBarManager {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let dataStore: DataStore

    init(dataStore: DataStore, licenseManager: LicenseManager, alertEngine: AlertEngine, exportManager: ExportManager) {
        self.dataStore = dataStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(
                licenseManager: licenseManager,
                exportManager: exportManager,
                alertEngine: alertEngine
            )
            .environment(dataStore)
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PortGuard")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PortGuard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func updateBadge(connectionCount: Int, hasActiveAlert: Bool) {
        guard let button = statusItem.button else { return }
        if hasActiveAlert {
            button.image = NSImage(systemSymbolName: "network.badge.shield.half.filled", accessibilityDescription: "PortGuard — Alert")
        } else {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PortGuard")
        }
        button.title = connectionCount > 0 ? " \(connectionCount)" : ""
    }
}
