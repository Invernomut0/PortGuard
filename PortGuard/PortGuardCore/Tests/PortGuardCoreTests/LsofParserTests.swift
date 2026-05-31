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
