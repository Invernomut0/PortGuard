import Foundation
import UserNotifications
import PortGuardCore

@MainActor
final class AlertEngine {
    var rules: [AlertRule] = [] {
        didSet { saveRules() }
    }

    private let rulesKey = "com.portguard.app.alertRules"

    init() {
        rules = loadRules()
        requestNotificationPermission()
    }

    func evaluate(diff: LsofDiff) {
        guard !rules.isEmpty else { return }
        for rule in rules where rule.isEnabled {
            checkRule(rule, diff: diff)
        }
    }

    private func checkRule(_ rule: AlertRule, diff: LsofDiff) {
        switch rule.trigger {
        case .portOpened:
            diff.added
                .filter { $0.state == .listen && (rule.portFilter == nil || $0.localPort == rule.portFilter) }
                .forEach { fire(rule: rule, connection: $0, verb: "opened") }

        case .portClosed:
            diff.removed
                .filter { $0.state == .listen && (rule.portFilter == nil || $0.localPort == rule.portFilter) }
                .forEach { fire(rule: rule, connection: $0, verb: "closed") }

        case .newOutboundConnection:
            diff.added
                .filter {
                    $0.state == .established &&
                    $0.remoteHost != nil &&
                    (rule.processFilter == nil || $0.processName == rule.processFilter)
                }
                .forEach { fire(rule: rule, connection: $0, verb: "connected outbound") }

        case .processConnected:
            diff.added
                .filter { conn in rule.processFilter.map { conn.processName.contains($0) } ?? true }
                .forEach { conn in fire(rule: rule, connection: conn, verb: "made a connection") }
        }
    }

    private func fire(rule: AlertRule, connection: ConnectionRecord, verb: String) {
        let content = UNMutableNotificationContent()
        content.title = "PortGuard: \(rule.name)"
        content.body = "\(connection.processName) \(verb) on port \(connection.localPort)"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }

    private func loadRules() -> [AlertRule] {
        guard let data = UserDefaults.standard.data(forKey: rulesKey),
              let decoded = try? JSONDecoder().decode([AlertRule].self, from: data) else { return [] }
        return decoded
    }
}
