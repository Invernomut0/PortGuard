import SwiftUI
import PortGuardCore

struct ConnectionsTabView: View {
    @Environment(DataStore.self) var dataStore
    @State private var resolvedHosts: [String: String] = [:]

    var body: some View {
        List(dataStore.outboundConnections) { conn in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conn.processName)
                        .fontWeight(.medium)
                    Text("Local :\(conn.localPort)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(resolvedHosts[conn.remoteHost ?? ""] ?? conn.remoteHost ?? "")
                        .font(.caption.monospaced())
                    if let remotePort = conn.remotePort {
                        Text(":\(remotePort)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task(id: conn.remoteHost) {
                guard let host = conn.remoteHost, resolvedHosts[host] == nil else { return }
                resolvedHosts[host] = await reverseDNS(host)
            }
        }
        .listStyle(.plain)
    }

    private func reverseDNS(_ ip: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let host = CFHostCreateWithName(nil, ip as CFString).takeRetainedValue()
                CFHostStartInfoResolution(host, .names, nil)
                var resolved = DarwinBoolean(false)
                if let names = CFHostGetNames(host, &resolved)?.takeUnretainedValue() as? [String],
                   !names.isEmpty {
                    continuation.resume(returning: names[0])
                } else {
                    continuation.resume(returning: ip)
                }
            }
        }
    }
}
