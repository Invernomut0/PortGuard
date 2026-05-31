import SwiftUI
import PortGuardCore

struct SnifferView: View {
    let processName: String
    let ports: [Int]

    @State private var sniffer: PacketSniffer
    @State private var selectedPacket: PacketRecord?
    @State private var autoscroll = true
    @Environment(\.dismiss) private var dismiss

    init(processName: String, ports: [Int]) {
        self.processName = processName
        self.ports = ports
        _sniffer = State(initialValue: {
            let s = PacketSniffer()
            s.processName = processName
            s.ports = ports
            return s
        }())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Circle()
                    .fill(sniffer.isRunning ? Color.red : Color.gray)
                    .frame(width: 10, height: 10)
                Text(processName)
                    .fontWeight(.semibold)
                Text("porte: \(ports.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(sniffer.packets.count) pacchetti")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Toggle("Auto-scroll", isOn: $autoscroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button {
                    sniffer.clearPackets()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Svuota")
                Button {
                    if sniffer.isRunning { sniffer.stop() } else { sniffer.start() }
                } label: {
                    Image(systemName: sniffer.isRunning ? "stop.fill" : "play.fill")
                        .foregroundStyle(sniffer.isRunning ? .red : .green)
                }
                .buttonStyle(.plain)
                .help(sniffer.isRunning ? "Stop" : "Avvia")
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .help("Chiudi")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if let err = sniffer.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(err)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sniffer.packets.isEmpty && !sniffer.isRunning {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Premi ▶ per avviare la cattura")
                        .foregroundStyle(.secondary)
                    Text("macOS chiederà la password di amministratore")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Packet list
                ScrollViewReader { proxy in
                    List(sniffer.packets) { pkt in
                        PacketRow(packet: pkt, isSelected: selectedPacket?.id == pkt.id)
                            .id(pkt.id)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedPacket = pkt }
                            .listRowBackground(selectedPacket?.id == pkt.id
                                ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                    .listStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: sniffer.packets.count) {
                        if autoscroll, let last = sniffer.packets.last {
                            withAnimation(.none) { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // Detail panel
                if let pkt = selectedPacket {
                    Divider()
                    PacketDetailView(packet: pkt)
                        .frame(height: 100)
                }
            }
        }
        .frame(width: 700, height: 480)
        .onAppear { sniffer.start() }
        .onDisappear { sniffer.stop() }
    }
}

private struct PacketRow: View {
    let packet: PacketRecord
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(packet.timestamp)
                .frame(width: 130, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(packet.proto)
                .frame(width: 36, alignment: .center)
                .foregroundStyle(protoColor)
                .fontWeight(.medium)
            Text(packet.source)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(packet.destination)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)
            Spacer()
            Text("\(packet.length)B")
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var protoColor: Color {
        switch packet.proto {
        case "IP", "IP6": return .blue
        case "ARP": return .orange
        default: return .primary
        }
    }
}

private struct PacketDetailView: View {
    let packet: PacketRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Dettaglio pacchetto")
                    .font(.caption.bold())
                Spacer()
                Text("ts: \(packet.timestamp)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Divider()
            ScrollView(.vertical) {
                Text(packet.info.isEmpty ? "(nessun dettaglio)" : packet.info)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(.quaternary)
    }
}
