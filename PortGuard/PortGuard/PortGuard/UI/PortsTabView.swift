import SwiftUI
import PortGuardCore

struct PortsTabView: View {
    @Environment(DataStore.self) var dataStore

    var body: some View {
        List {
            ForEach(dataStore.filteredListenPorts) { port in
                PortRowView(port: port, isPro: dataStore.showAllPorts)
            }

            if dataStore.hiddenHighPortsCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("\(dataStore.hiddenHighPortsCount) porte >1024 nascoste")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Pro")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange, in: Capsule())
                }
                .listRowBackground(Color.orange.opacity(0.08))
            }
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
