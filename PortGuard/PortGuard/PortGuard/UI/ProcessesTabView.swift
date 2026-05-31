import SwiftUI
import PortGuardCore

struct ProcessesTabView: View {
    @Environment(DataStore.self) var dataStore
    @Environment(\.isPro) var isPro
    @State private var expandedPID: Int?

    var body: some View {
        List {
            ForEach(dataStore.processSummaries) { summary in
                ProcessRowView(summary: summary, isExpanded: expandedPID == summary.pid, isPro: isPro) {
                    expandedPID = expandedPID == summary.pid ? nil : summary.pid
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ProcessRowView: View {
    let summary: ProcessSummary
    let isExpanded: Bool
    let isPro: Bool
    let onTap: () -> Void

    @State private var showingKillConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "app.fill")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Text(summary.name)
                        .fontWeight(.medium)
                    Spacer()
                    Text("PID \(summary.pid)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.connectionCount)")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
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
                            "Terminare \(summary.name) (PID \(summary.pid))?",
                            isPresented: $showingKillConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Termina", role: .destructive) {
                                Foundation.kill(pid_t(summary.pid), SIGTERM)
                            }
                        } message: {
                            Text("Il processo verrà chiuso immediatamente.")
                        }
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(summary.connections) { conn in
                    ConnectionDetailRow(connection: conn)
                        .padding(.leading, 28)
                }
            }
        }
    }
}

struct ConnectionDetailRow: View {
    let connection: ConnectionRecord

    var body: some View {
        HStack {
            Text(":\(connection.localPort)")
                .font(.caption.monospaced())
            if let remote = connection.remoteHost {
                Text("→ \(remote):\(connection.remotePort ?? 0)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(connection.state.rawValue)
                .font(.caption)
                .foregroundStyle(connection.state == .listen ? .green : .blue)
        }
    }
}
