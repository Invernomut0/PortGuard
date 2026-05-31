import Foundation
import PortGuardCore

struct ConnectionSnapshot: Codable {
    let timestamp: Date
    let connectionsJSON: Data
}

@MainActor
final class HistoryStore {
    private let storageURL: URL
    private var snapshotTimer: Timer?
    var snapshotInterval: TimeInterval = 300

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("PortGuard")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("history.json")
    }

    func startSnapshots(dataStore: DataStore) {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self, weak dataStore] _ in
            guard let self, let dataStore else { return }
            Task { @MainActor in self.snapshot(connections: dataStore.connections) }
        }
    }

    func stopSnapshots() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    func snapshot(connections: [ConnectionRecord]) {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        var all = loadAll()
        all.append(ConnectionSnapshot(timestamp: Date(), connectionsJSON: data))
        // Keep last 288 snapshots (24h at 5min intervals)
        if all.count > 288 { all = Array(all.suffix(288)) }
        if let encoded = try? JSONEncoder().encode(all) {
            try? encoded.write(to: storageURL)
        }
    }

    func snapshots(from: Date, to: Date) -> [ConnectionSnapshot] {
        loadAll().filter { $0.timestamp >= from && $0.timestamp <= to }
    }

    func allSnapshots() -> [ConnectionSnapshot] {
        loadAll().sorted { $0.timestamp > $1.timestamp }
    }

    private func loadAll() -> [ConnectionSnapshot] {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ConnectionSnapshot].self, from: data) else { return [] }
        return decoded
    }
}
