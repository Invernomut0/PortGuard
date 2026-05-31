// PortGuardCore/Sources/PortGuardCore/LsofPoller.swift
import Foundation

public enum LsofParser {
    public static func parse(output: String) -> [ConnectionRecord] {
        var results: [ConnectionRecord] = []
        let lines = output.components(separatedBy: "\n").dropFirst()

        for line in lines {
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }

            let command = String(parts[0]).replacingOccurrences(of: "\\x20", with: " ")
            guard let pid = Int(parts[1]) else { continue }
            let nameField = String(parts[parts.count - 1])
            let addressField = String(parts[parts.count - 2])
            let typeField = String(parts[4])

            guard typeField == "IPv4" || typeField == "IPv6" else { continue }

            let protocolField = parts.count > 7 ? String(parts[7]) : "TCP"
            let proto: ConnectionProtocol
            switch protocolField {
            case "TCP": proto = .tcp
            case "UDP": proto = .udp
            case "TCP6": proto = .tcp6
            case "UDP6": proto = .udp6
            default: proto = .tcp
            }
            let state = parseState(nameField)
            let (localPort, remoteHost, remotePort) = parseAddress(addressField)

            guard localPort > 0 else { continue }

            results.append(ConnectionRecord(
                pid: pid,
                processName: command,
                localPort: localPort,
                remoteHost: remoteHost,
                remotePort: remotePort,
                state: state,
                protocol: proto
            ))
        }
        return results
    }

    private static func parseState(_ raw: String) -> ConnectionState {
        switch raw {
        case "(LISTEN)": return .listen
        case "(ESTABLISHED)": return .established
        case "(CLOSE_WAIT)": return .closeWait
        case "(TIME_WAIT)": return .timeWait
        default: return .unknown
        }
    }

    private static func parseAddress(_ address: String) -> (localPort: Int, remoteHost: String?, remotePort: Int?) {
        if address.contains("->") {
            let parts = address.components(separatedBy: "->")
            let localPort = portFromAddressPart(parts[0])
            let (remoteHost, remotePort) = hostPortFromAddressPart(parts[1])
            return (localPort, remoteHost, remotePort)
        } else {
            return (portFromAddressPart(address), nil, nil)
        }
    }

    private static func portFromAddressPart(_ part: String) -> Int {
        guard let colonIdx = part.lastIndex(of: ":") else { return 0 }
        return Int(String(part[part.index(after: colonIdx)...])) ?? 0
    }

    private static func hostPortFromAddressPart(_ part: String) -> (String, Int?) {
        guard let colonIdx = part.lastIndex(of: ":") else { return (part, nil) }
        let host = String(part[..<colonIdx])
        let port = Int(String(part[part.index(after: colonIdx)...]))
        return (host, port)
    }
}

public enum LsofDiffEngine {
    public static func diff(previous: [ConnectionRecord], current: [ConnectionRecord]) -> LsofDiff {
        let prevSet = Set(previous)
        let currSet = Set(current)
        return LsofDiff(
            added: current.filter { !prevSet.contains($0) },
            removed: previous.filter { !currSet.contains($0) },
            unchanged: current.filter { prevSet.contains($0) }
        )
    }
}

@MainActor
public final class LsofPoller {
    public var onDiff: ((LsofDiff) -> Void)?
    public var interval: TimeInterval = 5.0 {
        didSet { restartTimer() }
    }

    private var timer: Timer?
    private var previous: [ConnectionRecord] = []

    public init() {}

    public func start() {
        poll()
        scheduleTimer()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func restartTimer() {
        stop()
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        Task {
            let output = await Task.detached(priority: .utility) {
                self.runLsof()
            }.value
            let current = LsofParser.parse(output: output)
            let diff = LsofDiffEngine.diff(previous: self.previous, current: current)
            self.previous = current
            if !diff.isEmpty {
                self.onDiff?(diff)
            }
        }
    }

    private nonisolated func runLsof() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["+c", "0", "-i", "-n", "-P"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
