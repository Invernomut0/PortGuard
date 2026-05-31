import SwiftUI
import PortGuardCore

struct QuickLookupView: View {
    @Environment(DataStore.self) var dataStore
    @Binding var query: String
    var onDismiss: () -> Void

    var results: [ConnectionRecord] {
        guard !query.isEmpty else { return [] }
        return Array(dataStore.connections.filter {
            $0.processName.lowercased().contains(query.lowercased()) ||
            String($0.localPort).contains(query) ||
            ($0.remoteHost?.contains(query) ?? false)
        }.prefix(10))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search port or process...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
            }
            .padding(16)

            if !results.isEmpty {
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { conn in
                            HStack {
                                Text(conn.processName)
                                    .fontWeight(.medium)
                                Text(":\(conn.localPort)")
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(conn.state.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .frame(width: 500)
        .onExitCommand { onDismiss() }
    }
}
