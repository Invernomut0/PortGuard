import SwiftUI
import PortGuardCore

struct PopoverRootView: View {
    @Environment(DataStore.self) var dataStore
    @Environment(\.openSettings) private var openSettings
    @State var licenseManager: LicenseManager
    @State var exportManager: ExportManager
    @State var alertEngine: AlertEngine
    @State private var selectedTab: Tab = .processes
    @State private var showingAlertRules = false

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
            .environment(\.isPro, licenseManager.isPro)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Text("\(dataStore.connections.count) connections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if licenseManager.isPro {
                    Button {
                        showingAlertRules = true
                    } label: {
                        Image(systemName: "bell")
                    }
                    .buttonStyle(.plain)
                    .help("Alert Rules")
                    .sheet(isPresented: $showingAlertRules) {
                        AlertRuleBuilderView(alertEngine: alertEngine)
                    }

                    Menu {
                        Button("Export as CSV") {
                            exportManager.export(connections: dataStore.connections, format: .csv)
                        }
                        Button("Export as JSON") {
                            exportManager.export(connections: dataStore.connections, format: .json)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .help("Export")
                }
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 400, height: 520)
    }
}
