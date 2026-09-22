import Foundation

enum Paths {
    /// All app files live here — user-owned, survives reboots
    static let workDir = "\(NSHomeDirectory())/.ps5streamer"

    static let nginxConf    = "\(workDir)/nginx.conf"
    static let nginxPid     = "\(workDir)/nginx.pid"
    static let nginxErrLog  = "\(workDir)/nginx-error.log"
    static let dnsmasqConf  = "\(workDir)/dnsmasq.conf"
    static let dnsmasqLog   = "\(workDir)/dnsmasq.log"
    static let dnsmasqOut   = "\(workDir)/dnsmasq-out.log"
    static let dnsmasqErr   = "\(workDir)/dnsmasq-err.log"
    static let dnsmasqPlist = "\(workDir)/com.ps5streamer.dnsmasq.plist"

    static func createWorkDir() {
        try? FileManager.default.createDirectory(
            atPath: workDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
    }
}
