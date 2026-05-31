import AppKit
import PortGuardCore
import UniformTypeIdentifiers

@MainActor
final class ExportManager {
    enum Format { case csv, json }

    func export(connections: [ConnectionRecord], format: Format) {
        let content: String
        let ext: String
        switch format {
        case .csv:
            content = toCSV(connections)
            ext = "csv"
        case .json:
            content = toJSON(connections)
            ext = "json"
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "portguard-snapshot-\(dateString()).\(ext)"
        panel.allowedContentTypes = format == .csv ? [.commaSeparatedText] : [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func toCSV(_ connections: [ConnectionRecord]) -> String {
        var lines = ["process,pid,local_port,remote_host,remote_port,state,protocol,timestamp"]
        for c in connections {
            lines.append([
                c.processName,
                "\(c.pid)",
                "\(c.localPort)",
                c.remoteHost ?? "",
                c.remotePort.map(String.init) ?? "",
                c.state.rawValue,
                c.protocol.rawValue,
                c.timestamp.ISO8601Format()
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private func toJSON(_ connections: [ConnectionRecord]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? String(data: encoder.encode(connections), encoding: .utf8)) ?? "[]"
    }

    private func dateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: Date())
    }
}
