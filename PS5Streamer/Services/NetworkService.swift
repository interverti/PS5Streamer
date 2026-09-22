import Darwin
import Foundation

enum NetworkService {
    /// Returns the Mac's primary LAN IP (prefers en0/WiFi, falls back to en1/Ethernet).
    static func getLANIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var fallback: String?
        var ptr = ifaddr

        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }

            let iface = current.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: iface.ifa_name)
            guard name == "en0" || name == "en1" else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                iface.ifa_addr,
                socklen_t(iface.ifa_addr.pointee.sa_len),
                &host, socklen_t(host.count),
                nil, 0,
                NI_NUMERICHOST
            )
            let ip = String(cString: host)
            if name == "en0" {
                return ip
            } // WiFi wins immediately
            fallback = ip // Ethernet fallback
        }
        return fallback
    }
}
