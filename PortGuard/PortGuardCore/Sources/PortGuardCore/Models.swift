// PortGuardCore/Sources/PortGuardCore/Models.swift
import Foundation

public enum ConnectionState: String, Codable, Hashable {
    case listen = "LISTEN"
    case established = "ESTABLISHED"
    case closeWait = "CLOSE_WAIT"
    case timeWait = "TIME_WAIT"
    case unknown
}

public enum ConnectionProtocol: String, Codable, Hashable {
    case tcp = "TCP"
    case udp = "UDP"
    case tcp6 = "TCP6"
    case udp6 = "UDP6"
}

public struct ConnectionRecord: Equatable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let pid: Int
    public let processName: String
    public let localPort: Int
    public let remoteHost: String?
    public let remotePort: Int?
    public let state: ConnectionState
    public let `protocol`: ConnectionProtocol
    public let timestamp: Date

    public init(pid: Int, processName: String, localPort: Int,
                remoteHost: String?, remotePort: Int?,
                state: ConnectionState, protocol proto: ConnectionProtocol,
                timestamp: Date = Date()) {
        self.id = UUID()
        self.pid = pid
        self.processName = processName
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.state = state
        self.protocol = proto
        self.timestamp = timestamp
    }

    public static func == (lhs: ConnectionRecord, rhs: ConnectionRecord) -> Bool {
        lhs.pid == rhs.pid &&
        lhs.processName == rhs.processName &&
        lhs.localPort == rhs.localPort &&
        lhs.remoteHost == rhs.remoteHost &&
        lhs.remotePort == rhs.remotePort &&
        lhs.state == rhs.state &&
        lhs.protocol == rhs.protocol
    }
}

public struct PortRecord: Equatable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let port: Int
    public let `protocol`: ConnectionProtocol
    public let pid: Int
    public let processName: String
    public let isSigned: Bool

    public init(port: Int, protocol proto: ConnectionProtocol, pid: Int,
                processName: String, isSigned: Bool = true) {
        self.id = UUID()
        self.port = port
        self.protocol = proto
        self.pid = pid
        self.processName = processName
        self.isSigned = isSigned
    }
}

public struct ProcessRecord: Equatable, Hashable, Codable, Identifiable {
    public let pid: Int
    public let name: String
    public let bundleIdentifier: String?
    public var id: Int { pid }

    public init(pid: Int, name: String, bundleIdentifier: String? = nil) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct LsofDiff: Equatable {
    public let added: [ConnectionRecord]
    public let removed: [ConnectionRecord]
    public let unchanged: [ConnectionRecord]

    public var isEmpty: Bool { added.isEmpty && removed.isEmpty }

    public init(added: [ConnectionRecord], removed: [ConnectionRecord], unchanged: [ConnectionRecord]) {
        self.added = added
        self.removed = removed
        self.unchanged = unchanged
    }
}

public struct AlertRule: Codable, Identifiable {
    public enum Trigger: String, Codable {
        case portOpened, portClosed, newOutboundConnection, processConnected
    }
    public let id: UUID
    public var name: String
    public var trigger: Trigger
    public var portFilter: Int?
    public var processFilter: String?
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, trigger: Trigger,
                portFilter: Int? = nil, processFilter: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.portFilter = portFilter
        self.processFilter = processFilter
        self.isEnabled = isEnabled
    }
}
