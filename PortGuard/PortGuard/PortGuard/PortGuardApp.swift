import SwiftUI
import PortGuardCore

@main
struct PortGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsPlaceholderView()
        }
    }
}

// Placeholder until SettingsView is implemented in Task 9
struct SettingsPlaceholderView: View {
    var body: some View {
        Text("Settings coming soon")
            .frame(width: 400, height: 300)
    }
}
