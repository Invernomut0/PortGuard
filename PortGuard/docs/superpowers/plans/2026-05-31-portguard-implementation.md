# PortGuard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build PortGuard, a macOS menubar app that shows real-time process/port/connection data using `lsof` + NSWorkspace, with a Pro tier (alerts, history, export) unlocked via Gumroad license key.

**Architecture:** `PortGuardCore` Swift Package contains all pure logic (parsing, diffing, data store); the Xcode app target contains SwiftUI UI, Pro features, and licensing. `LsofPoller` polls on a configurable interval and produces a `LsofDiff`; `ProcessMonitor` delivers instant NSWorkspace events; `DataStore` (`@Observable`) merges both into a single source of truth for the UI.

**Tech Stack:** Swift 5.10+, SwiftUI, AppKit (NSStatusItem, NSPopover, NSWorkspace), Swift Package Manager, GRDB (SQLite, Pro), Sparkle 2 (updates), Gumroad license key API.

---

## File Map

| File | Responsibility |
|---|---|
| `PortGuardCore/Sources/PortGuardCore/Models.swift` | Value types: `ConnectionRecord`, `PortRecord`, `ProcessRecord`, `LsofDiff`, `AlertRule` |
| `PortGuardCore/Sources/PortGuardCore/LsofPoller.swift` | Spawn `lsof`, parse output, produce `LsofDiff` |
| `PortGuardCore/Sources/PortGuardCore/ProcessMonitor.swift` | NSWorkspace observer, emit `ProcessRecord` events |
| `PortGuardCore/Sources/PortGuardCore/DataStore.swift` | `@Observable`, merge poller + monitor, expose filtered/sorted lists |
| `PortGuardCore/Tests/PortGuardCoreTests/LsofParserTests.swift` | Unit tests for parsing and diffing with fixture output |
| `PortGuardCore/Tests/PortGuardCoreTests/DataStoreTests.swift` | Unit tests for DataStore merge logic |
| `PortGuard/App/PortGuardApp.swift` | SwiftUI `@main`, `LSUIElement`, `ApplicationDelegateAdaptor` |
| `PortGuard/App/AppDelegate.swift` | `NSApplicationDelegate`, wires up `MenuBarManager`, `DataStore` |
| `PortGuard/MenuBar/MenuBarManager.swift` | `NSStatusItem` lifecycle, shows/hides `NSPopover` |
| `PortGuard/MenuBar/StatusItemView.swift` | SwiftUI view rendered in status item button |
| `PortGuard/UI/PopoverRootView.swift` | Root popover: search bar + `TabView` + footer |
| `PortGuard/UI/ProcessesTabView.swift` | Processes tab list + expandable detail row |
| `PortGuard/UI/PortsTabView.swift` | Ports tab list + unsigned-process badge |
| `PortGuard/UI/ConnectionsTabView.swift` | Connections tab with lazy reverse DNS |
| `PortGuard/UI/QuickLookupView.swift` | Global floating overlay panel |
| `PortGuard/UI/SettingsView.swift` | Preferences window |
| `PortGuard/Pro/AlertEngine.swift` | Evaluate `AlertRule` array against `LsofDiff` |
| `PortGuard/Pro/AlertRuleBuilderView.swift` | Visual rule editor UI |
| `PortGuard/Pro/HistoryStore.swift` | GRDB setup, snapshot append, query by time range |
| `PortGuard/Pro/ExportManager.swift` | Serialize `DataStore` snapshot to CSV/JSON |
| `PortGuard/License/LicenseManager.swift` | Gumroad API call, local HMAC validation, `isPro` published var |
| `PortGuard/License/LicenseActivationView.swift` | Key entry form |

---

## Task 1: PortGuardCore Swift Package — Models

**Files:**
- Create: `PortGuardCore/Package.swift`
- Create: `PortGuardCore/Sources/PortGuardCore/Models.swift`
- Create: `PortGuardCore/Tests/PortGuardCoreTests/ModelsTests.swift`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PortGuardCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PortGuardCore", targets: ["PortGuardCore"]),
    ],
    targets: [
        .target(name: "PortGuardCore"),
        .testTarget(name: "PortGuardCoreTests", dependencies: ["PortGuardCore"]),
    ]
)
```

- [ ] **Step 2: Write failing test for models**

```swift
// PortGuardCore/Tests/PortGuardCoreTests/ModelsTests.swift
import XCTest
@testable import PortGuardCore

final class ModelsTests: XCTestCase {
    func test_connectionRecord_equality() {
        let a = ConnectionRecord(pid: 1234, processName: "node", localPort: 3000, remoteHost: nil, remotePort: nil, state: .listen, protocol: .tcp)
        let b = ConnectionRecord(pid: 1234, processName: "node", localPort: 3000, remoteHost: nil, remotePort: nil, state: .listen, protocol: .tcp)
        XCTAssertEqual(a, b)
    }

    func test_lsofDiff_isEmpty_whenNoChanges() {
        let diff = LsofDiff(added: [], removed: [], unchanged: [])
        XCTAssertTrue(diff.isEmpty)
    }
}
```

- [ ] **Step 3: Run test to confirm it fails**

```bash
cd PortGuardCore && swift test --filter ModelsTests 2>&1 | tail -20
```
Expected: error "no such module 'PortGuardCore'"

- [ ] **Step 4: Write Models.swift**

```swift
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
```

- [ ] **Step 5: Run test to confirm it passes**

```bash
cd PortGuardCore && swift test --filter ModelsTests 2>&1 | tail -10
```
Expected: `Test Suite 'ModelsTests' passed`

- [ ] **Step 6: Commit**

```bash
git add PortGuardCore/
git commit -m "feat(core): add PortGuardCore package with domain models"
```

---

## Task 2: LsofPoller — parsing and diff engine

**Files:**
- Create: `PortGuardCore/Sources/PortGuardCore/LsofPoller.swift`
- Create: `PortGuardCore/Tests/PortGuardCoreTests/LsofParserTests.swift`

- [ ] **Step 1: Add fixture file**

Create `PortGuardCore/Tests/PortGuardCoreTests/Fixtures/lsof_sample.txt` with real-world `lsof -i -n -P` output:

```
COMMAND     PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node      12345 lorenzov   22u  IPv4 0x1234abcd      0t0  TCP *:3000 (LISTEN)
node      12345 lorenzov   24u  IPv4 0x1234abce      0t0  TCP 192.168.1.5:52100->142.250.80.46:443 (ESTABLISHED)
chrome    67890 lorenzov   45u  IPv4 0x1234abcf      0t0  TCP 192.168.1.5:55000->172.217.14.196:443 (ESTABLISHED)
python3    9999 lorenzov   10u  IPv4 0x1234abd0      0t0  TCP *:8080 (LISTEN)
```

- [ ] **Step 2: Write failing parser tests**

```swift
// PortGuardCore/Tests/PortGuardCoreTests/LsofParserTests.swift
import XCTest
@testable import PortGuardCore

final class LsofParserTests: XCTestCase {
    let fixture = """
COMMAND     PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node      12345 lorenzov   22u  IPv4 0x1234abcd      0t0  TCP *:3000 (LISTEN)
node      12345 lorenzov   24u  IPv4 0x1234abce      0t0  TCP 192.168.1.5:52100->142.250.80.46:443 (ESTABLISHED)
chrome    67890 lorenzov   45u  IPv4 0x1234abcf      0t0  TCP 192.168.1.5:55000->172.217.14.196:443 (ESTABLISHED)
python3    9999 lorenzov   10u  IPv4 0x1234abd0      0t0  TCP *:8080 (LISTEN)
"""

    func test_parse_detectsListenConnections() {
        let records = LsofParser.parse(output: fixture)
        let listenRecords = records.filter { $0.state == .listen }
        XCTAssertEqual(listenRecords.count, 2)
    }

    func test_parse_detectsEstablishedConnections() {
        let records = LsofParser.parse(output: fixture)
        let established = records.filter { $0.state == .established }
        XCTAssertEqual(established.count, 2)
    }

    func test_parse_extractsCorrectPort() {
        let records = LsofParser.parse(output: fixture)
        let nodeRecord = records.first { $0.processName == "node" && $0.state == .listen }
        XCTAssertEqual(nodeRecord?.localPort, 3000)
        XCTAssertEqual(nodeRecord?.pid, 12345)
    }

    func test_parse_extractsRemoteHost() {
        let records = LsofParser.parse(output: fixture)
        let chromeRecord = records.first { $0.processName == "chrome" }
        XCTAssertEqual(chromeRecord?.remoteHost, "172.217.14.196")
        XCTAssertEqual(chromeRecord?.remotePort, 443)
    }

    func test_diff_detectsAddedRecords() {
        let prev: [ConnectionRecord] = []
        let next = LsofParser.parse(output: fixture)
        let diff = LsofDiffEngine.diff(previous: prev, current: next)
        XCTAssertEqual(diff.added.count, next.count)
        XCTAssertTrue(diff.removed.isEmpty)
    }

    func test_diff_detectsRemovedRecords() {
        let prev = LsofParser.parse(output: fixture)
        let diff = LsofDiffEngine.diff(previous: prev, current: [])
        XCTAssertEqual(diff.removed.count, prev.count)
        XCTAssertTrue(diff.added.isEmpty)
    }
}
```

- [ ] **Step 3: Run to confirm failure**

```bash
cd PortGuardCore && swift test --filter LsofParserTests 2>&1 | tail -10
```
Expected: error "cannot find type 'LsofParser'"

- [ ] **Step 4: Write LsofPoller.swift**

```swift
// PortGuardCore/Sources/PortGuardCore/LsofPoller.swift
import Foundation

public enum LsofParser {
    public static func parse(output: String) -> [ConnectionRecord] {
        var results: [ConnectionRecord] = []
        let lines = output.components(separatedBy: "\n").dropFirst() // skip header

        for line in lines {
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            // Minimum: COMMAND PID USER FD TYPE DEVICE SIZE NODE NAME
            guard parts.count >= 9 else { continue }

            let command = String(parts[0])
            guard let pid = Int(parts[1]) else { continue }
            let nameField = String(parts[parts.count - 1]) // e.g. (LISTEN) or (ESTABLISHED)
            let addressField = String(parts[parts.count - 2]) // e.g. *:3000 or 192.168.1.5:52100->...
            let typeField = String(parts[4]) // IPv4 / IPv6

            // Skip non-internet entries
            guard typeField == "IPv4" || typeField == "IPv6" else { continue }

            let proto: ConnectionProtocol = typeField == "IPv6" ? .tcp6 : .tcp
            let state = parseState(nameField)
            let (localPort, remoteHost, remotePort) = parseAddress(addressField)

            guard localPort > 0 else { continue }

            let record = ConnectionRecord(
                pid: pid,
                processName: command,
                localPort: localPort,
                remoteHost: remoteHost,
                remotePort: remotePort,
                state: state,
                protocol: proto
            )
            results.append(record)
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
        let portStr = String(part[part.index(after: colonIdx)...])
        return Int(portStr) ?? 0
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
        let output = runLsof()
        let current = LsofParser.parse(output: output)
        let diff = LsofDiffEngine.diff(previous: previous, current: current)
        previous = current
        if !diff.isEmpty {
            onDiff?(diff)
        }
    }

    private func runLsof() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", "-n", "-P"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
cd PortGuardCore && swift test --filter LsofParserTests 2>&1 | tail -15
```
Expected: `Test Suite 'LsofParserTests' passed`

- [ ] **Step 6: Commit**

```bash
git add PortGuardCore/
git commit -m "feat(core): add LsofParser, LsofDiffEngine, and LsofPoller"
```

---

## Task 3: ProcessMonitor

**Files:**
- Create: `PortGuardCore/Sources/PortGuardCore/ProcessMonitor.swift`

- [ ] **Step 1: Write ProcessMonitor.swift**

```swift
// PortGuardCore/Sources/PortGuardCore/ProcessMonitor.swift
import AppKit

@MainActor
public final class ProcessMonitor {
    public var onLaunch: ((ProcessRecord) -> Void)?
    public var onTerminate: ((ProcessRecord) -> Void)?

    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func start() {
        let ws = NSWorkspace.shared.notificationCenter

        let launchObs = ws.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let record = ProcessRecord(
                pid: Int(app.processIdentifier),
                name: app.localizedName ?? app.executableURL?.lastPathComponent ?? "unknown",
                bundleIdentifier: app.bundleIdentifier
            )
            self?.onLaunch?(record)
        }

        let terminateObs = ws.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let record = ProcessRecord(
                pid: Int(app.processIdentifier),
                name: app.localizedName ?? app.executableURL?.lastPathComponent ?? "unknown",
                bundleIdentifier: app.bundleIdentifier
            )
            self?.onTerminate?(record)
        }

        observers = [launchObs, terminateObs]
    }

    public func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
cd PortGuardCore && swift build 2>&1 | tail -10
```
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add PortGuardCore/Sources/PortGuardCore/ProcessMonitor.swift
git commit -m "feat(core): add ProcessMonitor using NSWorkspace notifications"
```

---

## Task 4: DataStore

**Files:**
- Create: `PortGuardCore/Sources/PortGuardCore/DataStore.swift`
- Create: `PortGuardCore/Tests/PortGuardCoreTests/DataStoreTests.swift`

- [ ] **Step 1: Write failing DataStore tests**

```swift
// PortGuardCore/Tests/PortGuardCoreTests/DataStoreTests.swift
import XCTest
@testable import PortGuardCore

@MainActor
final class DataStoreTests: XCTestCase {
    func test_applyDiff_addsConnections() async {
        let store = DataStore()
        let record = ConnectionRecord(pid: 1, processName: "test", localPort: 8080,
                                      remoteHost: nil, remotePort: nil,
                                      state: .listen, protocol: .tcp)
        let diff = LsofDiff(added: [record], removed: [], unchanged: [])
        store.apply(diff: diff)
        XCTAssertEqual(store.connections.count, 1)
        XCTAssertEqual(store.listenPorts.count, 1)
    }

    func test_applyDiff_removesConnections() async {
        let store = DataStore()
        let record = ConnectionRecord(pid: 1, processName: "test", localPort: 8080,
                                      remoteHost: nil, remotePort: nil,
                                      state: .listen, protocol: .tcp)
        store.apply(diff: LsofDiff(added: [record], removed: [], unchanged: []))
        store.apply(diff: LsofDiff(added: [], removed: [record], unchanged: []))
        XCTAssertTrue(store.connections.isEmpty)
    }

    func test_filtered_bySearchQuery() async {
        let store = DataStore()
        let nodeRecord = ConnectionRecord(pid: 1, processName: "node", localPort: 3000,
                                          remoteHost: nil, remotePort: nil,
                                          state: .listen, protocol: .tcp)
        let chromeRecord = ConnectionRecord(pid: 2, processName: "chrome", localPort: 443,
                                            remoteHost: "google.com", remotePort: 443,
                                            state: .established, protocol: .tcp)
        store.apply(diff: LsofDiff(added: [nodeRecord, chromeRecord], removed: [], unchanged: []))
        store.searchQuery = "node"
        XCTAssertEqual(store.filteredConnections.count, 1)
        XCTAssertEqual(store.filteredConnections.first?.processName, "node")
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
cd PortGuardCore && swift test --filter DataStoreTests 2>&1 | tail -10
```
Expected: error "cannot find type 'DataStore'"

- [ ] **Step 3: Write DataStore.swift**

```swift
// PortGuardCore/Sources/PortGuardCore/DataStore.swift
import Foundation
import Observation

@Observable
@MainActor
public final class DataStore {
    public private(set) var connections: [ConnectionRecord] = []
    public private(set) var listenPorts: [PortRecord] = []
    public var searchQuery: String = ""

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
        guard !searchQuery.isEmpty else { return listenPorts }
        let q = searchQuery.lowercased()
        return listenPorts.filter {
            $0.processName.lowercased().contains(q) ||
            String($0.port).contains(q)
        }
    }

    public var outboundConnections: [ConnectionRecord] {
        filteredConnections.filter { $0.state == .established && $0.remoteHost != nil }
    }

    public var processSummaries: [ProcessSummary] {
        let groups = Dictionary(grouping: filteredConnections, by: { $0.pid })
        return groups.map { pid, conns in
            ProcessSummary(pid: pid, name: conns.first?.processName ?? "", connections: conns)
        }.sorted { $0.name < $1.name }
    }

    public func apply(diff: LsofDiff) {
        let removedSet = Set(diff.removed)
        connections.removeAll { removedSet.contains($0) }
        connections.append(contentsOf: diff.added)
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
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd PortGuardCore && swift test 2>&1 | tail -15
```
Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add PortGuardCore/Sources/PortGuardCore/DataStore.swift PortGuardCore/Tests/
git commit -m "feat(core): add DataStore with diff application and filtering"
```

---

## Task 5: Xcode Project Setup

**Files:**
- Create: `PortGuard/PortGuard.xcodeproj` (via Xcode)
- Modify: `PortGuard/PortGuard/Info.plist`
- Create: `PortGuard/PortGuard/App/PortGuardApp.swift`
- Create: `PortGuard/PortGuard/App/AppDelegate.swift`

- [ ] **Step 1: Create Xcode project**

Open Xcode → File → New → Project → macOS → App.
- Product Name: `PortGuard`
- Interface: SwiftUI
- Language: Swift
- Uncheck "Include Tests" (we use a separate test target)
- Save to `/Users/lorenzov/mobile_app_ideas/PortGuard/`

- [ ] **Step 2: Add PortGuardCore as local Swift Package**

In Xcode: File → Add Package Dependencies → Add Local → select `PortGuardCore/` folder. Add `PortGuardCore` library to the `PortGuard` target.

- [ ] **Step 3: Set LSUIElement in Info.plist**

Add key `Application is agent (UIElement)` = `YES` to `Info.plist`. This hides the app from the Dock.

- [ ] **Step 4: Write PortGuardApp.swift**

```swift
// PortGuard/PortGuard/App/PortGuardApp.swift
import SwiftUI
import PortGuardCore

@main
struct PortGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — menubar only
        Settings {
            SettingsView()
                .environmentObject(appDelegate.dataStore)
        }
    }
}
```

- [ ] **Step 5: Write AppDelegate.swift**

```swift
// PortGuard/PortGuard/App/AppDelegate.swift
import AppKit
import PortGuardCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dataStore = DataStore()
    private let poller = LsofPoller()
    private let processMonitor = ProcessMonitor()
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager(dataStore: dataStore)

        poller.onDiff = { [weak self] diff in
            Task { @MainActor in self?.dataStore.apply(diff: diff) }
        }
        processMonitor.onLaunch = { _ in } // future use
        processMonitor.onTerminate = { _ in } // future use

        poller.start()
        processMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        poller.stop()
        processMonitor.stop()
    }
}
```

- [ ] **Step 6: Build to confirm it compiles**

In Xcode: Product → Build (⌘B). Expected: Build Succeeded.

- [ ] **Step 7: Commit**

```bash
cd /Users/lorenzov/mobile_app_ideas/PortGuard
git add PortGuard/
git commit -m "feat(app): Xcode project setup with PortGuardCore integration"
```

---

## Task 6: MenuBarManager + Status Item

**Files:**
- Create: `PortGuard/PortGuard/MenuBar/MenuBarManager.swift`
- Create: `PortGuard/PortGuard/MenuBar/StatusItemView.swift`

- [ ] **Step 1: Write MenuBarManager.swift**

```swift
// PortGuard/PortGuard/MenuBar/MenuBarManager.swift
import AppKit
import SwiftUI
import PortGuardCore

@MainActor
final class MenuBarManager {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView().environment(dataStore)
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PortGuard")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func updateBadge(connectionCount: Int, hasActiveAlert: Bool) {
        guard let button = statusItem.button else { return }
        if hasActiveAlert {
            button.image = NSImage(systemSymbolName: "network.badge.shield.half.filled", accessibilityDescription: "PortGuard — Alert")
        } else {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PortGuard")
        }
        button.title = connectionCount > 0 ? " \(connectionCount)" : ""
    }
}
```

- [ ] **Step 2: Write StatusItemView.swift**

```swift
// PortGuard/PortGuard/MenuBar/StatusItemView.swift
import SwiftUI
import PortGuardCore

struct StatusItemView: View {
    @Environment(DataStore.self) var dataStore

    var body: some View {
        Label("\(dataStore.connections.count)", systemImage: "network")
            .font(.system(size: 12, weight: .medium))
    }
}
```

- [ ] **Step 3: Build to confirm**

In Xcode: ⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Run the app manually**

In Xcode: ⌘R. The app should appear in the menubar with a network icon. Click it — popover will be empty for now (PopoverRootView not yet written, will show a placeholder).

- [ ] **Step 5: Commit**

```bash
git add PortGuard/PortGuard/MenuBar/
git commit -m "feat(ui): add MenuBarManager and NSStatusItem with popover"
```

---

## Task 7: PopoverRootView + Tab skeleton

**Files:**
- Create: `PortGuard/PortGuard/UI/PopoverRootView.swift`
- Create: `PortGuard/PortGuard/UI/ProcessesTabView.swift`
- Create: `PortGuard/PortGuard/UI/PortsTabView.swift`
- Create: `PortGuard/PortGuard/UI/ConnectionsTabView.swift`

- [ ] **Step 1: Write PopoverRootView.swift**

```swift
// PortGuard/PortGuard/UI/PopoverRootView.swift
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
            // Search bar
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

            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider().padding(.top, 8)

            // Content
            Group {
                switch selectedTab {
                case .processes: ProcessesTabView()
                case .ports: PortsTabView()
                case .connections: ConnectionsTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                Text("\(dataStore.connections.count) connections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("⚙") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 400, height: 520)
    }
}
```

- [ ] **Step 2: Write ProcessesTabView.swift**

```swift
// PortGuard/PortGuard/UI/ProcessesTabView.swift
import SwiftUI
import PortGuardCore

struct ProcessesTabView: View {
    @Environment(DataStore.self) var dataStore
    @State private var expandedPID: Int? = nil

    var body: some View {
        List {
            ForEach(dataStore.processSummaries) { summary in
                ProcessRowView(summary: summary, isExpanded: expandedPID == summary.pid) {
                    expandedPID = expandedPID == summary.pid ? nil : summary.pid
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ProcessRowView: View {
    let summary: ProcessSummary
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "app.fill")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Text(summary.name)
                        .fontWeight(.medium)
                    Spacer()
                    Text("PID \(summary.pid)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.connectionCount)")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(summary.connections) { conn in
                    ConnectionDetailRow(connection: conn)
                        .padding(.leading, 28)
                }
            }
        }
    }
}

struct ConnectionDetailRow: View {
    let connection: ConnectionRecord

    var body: some View {
        HStack {
            Text(":\(connection.localPort)")
                .font(.caption.monospaced())
            if let remote = connection.remoteHost {
                Text("→ \(remote):\(connection.remotePort ?? 0)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(connection.state.rawValue)
                .font(.caption)
                .foregroundStyle(connection.state == .listen ? .green : .blue)
        }
    }
}
```

- [ ] **Step 3: Write PortsTabView.swift**

```swift
// PortGuard/PortGuard/UI/PortsTabView.swift
import SwiftUI
import PortGuardCore

struct PortsTabView: View {
    @Environment(DataStore.self) var dataStore

    var body: some View {
        List(dataStore.filteredListenPorts) { port in
            HStack {
                Text(":\(port.port)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(port.protocol.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Text(port.processName)
                    .foregroundStyle(.secondary)
                Text("PID \(port.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !port.isSigned {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .help("Process is not code-signed")
                }
            }
        }
        .listStyle(.plain)
    }
}
```

- [ ] **Step 4: Write ConnectionsTabView.swift**

```swift
// PortGuard/PortGuard/UI/ConnectionsTabView.swift
import SwiftUI
import PortGuardCore

struct ConnectionsTabView: View {
    @Environment(DataStore.self) var dataStore
    @State private var resolvedHosts: [String: String] = [:]

    var body: some View {
        List(dataStore.outboundConnections) { conn in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conn.processName)
                        .fontWeight(.medium)
                    Text("Local :\(conn.localPort)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(resolvedHosts[conn.remoteHost ?? ""] ?? conn.remoteHost ?? "")
                        .font(.caption.monospaced())
                    if let remotePort = conn.remotePort {
                        Text(":\(remotePort)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task(id: conn.remoteHost) {
                guard let host = conn.remoteHost, resolvedHosts[host] == nil else { return }
                resolvedHosts[host] = await reverseDNS(host)
            }
        }
        .listStyle(.plain)
    }

    private func reverseDNS(_ ip: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var hints = addrinfo()
                hints.ai_flags = AI_NUMERICHOST
                var result = ip
                // Use CFHost for reverse DNS
                let host = CFHostCreateWithName(nil, ip as CFString).takeRetainedValue()
                CFHostStartInfoResolution(host, .names, nil)
                var resolved = DarwinBoolean(false)
                if let names = CFHostGetNames(host, &resolved)?.takeUnretainedValue() as? [String], !names.isEmpty {
                    result = names[0]
                }
                continuation.resume(returning: result)
            }
        }
    }
}
```

- [ ] **Step 5: Build and run to confirm tabs work**

In Xcode: ⌘R. Click menubar icon → popover opens with 3 tabs and search bar. Processes tab should show active processes. Expected: no crash, data visible after first poll interval.

- [ ] **Step 6: Commit**

```bash
git add PortGuard/PortGuard/UI/
git commit -m "feat(ui): add PopoverRootView with Processes, Ports, and Connections tabs"
```

---

## Task 8: Quick Lookup overlay

**Files:**
- Create: `PortGuard/PortGuard/UI/QuickLookupView.swift`
- Modify: `PortGuard/PortGuard/App/AppDelegate.swift`

- [ ] **Step 1: Write QuickLookupView.swift**

```swift
// PortGuard/PortGuard/UI/QuickLookupView.swift
import SwiftUI
import PortGuardCore

struct QuickLookupView: View {
    @Environment(DataStore.self) var dataStore
    @Binding var query: String
    var onDismiss: () -> Void

    var results: [ConnectionRecord] {
        guard !query.isEmpty else { return [] }
        return dataStore.connections.filter {
            $0.processName.lowercased().contains(query.lowercased()) ||
            String($0.localPort).contains(query) ||
            ($0.remoteHost?.contains(query) ?? false)
        }
        .prefix(10)
        .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search port or process...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
            }
            .padding(16)

            if !results.isEmpty {
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { conn in
                            HStack {
                                Text(conn.processName)
                                    .fontWeight(.medium)
                                Text(":\(conn.localPort)")
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(conn.state.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .frame(width: 500)
        .onExitCommand { onDismiss() }
    }
}
```

- [ ] **Step 2: Add global shortcut and overlay window to AppDelegate.swift**

Replace `AppDelegate.swift` with:

```swift
// PortGuard/PortGuard/App/AppDelegate.swift
import AppKit
import SwiftUI
import PortGuardCore
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dataStore = DataStore()
    private let poller = LsofPoller()
    private let processMonitor = ProcessMonitor()
    private var menuBarManager: MenuBarManager?
    private var quickLookupWindow: NSPanel?
    private var hotKeyRef: EventHotKeyRef?
    @State private var quickLookupQuery = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager(dataStore: dataStore)

        poller.onDiff = { [weak self] diff in
            Task { @MainActor in self?.dataStore.apply(diff: diff) }
        }

        poller.start()
        processMonitor.start()
        registerGlobalShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        poller.stop()
        processMonitor.stop()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }

    private func registerGlobalShortcut() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, refCon in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refCon!).takeUnretainedValue()
            Task { @MainActor in delegate.showQuickLookup() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        var hotKeyID = EventHotKeyID(signature: OSType(0x5047_5244), id: 1) // "PGRD"
        // ⌥⌘P = optionKey + cmdKey + kVK_ANSI_P (35)
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(optionKey | cmdKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    @MainActor
    func showQuickLookup() {
        if let win = quickLookupWindow, win.isVisible {
            win.orderOut(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 60),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false

        let contentView = NSHostingView(rootView:
            QuickLookupView(query: .constant(""), onDismiss: { [weak panel] in panel?.orderOut(nil) })
                .environment(dataStore)
        )
        panel.contentView = contentView
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        quickLookupWindow = panel
    }
}
```

- [ ] **Step 3: Build and test**

In Xcode: ⌘R. Press ⌥⌘P. Expected: floating overlay appears centered on screen. Press Escape to dismiss.

- [ ] **Step 4: Commit**

```bash
git add PortGuard/PortGuard/UI/QuickLookupView.swift PortGuard/PortGuard/App/AppDelegate.swift
git commit -m "feat(ui): add Quick Lookup global overlay (⌥⌘P)"
```

---

## Task 9: Settings

**Files:**
- Create: `PortGuard/PortGuard/UI/SettingsView.swift`
- Modify: `PortGuard/PortGuard/App/AppDelegate.swift` (connect interval setting)

- [ ] **Step 1: Write SettingsView.swift**

```swift
// PortGuard/PortGuard/UI/SettingsView.swift
import SwiftUI
import PortGuardCore
import ServiceManagement

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        Form {
            Section("General") {
                Picker("Refresh interval", selection: $refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        try? SMAppService.mainApp.register()
                        if !enabled { try? SMAppService.mainApp.unregister() }
                    }
            }

            Section("License") {
                LicenseActivationView()
                    .environmentObject(licenseManager)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                Link("GitHub", destination: URL(string: "https://github.com/yourname/portguard")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 380)
        .navigationTitle("PortGuard Settings")
    }
}
```

- [ ] **Step 2: Build and verify**

In Xcode: ⌘R. Click ⚙ in popover footer → Settings window opens. Expected: form with refresh interval picker and login item toggle.

- [ ] **Step 3: Commit**

```bash
git add PortGuard/PortGuard/UI/SettingsView.swift
git commit -m "feat(ui): add SettingsView with refresh interval and login item"
```

---

## Task 10: LicenseManager (Pro unlock)

**Files:**
- Create: `PortGuard/PortGuard/License/LicenseManager.swift`
- Create: `PortGuard/PortGuard/License/LicenseActivationView.swift`

- [ ] **Step 1: Write LicenseManager.swift**

```swift
// PortGuard/PortGuard/License/LicenseManager.swift
import Foundation
import IOKit
import CryptoKit

@Observable
final class LicenseManager {
    private(set) var isPro: Bool = false
    private(set) var activationError: String? = nil
    var isValidating: Bool = false

    private let gumroadProductPermalink = "portguard"
    private let keychainKey = "com.yourname.portguard.licenseKey"

    init() {
        if let saved = loadKeyFromKeychain() {
            Task { await validate(key: saved, persist: false) }
        }
    }

    func activate(key: String) async {
        await validate(key: key, persist: true)
    }

    func deactivate() {
        deleteKeyFromKeychain()
        isPro = false
    }

    private func validate(key: String, persist: Bool) async {
        await MainActor.run { isValidating = true; activationError = nil }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://api.gumroad.com/v2/licenses/verify"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "product_permalink=\(gumroadProductPermalink)&license_key=\(trimmed)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                if persist { saveKeyToKeychain(trimmed) }
                await MainActor.run { isPro = true; isValidating = false }
            } else {
                await MainActor.run { activationError = "Invalid license key. Please check and try again."; isValidating = false }
            }
        } catch {
            await MainActor.run { activationError = "Network error. Please check your connection."; isValidating = false }
        }
    }

    private func deviceID() -> String {
        var serial = IOServiceMatching("IOPlatformExpertDevice")
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, serial)
        defer { IOObjectRelease(entry) }
        return (IORegistryEntryCreateCFProperty(entry, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String) ?? "unknown"
    }

    private func saveKeyToKeychain(_ key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrAccount as String: keychainKey,
                                     kSecValueData as String: data]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyFromKeychain() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrAccount as String: keychainKey,
                                     kSecReturnData as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeyFromKeychain() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrAccount as String: keychainKey]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Write LicenseActivationView.swift**

```swift
// PortGuard/PortGuard/License/LicenseActivationView.swift
import SwiftUI

struct LicenseActivationView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var keyInput = ""

    var body: some View {
        if licenseManager.isPro {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Pro — activated")
                Spacer()
                Button("Deactivate") { licenseManager.deactivate() }
                    .foregroundStyle(.red)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("License key", text: $keyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Activate") {
                        Task { await licenseManager.activate(key: keyInput) }
                    }
                    .disabled(keyInput.isEmpty || licenseManager.isValidating)
                }
                if let error = licenseManager.activationError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Link("Buy Pro — €15", destination: URL(string: "https://gumroad.com/l/portguard")!)
                    .font(.caption)
            }
        }
    }
}
```

- [ ] **Step 3: Wire LicenseManager into AppDelegate and SettingsView**

Add to `AppDelegate`:
```swift
let licenseManager = LicenseManager()
```

Pass it as `environmentObject` wherever `SettingsView` is presented.

- [ ] **Step 4: Build and verify**

Run app, open Settings, enter an invalid key → error shown. Expected: "Invalid license key" message. (Valid key test requires a real Gumroad product.)

- [ ] **Step 5: Commit**

```bash
git add PortGuard/PortGuard/License/
git commit -m "feat(license): add Gumroad license validation and Pro unlock"
```

---

## Task 11: AlertEngine (Pro)

**Files:**
- Create: `PortGuard/PortGuard/Pro/AlertEngine.swift`
- Create: `PortGuard/PortGuard/Pro/AlertRuleBuilderView.swift`

- [ ] **Step 1: Write AlertEngine.swift**

```swift
// PortGuard/PortGuard/Pro/AlertEngine.swift
import Foundation
import UserNotifications
import PortGuardCore

@MainActor
final class AlertEngine {
    var rules: [AlertRule] = [] {
        didSet { saveRules() }
    }

    private let rulesKey = "com.yourname.portguard.alertRules"

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
            let matches = diff.added.filter { conn in
                conn.state == .listen &&
                (rule.portFilter == nil || conn.localPort == rule.portFilter)
            }
            matches.forEach { fire(rule: rule, connection: $0, verb: "opened") }

        case .portClosed:
            let matches = diff.removed.filter { conn in
                conn.state == .listen &&
                (rule.portFilter == nil || conn.localPort == rule.portFilter)
            }
            matches.forEach { fire(rule: rule, connection: $0, verb: "closed") }

        case .newOutboundConnection:
            let matches = diff.added.filter { conn in
                conn.state == .established &&
                conn.remoteHost != nil &&
                (rule.processFilter == nil || conn.processName == rule.processFilter)
            }
            matches.forEach { fire(rule: rule, connection: $0, verb: "connected outbound") }

        case .processConnected:
            let matches = diff.added.filter { conn in
                rule.processFilter.map { conn.processName.contains($0) } ?? true
            }
            matches.forEach { fire(rule: rule, connection: $0, verb: "made a connection") }
        }
    }

    private func fire(rule: AlertRule, connection: ConnectionRecord, verb: String) {
        let content = UNMutableNotificationContent()
        content.title = "PortGuard: \(rule.name)"
        content.body = "\(connection.processName) \(verb) on port \(connection.localPort)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
              let rules = try? JSONDecoder().decode([AlertRule].self, from: data) else { return [] }
        return rules
    }
}
```

- [ ] **Step 2: Write AlertRuleBuilderView.swift**

```swift
// PortGuard/PortGuard/Pro/AlertRuleBuilderView.swift
import SwiftUI
import PortGuardCore

struct AlertRuleBuilderView: View {
    @EnvironmentObject var alertEngine: AlertEngine
    @State private var showingAddRule = false
    @State private var newRuleName = ""
    @State private var newRuleTrigger: AlertRule.Trigger = .portOpened
    @State private var newRulePort: String = ""
    @State private var newRuleProcess: String = ""

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
                        Button {
                            if let idx = alertEngine.rules.firstIndex(where: { $0.id == rule.id }) {
                                alertEngine.rules[idx].isEnabled.toggle()
                            }
                        } label: {
                            Text(rule.isEnabled ? "Disable" : "Enable")
                                .font(.caption)
                        }
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
                            let rule = AlertRule(
                                name: newRuleName.isEmpty ? "Unnamed rule" : newRuleName,
                                trigger: newRuleTrigger,
                                portFilter: Int(newRulePort),
                                processFilter: newRuleProcess.isEmpty ? nil : newRuleProcess
                            )
                            alertEngine.rules.append(rule)
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
        var parts: [String] = []
        switch rule.trigger {
        case .portOpened: parts.append("Port opened")
        case .portClosed: parts.append("Port closed")
        case .newOutboundConnection: parts.append("New outbound connection")
        case .processConnected: parts.append("Process connected")
        }
        if let port = rule.portFilter { parts.append("port \(port)") }
        if let proc = rule.processFilter { parts.append("by \(proc)") }
        return parts.joined(separator: " ")
    }
}
```

- [ ] **Step 3: Wire AlertEngine into AppDelegate**

In `AppDelegate.swift`, add:
```swift
let alertEngine = AlertEngine()
```

In the `poller.onDiff` closure, after `dataStore.apply(diff:)`, add:
```swift
if licenseManager.isPro { alertEngine.evaluate(diff: diff) }
```

- [ ] **Step 4: Test alert flow**

1. Run app, open Settings, activate a test license key (or temporarily set `isPro = true` in `LicenseManager.init()`)
2. Open Alert Rules, add rule: trigger = "Port opened", port = 9999
3. In Terminal: `python3 -m http.server 9999`
4. Within the refresh interval, a macOS notification should fire

- [ ] **Step 5: Commit**

```bash
git add PortGuard/PortGuard/Pro/AlertEngine.swift PortGuard/PortGuard/Pro/AlertRuleBuilderView.swift
git commit -m "feat(pro): add AlertEngine with rule evaluation and notification dispatch"
```

---

## Task 12: HistoryStore (Pro)

**Files:**
- Create: `PortGuard/PortGuard/Pro/HistoryStore.swift`

- [ ] **Step 1: Add GRDB dependency**

In `PortGuard.xcodeproj`: File → Add Package Dependencies.
URL: `https://github.com/groue/GRDB.swift`
Version: Up to Next Major from `6.0.0`.
Add `GRDB` library to `PortGuard` target.

- [ ] **Step 2: Write HistoryStore.swift**

```swift
// PortGuard/PortGuard/Pro/HistoryStore.swift
import Foundation
import GRDB
import PortGuardCore

struct ConnectionSnapshot: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let timestamp: Date
    let connectionsJSON: Data

    static let databaseTableName = "connection_snapshots"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

@MainActor
final class HistoryStore {
    private var db: DatabaseQueue?
    private var snapshotTimer: Timer?
    var snapshotInterval: TimeInterval = 300 // 5 minutes

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PortGuard/history.db")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        db = try? DatabaseQueue(path: url.path)
        try? db?.write { db in
            try db.create(table: "connection_snapshots", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("connectionsJSON", .blob).notNull()
            }
        }
    }

    func startSnapshots(dataStore: DataStore) {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self, weak dataStore] _ in
            guard let self, let dataStore else { return }
            Task { @MainActor in self.snapshot(connections: dataStore.connections) }
        }
    }

    func stopSnapshots() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    func snapshot(connections: [ConnectionRecord]) {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        var record = ConnectionSnapshot(timestamp: Date(), connectionsJSON: data)
        try? db?.write { db in try record.insert(db) }
    }

    func snapshots(from: Date, to: Date) -> [ConnectionSnapshot] {
        (try? db?.read { db in
            try ConnectionSnapshot
                .filter(Column("timestamp") >= from && Column("timestamp") <= to)
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }) ?? []
    }

    func allSnapshots() -> [ConnectionSnapshot] {
        (try? db?.read { db in
            try ConnectionSnapshot.order(Column("timestamp").desc).fetchAll(db)
        }) ?? []
    }
}
```

- [ ] **Step 3: Build to confirm**

In Xcode: ⌘B. Expected: Build Succeeded (GRDB linked).

- [ ] **Step 4: Commit**

```bash
git add PortGuard/PortGuard/Pro/HistoryStore.swift
git commit -m "feat(pro): add HistoryStore with GRDB SQLite snapshots"
```

---

## Task 13: ExportManager (Pro)

**Files:**
- Create: `PortGuard/PortGuard/Pro/ExportManager.swift`
- Modify: `PortGuard/PortGuard/UI/PopoverRootView.swift` (add Export button to footer)

- [ ] **Step 1: Write ExportManager.swift**

```swift
// PortGuard/PortGuard/Pro/ExportManager.swift
import Foundation
import PortGuardCore
import AppKit

enum ExportFormat { case csv, json }

@MainActor
final class ExportManager {
    func export(connections: [ConnectionRecord], format: ExportFormat) {
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
            lines.append("\(c.processName),\(c.pid),\(c.localPort),\(c.remoteHost ?? ""),\(c.remotePort.map(String.init) ?? ""),\(c.state.rawValue),\(c.protocol.rawValue),\(c.timestamp.ISO8601Format())")
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
```

- [ ] **Step 2: Add Export button to PopoverRootView footer**

In `PopoverRootView.swift`, replace the footer `HStack` with:

```swift
HStack {
    Text("\(dataStore.connections.count) connections")
        .font(.caption)
        .foregroundStyle(.secondary)
    Spacer()
    if licenseManager.isPro {
        Menu {
            Button("Export as CSV") { exportManager.export(connections: dataStore.connections, format: .csv) }
            Button("Export as JSON") { exportManager.export(connections: dataStore.connections, format: .json) }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
    }
    Button("⚙") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
        .buttonStyle(.plain)
}
.padding(.horizontal, 12)
.padding(.vertical, 8)
```

Add `@EnvironmentObject var licenseManager: LicenseManager` and `@EnvironmentObject var exportManager: ExportManager` to `PopoverRootView`.

- [ ] **Step 3: Build and verify**

With Pro active: Export menu appears in footer. Choose CSV → Save dialog opens. Expected: file saved with correct columns.

- [ ] **Step 4: Commit**

```bash
git add PortGuard/PortGuard/Pro/ExportManager.swift PortGuard/PortGuard/UI/PopoverRootView.swift
git commit -m "feat(pro): add CSV and JSON export with NSSavePanel"
```

---

## Task 14: Distribution setup

**Files:**
- Create: `PortGuard/scripts/notarize.sh`
- Create: `PortGuard/docs/index.html`

- [ ] **Step 1: Add Sparkle 2**

In Xcode: File → Add Package Dependencies.
URL: `https://github.com/sparkle-project/Sparkle`
Version: Up to Next Major from `2.0.0`.
Add `Sparkle` library to `PortGuard` target.

In `AppDelegate.applicationDidFinishLaunching`, add:
```swift
import Sparkle
// ...
let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
```

Add `SUFeedURL` key to `Info.plist` pointing to your appcast URL (e.g. `https://yourname.github.io/portguard/appcast.xml`).

- [ ] **Step 2: Write notarize.sh**

```bash
#!/bin/bash
# Usage: ./scripts/notarize.sh <path-to-app> <apple-id> <team-id>
set -e
APP="$1"
APPLE_ID="$2"
TEAM_ID="$3"
DMG="PortGuard.dmg"

echo "Archiving..."
xcodebuild archive -scheme PortGuard -archivePath PortGuard.xcarchive

echo "Exporting..."
xcodebuild -exportArchive -archivePath PortGuard.xcarchive \
  -exportPath export/ -exportOptionsPlist ExportOptions.plist

echo "Creating DMG..."
hdiutil create -volname "PortGuard" -srcfolder "export/PortGuard.app" \
  -ov -format UDZO "$DMG"

echo "Notarizing..."
xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" --password "@keychain:AC_PASSWORD" --wait

echo "Stapling..."
xcrun stapler staple "$DMG"

echo "Done: $DMG"
```

Make it executable: `chmod +x scripts/notarize.sh`

- [ ] **Step 3: Create minimal landing page**

```html
<!-- docs/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PortGuard — Network observability for Mac developers</title>
  <style>
    body { font-family: -apple-system, sans-serif; max-width: 680px; margin: 80px auto; padding: 0 20px; color: #1d1d1f; }
    h1 { font-size: 2.5rem; font-weight: 700; }
    p { font-size: 1.1rem; color: #666; line-height: 1.6; }
    .badge { background: #0071e3; color: white; padding: 12px 28px; border-radius: 8px; text-decoration: none; font-weight: 600; display: inline-block; margin-top: 24px; }
    .features { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 48px; }
    .feature h3 { font-size: 1rem; margin-bottom: 4px; }
    .feature p { font-size: 0.9rem; }
    footer { margin-top: 80px; color: #aaa; font-size: 0.85rem; }
  </style>
</head>
<body>
  <h1>PortGuard</h1>
  <p>See what's using your ports. Real-time process, port, and connection monitoring in your Mac menubar. Built for developers.</p>
  <a href="https://github.com/yourname/portguard/releases/latest" class="badge">Download Free</a>
  <a href="https://gumroad.com/l/portguard" class="badge" style="background:#333; margin-left:12px">Buy Pro — €15</a>

  <div class="features">
    <div class="feature">
      <h3>⚡ Real-time</h3>
      <p>Configurable polling from 1 to 30 seconds. Instant process launch/quit detection.</p>
    </div>
    <div class="feature">
      <h3>🔍 Quick Lookup</h3>
      <p>Press ⌥⌘P anywhere to search ports and processes instantly.</p>
    </div>
    <div class="feature">
      <h3>🔔 Pro: Alerts</h3>
      <p>Get notified when a port opens, closes, or a process makes a new connection.</p>
    </div>
    <div class="feature">
      <h3>📊 Pro: History</h3>
      <p>Persistent connection timeline. See what was running 2 hours ago.</p>
    </div>
  </div>

  <footer>
    <p>Free & open source (MIT). <a href="https://github.com/yourname/portguard">GitHub</a> · <a href="mailto:you@example.com">Contact</a></p>
  </footer>
</body>
</html>
```

- [ ] **Step 4: Create GitHub repo and push**

```bash
cd /Users/lorenzov/mobile_app_ideas/PortGuard
git remote add origin https://github.com/yourname/portguard.git
git push -u origin main
```

Enable GitHub Pages in repo settings → source: `docs/` folder.

- [ ] **Step 5: Final commit**

```bash
git add scripts/ docs/
git commit -m "feat(dist): add notarization script and landing page"
```

---

## End-to-End Verification Checklist

- [ ] `swift test` in `PortGuardCore/` — all tests pass
- [ ] Start app, wait one refresh interval, verify Ports tab shows LISTEN ports (cross-check with `lsof -i -n -P | grep LISTEN` in Terminal)
- [ ] Open a test server: `python3 -m http.server 9999` — verify port 9999 appears in Ports tab
- [ ] Test Quick Lookup (⌥⌘P): type "9999" — verify result shown
- [ ] Test Pro alerts: add rule for port 9999, start `python3 -m http.server 9999`, verify macOS notification fires
- [ ] Test Export: with Pro active, export CSV, open in Numbers/Excel and verify columns
- [ ] Test Sparkle: build release, set up appcast with newer version, verify in-app update prompt appears
- [ ] Test invalid license key → graceful error message, no crash
