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
