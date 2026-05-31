import Foundation

public struct PacketRecord: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: String
    public let source: String
    public let destination: String
    public let proto: String
    public let length: Int
    public let info: String

    public init(id: UUID = UUID(), timestamp: String, source: String,
                destination: String, proto: String, length: Int, info: String) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.destination = destination
        self.proto = proto
        self.length = length
        self.info = info
    }
}

@Observable
@MainActor
public final class PacketSniffer {
    public private(set) var packets: [PacketRecord] = []
    public private(set) var isRunning = false
    public private(set) var error: String?
    public var processName: String = ""
    public var ports: [Int] = []

    private var task: Process?
    private var pipe: Pipe?
    private var readTask: Task<Void, Never>?

    public init() {}

    public func start() {
        guard !ports.isEmpty else { return }
        packets = []
        error = nil
        isRunning = true

        let portFilter = ports.map { "port \($0)" }.joined(separator: " or ")

        // tcpdump requires root; use osascript to prompt once for credentials
        let cmd = "/usr/sbin/tcpdump -i any -l -n -tt '\(portFilter)' 2>&1"
        let script = "do shell script \"\(cmd)\" with administrator privileges"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]

        let outputPipe = Pipe()
        proc.standardOutput = outputPipe
        proc.standardError = outputPipe

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }

        do {
            try proc.run()
        } catch {
            self.error = "Impossibile avviare tcpdump: \(error.localizedDescription)"
            isRunning = false
            return
        }

        task = proc
        pipe = outputPipe

        readTask = Task.detached(priority: .utility) { [weak self, outputPipe] in
            let handle = outputPipe.fileHandleForReading
            var buffer = ""
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                guard let chunk = String(data: data, encoding: .utf8) else { continue }
                buffer += chunk
                let lines = buffer.components(separatedBy: "\n")
                buffer = lines.last ?? ""
                for line in lines.dropLast() {
                    guard !line.isEmpty else { continue }
                    if let record = PacketParser.parse(line: line) {
                        await MainActor.run { [weak self] in
                            self?.packets.append(record)
                            // Cap a 500 pacchetti per evitare memory bloat
                            if let count = self?.packets.count, count > 500 {
                                self?.packets.removeFirst(count - 500)
                            }
                        }
                    }
                }
            }
        }
    }

    public func stop() {
        task?.terminate()
        task = nil
        readTask?.cancel()
        readTask = nil
        isRunning = false
    }
}

public enum PacketParser {
    // Esempio linea tcpdump: 1717150000.123456 IP 192.168.1.1.52345 > 93.184.216.34.443: Flags [P.], seq 1:100, ack 1, win 2048, length 99
    public static func parse(line: String) -> PacketRecord? {
        let parts = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
        guard parts.count >= 5 else { return nil }

        let timestamp = String(parts[0])
        // Skip non-packet lines (tcpdump header, verbose info, etc.)
        guard timestamp.contains("."), Double(timestamp) != nil else { return nil }

        let proto = String(parts[1]) // "IP" or "IP6" or "ARP"

        var src = ""
        var dst = ""
        var info = ""
        var length = 0

        if parts.count >= 5 {
            src = String(parts[2])
            // parts[3] is ">"
            dst = parts.count > 4 ? String(parts[4]).trimmingCharacters(in: CharacterSet(charactersIn: ":")) : ""
        }
        if parts.count > 5 {
            info = parts[5...].joined(separator: " ")
        }
        if let lenRange = info.range(of: #"length (\d+)"#, options: .regularExpression) {
            let lenStr = info[lenRange].replacingOccurrences(of: "length ", with: "")
            length = Int(lenStr) ?? 0
        }

        return PacketRecord(
            timestamp: timestamp,
            source: src,
            destination: dst,
            proto: proto,
            length: length,
            info: info
        )
    }
}
