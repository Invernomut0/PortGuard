// PortGuardCore/Sources/PortGuardCore/DataStore.swift
import Foundation
import Observation

@Observable
@MainActor
public final class DataStore {
    public private(set) var connections: [ConnectionRecord] = []
    public private(set) var listenPorts: [PortRecord] = []
    public var searchQuery: String = ""
    /// Quando false (free) mostra solo porte ≤1024; impostare a true per utenti Pro.
    public var showAllPorts: Bool = false

    public init() {}

    public var filteredConnections: [ConnectionRecord] {
        guard !searchQuery.isEmpty else { return connections }
        let q = searchQuery.lowercased()
        return connections.filter {
            $0.processName.lowercased().contains(q) ||
            String($0.localPort).contains(q) ||
            ($0.remoteHost?.lowercased().contains(q) ?? false)
        }
    }

    public var filteredListenPorts: [PortRecord] {
        let base = showAllPorts ? listenPorts : listenPorts.filter { $0.port <= 1024 }
        guard !searchQuery.isEmpty else { return base }
        let q = searchQuery.lowercased()
        return base.filter {
            $0.processName.lowercased().contains(q) ||
            String($0.port).contains(q)
        }
    }

    public var hiddenHighPortsCount: Int {
        guard !showAllPorts else { return 0 }
        return listenPorts.filter { $0.port > 1024 }.count
    }

    public var outboundConnections: [ConnectionRecord] {
        filteredConnections.filter { $0.state == .established && $0.remoteHost != nil }
    }

    public var processSummaries: [ProcessSummary] {
        let groups = Dictionary(grouping: filteredConnections, by: { $0.pid })
        return groups.map { pid, conns in
            ProcessSummary(pid: pid, name: conns.first?.processName ?? "", connections: conns)
        }.sorted { ($0.name, $0.pid) < ($1.name, $1.pid) }
    }

    public func apply(diff: LsofDiff) {
        let removedSet = Set(diff.removed)
        connections.removeAll { removedSet.contains($0) }
        let existingSet = Set(connections)
        connections.append(contentsOf: diff.added.filter { !existingSet.contains($0) })
        rebuildListenPorts()
    }

    private func rebuildListenPorts() {
        listenPorts = connections
            .filter { $0.state == .listen }
            .map { conn in
                PortRecord(port: conn.localPort, protocol: conn.protocol,
                           pid: conn.pid, processName: conn.processName)
            }
    }
}

public struct ProcessSummary: Identifiable {
    public let pid: Int
    public let name: String
    public let connections: [ConnectionRecord]
    public var id: Int { pid }
    public var connectionCount: Int { connections.count }
}
