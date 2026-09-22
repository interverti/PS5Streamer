import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var isStarting = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            services
            Divider()
            dnsInfo
            Divider()
            urlSection
            Divider()
            logSection
            Divider()
            footer
        }
        .frame(width: 340)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.purple)
            Text("PS5 Streamer")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button {
                Task {
                    if state.isRunning {
                        state.stop()
                    } else {
                        isStarting = true
                        await state.start()
                        isStarting = false
                    }
                }
            } label: {
                if isStarting {
                    ProgressView().controlSize(.small).frame(width: 52)
                } else {
                    Text(state.isRunning ? "Stop" : "Start").frame(width: 52)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(state.isRunning ? .red : .purple)
            .controlSize(.regular)
            .disabled(isStarting)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Services

    var services: some View {
        HStack(spacing: 20) {
            statusDot(label: "RTMP :1935", status: state.rtmpStatus)
            statusDot(label: "DNS :53",    status: state.dnsStatus)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    func statusDot(label: String, status: ServiceStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(for: status))
                .frame(width: 8, height: 8)
                .shadow(color: color(for: status).opacity(status == .running ? 0.8 : 0), radius: 4)
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - DNS Info

    var dnsInfo: some View {
        HStack {
            dnsField(label: "PS5 DNS", value: state.localIP)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    func dnsField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    // MARK: - URL

    var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("mpv URL")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            if state.streamKey != nil {
                HStack(spacing: 8) {
                    Text(state.obsURL)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(state.obsURL, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text(state.isRunning ? "Waiting for PS5…" : "Start to get URL")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Log

    var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Log")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Clear") { state.logs.removeAll() }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(state.logs, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    var footer: some View {
        HStack {
            Spacer()
            Button("Quit") {
                state.stop()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    func color(for status: ServiceStatus) -> Color {
        switch status {
        case .stopped:  return .gray
        case .starting: return .yellow
        case .running:  return .green
        case .error:    return .red
        }
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
