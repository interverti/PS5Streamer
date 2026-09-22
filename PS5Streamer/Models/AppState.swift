import Foundation

enum ServiceStatus: Equatable {
    case stopped
    case starting
    case running
    case error(String)

    var label: String {
        switch self {
        case .stopped:       return "Stopped"
        case .starting:      return "Starting…"
        case .running:       return "Running"
        case .error(let m):  return "Error: \(m)"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isRunning    = false
    @Published var dnsStatus:  ServiceStatus = .stopped
    @Published var rtmpStatus: ServiceStatus = .stopped
    @Published var streamKey:  String?
    @Published var localIP:    String = "Detecting…"
    @Published var logs:       [String] = []

    private let processManager  = ProcessManager()
    private let configGenerator = ConfigGenerator()
    private var streamKeyServer: StreamKeyServer?

    init() {
        localIP = NetworkService.getLANIP() ?? "Not found"

        // If nginx crashes mid-stream, reflect it in the UI
        processManager.onNginxCrash = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.rtmpStatus = .error("nginx crashed")
                self.streamKey  = nil
                self.log("❌ nginx crashed — check \(Paths.nginxErrLog)")
                self.log("ℹ️ Click Stop then Start to recover")
            }
        }
    }

    // MARK: - Control

    func start() async {
        guard !isRunning else { return }

        localIP = NetworkService.getLANIP() ?? ""
        let configs = configGenerator.generate(macIP: localIP)

        // 1 — nginx (plain Process, port 1935, no root needed)
        rtmpStatus = .starting
        do {
            try processManager.startNginx(configPath: configs.nginxConfig)
            rtmpStatus = .running
            log("✅ RTMP server running on :1935")
        } catch {
            rtmpStatus = .error(error.localizedDescription)
            log("❌ RTMP: \(error.localizedDescription)")
            return
        }

        // 2 — StreamKeyServer (catches nginx on_publish callback on :9988)
        streamKeyServer = StreamKeyServer { [weak self] app, key in
            Task { @MainActor [weak self] in
                self?.streamApp = app
                self?.streamKey = key
                self?.log("🎮 PS5 connected via /\(app)/ — stream key detected")
            }
        }
        streamKeyServer?.start()

        // 3 — dnsmasq LaunchDaemon (needs admin — port 53)
        dnsStatus = .starting
        do {
            try await processManager.startDnsmasq(configPath: configs.dnsmasqConfig)
            dnsStatus = .running
            log("✅ DNS interceptor running on :53")
        } catch {
            dnsStatus = .error(error.localizedDescription)
            log("❌ DNS: \(error.localizedDescription)")
            // Roll back nginx if dnsmasq fails
            processManager.stopNginx()
            rtmpStatus = .stopped
            streamKeyServer?.stop()
            streamKeyServer = nil
            return
        }

        isRunning = true
        log("🚀 Ready — broadcast from PS5 to YouTube")
    }

    func stop() {
        processManager.stopAll()
        streamKeyServer?.stop()
        streamKeyServer = nil
        isRunning  = false
        dnsStatus  = .stopped
        rtmpStatus = .stopped
        streamKey  = nil
        log("⏹ Stopped — all services cleaned up")
    }

    // MARK: - Derived

    var obsURL: String {
        guard let key = streamKey else { return "" }
        return "rtmp://127.0.0.1/\(streamApp)/\(key)"
    }



    /// The RTMP application name ("app" for Twitch, "live2" for YouTube)
    var streamApp: String = "app"

    // MARK: - Logging

    private func log(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.insert("[\(ts)] \(message)", at: 0)
        if logs.count > 200 { logs.removeLast() }
    }
}
