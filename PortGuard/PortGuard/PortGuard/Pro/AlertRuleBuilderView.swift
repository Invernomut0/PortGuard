import SwiftUI
import PortGuardCore

struct AlertRuleBuilderView: View {
    @State var alertEngine: AlertEngine
    @State private var showingAddRule = false
    @State private var newRuleName = ""
    @State private var newRuleTrigger: AlertRule.Trigger = .portOpened
    @State private var newRulePort = ""
    @State private var newRuleProcess = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Alert Rules").font(.headline)
                Spacer()
                Button { showingAddRule.toggle() } label: {
                    Image(systemName: "plus")
                }
            }
            .padding()

            List {
                ForEach(alertEngine.rules) { rule in
                    HStack {
                        Image(systemName: rule.isEnabled ? "bell.fill" : "bell.slash")
                            .foregroundStyle(rule.isEnabled ? .blue : .secondary)
                        VStack(alignment: .leading) {
                            Text(rule.name).fontWeight(.medium)
                            Text(ruleDescription(rule)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(rule.isEnabled ? "Disable" : "Enable") {
                            if let idx = alertEngine.rules.firstIndex(where: { $0.id == rule.id }) {
                                alertEngine.rules[idx].isEnabled.toggle()
                            }
                        }
                        .font(.caption)
                    }
                }
                .onDelete { alertEngine.rules.remove(atOffsets: $0) }
            }

            if showingAddRule {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Rule name", text: $newRuleName)
                    Picker("Trigger", selection: $newRuleTrigger) {
                        Text("Port opened").tag(AlertRule.Trigger.portOpened)
                        Text("Port closed").tag(AlertRule.Trigger.portClosed)
                        Text("New outbound connection").tag(AlertRule.Trigger.newOutboundConnection)
                        Text("Process connected").tag(AlertRule.Trigger.processConnected)
                    }
                    if newRuleTrigger == .portOpened || newRuleTrigger == .portClosed {
                        TextField("Port number (leave blank for any)", text: $newRulePort)
                    }
                    if newRuleTrigger == .newOutboundConnection || newRuleTrigger == .processConnected {
                        TextField("Process name (leave blank for any)", text: $newRuleProcess)
                    }
                    HStack {
                        Button("Add") {
                            alertEngine.rules.append(AlertRule(
                                name: newRuleName.isEmpty ? "Unnamed rule" : newRuleName,
                                trigger: newRuleTrigger,
                                portFilter: Int(newRulePort),
                                processFilter: newRuleProcess.isEmpty ? nil : newRuleProcess
                            ))
                            showingAddRule = false
                            newRuleName = ""; newRulePort = ""; newRuleProcess = ""
                        }
                        Button("Cancel") { showingAddRule = false }
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 400)
    }

    private func ruleDescription(_ rule: AlertRule) -> String {
        var parts: [String] = [rule.trigger.rawValue]
        if let port = rule.portFilter { parts.append("port \(port)") }
        if let proc = rule.processFilter { parts.append("by \(proc)") }
        return parts.joined(separator: " ")
    }
}
