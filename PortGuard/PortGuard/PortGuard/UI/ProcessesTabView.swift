import SwiftUI
import PortGuardCore

struct ProcessesTabView: View {
    @Environment(DataStore.self) var dataStore
    @State private var expandedPID: Int?

    var body: some View {
        List {
            ForEach(dataStore.processSummaries) { summary in
                ProcessRowView(summary: summary, isExpanded: expandedPID == summary.pid) {
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
    let onTap: () -> Void

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
