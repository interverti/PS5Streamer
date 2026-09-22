import Foundation
import AppKit

// MARK: - Errors

enum ProcessManagerError: LocalizedError {
    case nginxNotFound
    case dnsmasqNotFound
    case nginxFailed(String)
    case dnsmasqFailed(String)
    case adminCancelled

    var errorDescription: String? {
        switch self {
        case .nginxNotFound:
            return "nginx not found. Install: brew tap denji/nginx && brew install nginx-full"
        case .dnsmasqNotFound:
            return "dnsmasq not found. Install: brew install dnsmasq"
        case .nginxFailed(let m):
            return "nginx failed: \(m)"
        case .dnsmasqFailed(let m):
            return "dnsmasq failed: \(m)"
        case .adminCancelled:
            return "Admin access required for DNS interception (port 53)."
        }
    }
}

// MARK: - ProcessManager

final class ProcessManager {

    private var nginxProcess: Process?

    /// Called when nginx crashes unexpectedly after a successful start.
    var onNginxCrash: (() -> Void)?

    // MARK: - nginx (plain Process — port 1935 doesn't need root)

    func startNginx(configPath: String) throws {
        guard let bin = resolveNginxBin() else {
            throw ProcessManagerError.nginxNotFound
        }

        // Kill any stray nginx from a previous session first
        killStrayNginx(bin: bin)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments     = ["-c", configPath, "-g", "daemon off;"]

        let pipe = Pipe()
        p.standardError  = pipe
        p.standardOutput = pipe

        // Notify app if nginx crashes after a clean start
        p.terminationHandler = { [weak self] process in
            if process.terminationStatus != 0 {
                DispatchQueue.main.async { self?.onNginxCrash?() }
            }
        }

        try p.run()
        nginxProcess = p

        // Give nginx time to bind or fail
        Thread.sleep(forTimeInterval: 0.8)

        if !p.isRunning {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg  = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
            throw ProcessManagerError.nginxFailed(msg)
        }
    }

    func stopNginx() {
        nginxProcess?.terminate()
        nginxProcess?.waitUntilExit()
        nginxProcess = nil
        try? FileManager.default.removeItem(atPath: Paths.nginxPid)
    }

    private func killStrayNginx(bin: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        p.arguments     = ["-f", bin]
        try? p.run()
        p.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.3)
    }

    // MARK: - dnsmasq (LaunchDaemon — port 53 needs root)

    func startDnsmasq(configPath: String) async throws {
        guard let bin = resolveDnsmasqBin() else {
            throw ProcessManagerError.dnsmasqNotFound
        }

        let plist    = buildDnsmasqPlist(bin: bin, configPath: configPath)
        let tmpPlist  = Paths.dnsmasqPlist
        let destPlist = "/Library/LaunchDaemons/com.ps5streamer.dnsmasq.plist"

        try plist.write(toFile: tmpPlist, atomically: true, encoding: .utf8)

        // Unload any existing instance before loading the new one (avoids conflicts)
        let shell = """
        launchctl unload '\(destPlist)' 2>/dev/null || true
        cp '\(tmpPlist)' '\(destPlist)'
        chmod 644 '\(destPlist)'
        launchctl load '\(destPlist)'
        """
        try await runWithAdmin(shell: shell)
    }

    func stopDnsmasq() {
        let destPlist = "/Library/LaunchDaemons/com.ps5streamer.dnsmasq.plist"
        let shell = """
        launchctl unload '\(destPlist)' 2>/dev/null || true
        rm -f '\(destPlist)'
        """
        Task { try? await runWithAdmin(shell: shell) }
    }

    // MARK: - Stop all

    func stopAll() {
        stopNginx()
        stopDnsmasq()
    }

    // MARK: - Binary resolution

    private func resolveNginxBin() -> String? {
        let candidates = [
            Bundle.main.resourcePath.map { "\($0)/Binaries/nginx" },
            Optional("/opt/homebrew/bin/nginx"),
            Optional("/usr/local/bin/nginx"),
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func resolveDnsmasqBin() -> String? {
        let candidates = [
            Bundle.main.resourcePath.map { "\($0)/Binaries/dnsmasq" },
            Optional("/opt/homebrew/sbin/dnsmasq"),
            Optional("/usr/local/sbin/dnsmasq"),
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - dnsmasq LaunchDaemon plist

    private func buildDnsmasqPlist(bin: String, configPath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
            "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.ps5streamer.dnsmasq</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(bin)</string>
                <string>--conf-file=\(configPath)</string>
                <string>--no-daemon</string>
                <string>--port=53</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(Paths.dnsmasqOut)</string>
            <key>StandardErrorPath</key>
            <string>\(Paths.dnsmasqErr)</string>
        </dict>
        </plist>
        """
    }

    // MARK: - AppleScript admin runner

    @discardableResult
    private func runWithAdmin(shell: String) async throws -> String {
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let src = #"do shell script "\#(escaped)" with administrator privileges"#

        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let result = NSAppleScript(source: src)?.executeAndReturnError(&error)

                if let err = error {
                    let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown"
                    if msg.localizedCaseInsensitiveContains("cancel") {
                        cont.resume(throwing: ProcessManagerError.adminCancelled)
                    } else {
                        cont.resume(throwing: ProcessManagerError.dnsmasqFailed(msg))
                    }
                } else {
                    cont.resume(returning: result?.stringValue ?? "")
                }
            }
        }
    }
}
