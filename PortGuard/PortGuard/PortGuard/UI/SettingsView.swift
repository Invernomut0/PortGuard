import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @State var licenseManager: LicenseManager

    var body: some View {
        Form {
            Section("General") {
                Picker("Refresh interval", selection: $refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        if enabled {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            }

            Section("License") {
                LicenseActivationView(licenseManager: licenseManager)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                Link("GitHub", destination: URL(string: "https://github.com/lorenzov/portguard")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 400)
    }
}
