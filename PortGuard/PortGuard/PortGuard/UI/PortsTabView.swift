import SwiftUI
import PortGuardCore

struct PortsTabView: View {
    @Environment(DataStore.self) var dataStore
    @Environment(\.isPro) var isPro

    var body: some View {
        List(dataStore.filteredListenPorts) { port in
            PortRowView(port: port, isPro: isPro)
        }
        .listStyle(.plain)
    }
}

private struct PortRowView: View {
    let port: PortRecord
    let isPro: Bool

    @State private var showingKillConfirm = false

    var body: some View {
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
                    .help("Il processo non è code-signed")
            }
            if isPro {
                Button {
                    showingKillConfirm = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Termina processo")
                .confirmationDialog(
                    "Terminare \(port.processName) (PID \(port.pid))?",
                    isPresented: $showingKillConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Termina", role: .destructive) {
                        Foundation.kill(pid_t(port.pid), SIGTERM)
                    }
                } message: {
                    Text("Il processo in ascolto sulla porta \(port.port) verrà chiuso.")
                }
            }
        }
    }
}
