import SwiftUI
import PortGuardCore

struct PortsTabView: View {
    @Environment(DataStore.self) var dataStore

    var body: some View {
        List(dataStore.filteredListenPorts) { port in
            HStack {
                Text(":\(port.port)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(port.protocol.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Text(port.processName)
                    .foregroundStyle(.secondary)
                Text("PID \(port.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !port.isSigned {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .help("Process is not code-signed")
                }
            }
        }
        .listStyle(.plain)
    }
}
