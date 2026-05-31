import SwiftUI
import PortGuardCore

@main
struct PortGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(licenseManager: appDelegate.licenseManager)
        }
    }
}
