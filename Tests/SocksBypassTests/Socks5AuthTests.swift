import Foundation
import XCTest
@testable import SocksBypass

final class Socks5AuthTests: XCTestCase {
    private let credentials = Socks5HandshakeParser.Credentials(username: "sbp", password: "tok")
    private let request = Data([0x05, 0x01, 0x00, 0x01, 127, 0, 0, 1, 0x1F, 0x90])

    private func auth(_ user: String, _ password: String) -> Data {
        Data([0x01, UInt8(user.utf8.count)]) + Data(user.utf8) + Data([UInt8(password.utf8.count)]) + Data(password.utf8)
    }

    func testRejectsNoAuthOnlyGreetingWhenAuthRequired() {
        var parser = Socks5HandshakeParser(credentials: credentials)
        let output = parser.feed(Data([0x05, 0x01, 0x00]))
        XCTAssertEqual(output.replies, [Data([0x05, 0xFF])])
        XCTAssertTrue(output.shouldClose)
    }

    func testCorrectCredentialsOneByteAtATime() {
        var parser = Socks5HandshakeParser(credentials: credentials)
        var replies: [Data] = []
        var connect: Socks5HandshakeParser.Request?
        for byte in Data([0x05, 0x02, 0x00, 0x02]) + auth("sbp", "tok") + request {
            let output = parser.feed(Data([byte]))
            replies += output.replies
            connect = output.request ?? connect
        }
        XCTAssertEqual(replies, [Data([0x05, 0x02]), Data([0x01, 0x00])])
        XCTAssertEqual(connect?.target, .init(address: "127.0.0.1", port: 8080))
    }

    func testWrongPasswordClosesWithFailure() {
        var parser = Socks5HandshakeParser(credentials: credentials)
        _ = parser.feed(Data([0x05, 0x01, 0x02]))
        let output = parser.feed(auth("sbp", "nope"))
        XCTAssertEqual(output.replies, [Data([0x01, 0x01])])
        XCTAssertTrue(output.shouldClose)
    }

    func testStatusRouteRequiresToken() {
        XCTAssertEqual(StatusServer.route(head: "GET /status HTTP/1.0\r\nAuthorization: Bearer tok", token: "tok", body: Data()).0, 200)
        XCTAssertEqual(StatusServer.route(head: "GET /status HTTP/1.0\r\nAuthorization: Bearer TOK", token: "tok", body: Data()).0, 401)
        XCTAssertEqual(StatusServer.route(head: "GET /status HTTP/1.0", token: "tok", body: Data()).0, 401)
    }
}
