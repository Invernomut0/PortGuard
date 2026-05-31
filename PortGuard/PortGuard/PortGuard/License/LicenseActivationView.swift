import SwiftUI

struct LicenseActivationView: View {
    @State var licenseManager: LicenseManager
    @State private var keyInput = ""

    var body: some View {
        if licenseManager.isPro {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Pro — activated")
                Spacer()
                Button("Deactivate") { licenseManager.deactivate() }
                    .foregroundStyle(.red)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("License key", text: $keyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Activate") {
                        Task { await licenseManager.activate(key: keyInput) }
                    }
                    .disabled(keyInput.isEmpty || licenseManager.isValidating)
                }
                if let error = licenseManager.activationError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Link("Buy Pro — €15", destination: URL(string: "https://gumroad.com/l/portguard")!)
                    .font(.caption)
            }
        }
    }
}
