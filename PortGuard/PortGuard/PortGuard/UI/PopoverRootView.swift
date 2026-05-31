import SwiftUI
import PortGuardCore

struct PopoverRootView: View {
    @Environment(DataStore.self) var dataStore
    @State private var selectedTab: Tab = .processes

    enum Tab: String, CaseIterable {
        case processes = "Processes"
        case ports = "Ports"
        case connections = "Connections"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search process, port...", text: Bindable(dataStore).searchQuery)
                    .textFieldStyle(.plain)
                if !dataStore.searchQuery.isEmpty {
                    Button { dataStore.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider().padding(.top, 8)

            Group {
                switch selectedTab {
                case .processes: ProcessesTabView()
                case .ports: PortsTabView()
                case .connections: ConnectionsTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Text("\(dataStore.connections.count) connections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("⚙") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 400, height: 520)
    }
}
