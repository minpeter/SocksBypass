import Foundation
import Network

/// Tiny HTTP/1.0 JSON endpoint for the Linux companion.
///
/// `GET /status` with `Authorization: Bearer <token>` returns the latest
/// snapshot set through `update`. Anything else gets 401/404. One request per
/// connection; the connection is closed after the reply.
final class StatusServer {
    static let defaultPort: UInt16 = 9877
    private static let maxRequestBytes = 8 * 1024

    private let queue = DispatchQueue(label: "com.minpeter.socksbypass.status")
    private let port: UInt16
    private var listener: NWListener?
    private var token: String?
    private var body = Data("{}".utf8)

    init(port: UInt16 = StatusServer.defaultPort) {
        self.port = port
    }

    /// `token == nil` serves without auth (only when the proxy itself runs NO AUTH).
    func start(token: String?) {
        queue.async {
            self.token = token
            guard self.listener == nil, let port = NWEndpoint.Port(rawValue: self.port) else { return }
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            guard let listener = try? NWListener(using: parameters, on: port) else { return }
            listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
            listener.start(queue: self.queue)
            self.listener = listener
        }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
        }
    }

    func update(_ status: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: status, options: [.sortedKeys]) else { return }
        queue.async { self.body = data }
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
        queue.asyncAfter(deadline: .now() + 5) { connection.cancel() }
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxRequestBytes) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
                self.respond(connection, Self.route(head: head, token: self.token, body: self.body))
            } else if isComplete || error != nil || buffer.count >= Self.maxRequestBytes {
                self.respond(connection, (400, Data()))
            } else {
                self.receive(connection, buffer: buffer)
            }
        }
    }

    /// Pure routing so it can be tested without sockets.
    static func route(head: String, token: String?, body: Data) -> (Int, Data) {
        let lines = head.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return (405, Data()) }
        guard parts[1] == "/status" else { return (404, Data()) }
        if let token {
            let expected = Data("bearer \(token)".utf8)
            let authorized = lines.dropFirst().contains { line in
                guard let colon = line.firstIndex(of: ":"),
                      line[..<colon].lowercased() == "authorization" else { return false }
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                // Scheme is case-insensitive, token is not.
                let normalized = value.prefix(7).lowercased() + value.dropFirst(7)
                return Socks5HandshakeParser.constantTimeEqual(Data(normalized.utf8), expected)
            }
            guard authorized else { return (401, Data()) }
        }
        return (200, body)
    }

    private func respond(_ connection: NWConnection, _ reply: (Int, Data)) {
        let reason = [200: "OK", 400: "Bad Request", 401: "Unauthorized", 404: "Not Found", 405: "Method Not Allowed"][reply.0] ?? "Error"
        var head = "HTTP/1.0 \(reply.0) \(reason)\r\nContent-Length: \(reply.1.count)\r\nConnection: close\r\n"
        if reply.0 == 200 { head += "Content-Type: application/json\r\n" }
        if reply.0 == 401 { head += "WWW-Authenticate: Bearer\r\n" }
        var data = Data((head + "\r\n").utf8)
        data.append(reply.1)
        connection.send(content: data, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
