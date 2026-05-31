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
