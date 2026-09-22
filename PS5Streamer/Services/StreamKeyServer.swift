import Foundation
import Network

/// Tiny HTTP server that listens on :9988 for nginx-rtmp's on_publish callbacks.
///
/// When the PS5 starts streaming, nginx-rtmp POSTs to:
///   POST http://127.0.0.1:9988/on_publish
///   Body: app=live&name=live_XXXXXXXXXX&addr=192.168.x.x&...
///
/// We parse `name` from the body and call onKeyDetected.
final class StreamKeyServer {
    private var listener: NWListener?
    private let port: UInt16 = 9988
    private let onKeyDetected: (_ app: String, _ key: String) -> Void
    private let queue = DispatchQueue(label: "com.ps5streamer.streamkeyserver")

    init(onKeyDetected: @escaping (_ app: String, _ key: String) -> Void) {
        self.onKeyDetected = onKeyDetected
    }

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            print("StreamKeyServer: failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(connection: conn)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:   print("StreamKeyServer: listening on :9988")
            case .failed(let e): print("StreamKeyServer: failed — \(e)")
            default: break
            }
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)

        // Receive up to 8 KB (more than enough for an RTMP notify POST)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            defer {
                // Always respond 200 so nginx-rtmp allows the stream
                let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                connection.send(content: response.data(using: .utf8),
                                completion: .contentProcessed { _ in connection.cancel() })
            }

            guard let data, let body = String(data: data, encoding: .utf8) else { return }

            // HTTP request arrives as "POST /on_publish HTTP/1.1\r\n...\r\n\r\n<body>"
            // The body is URL-encoded form data: app=live&flashver=...&name=live_XXXX&...
            if let (app, key) = self?.parseStreamInfo(from: body) {
                self?.onKeyDetected(app, key)
            }
        }
    }

    // MARK: - Parsing

    private func parseStreamInfo(from httpRequest: String) -> (app: String, key: String)? {
        let parts = httpRequest.components(separatedBy: "\r\n\r\n")
        guard let body = parts.last, !body.isEmpty else { return nil }

        var params: [String: String] = [:]
        for pair in body.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
            }
        }

        guard let key = params["name"] else { return nil }
        let app = params["app"] ?? "app"
        return (app, key)
    }
}
