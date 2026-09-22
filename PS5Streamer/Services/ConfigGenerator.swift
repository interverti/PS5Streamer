import Foundation

struct GeneratedConfigs {
    let nginxConfig:   String
    let dnsmasqConfig: String
}

struct ConfigGenerator {

    func generate(macIP: String) -> GeneratedConfigs {
        Paths.createWorkDir()

        try? nginxConfig().write(toFile: Paths.nginxConf, atomically: true, encoding: .utf8)
        try? dnsmasqConfig(macIP: macIP).write(toFile: Paths.dnsmasqConf, atomically: true, encoding: .utf8)

        return GeneratedConfigs(nginxConfig: Paths.nginxConf, dnsmasqConfig: Paths.dnsmasqConf)
    }

    // MARK: - nginx.conf

    private func nginxConfig() -> String {
        return """
        worker_processes 1;
        error_log \(Paths.nginxErrLog) warn;
        pid       \(Paths.nginxPid);

        events {
            worker_connections 512;
        }

        rtmp {
            server {
                listen 1935;
                chunk_size 4096;

                application app {
                    live on;
                    record off;
                    sync 10ms;
                    on_publish http://127.0.0.1:9988/on_publish;
                    # push rtmp://live.twitch.tv/app/YOUR_TWITCH_KEY;
                }

                application live2 {
                    live on;
                    record off;
                    on_publish http://127.0.0.1:9988/on_publish;
                }
            }
        }

        http {
            server {
                listen 8080;
                location /stat { rtmp_stat all; }
            }
        }
        """
    }

    // MARK: - dnsmasq.conf

    private func dnsmasqConfig(macIP: String) -> String {
        let ingestHosts = [
            "contribute.live-video.net",
            "ingest.global-contribute.live-video.net",
            "live.twitch.tv",
            "live-sin.twitch.tv",
            "live-nrt.twitch.tv",
            "live-syd.twitch.tv",
            "live-fra.twitch.tv",
            "live-ams.twitch.tv",
            "live-lhr.twitch.tv",
            "live-jfk.twitch.tv",
            "live-lax.twitch.tv",
            "live-sea.twitch.tv",
        ]

        let addressLines = ingestHosts
            .map { "address=/\($0)/\(macIP)" }
            .joined(separator: "\n")

        return """
        server=1.1.1.1
        server=8.8.8.8

        \(addressLines)

        log-queries
        log-facility=\(Paths.dnsmasqLog)

        no-hosts
        listen-address=0.0.0.0
        """
    }
}
