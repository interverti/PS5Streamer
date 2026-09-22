import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var copiedOBS = false
    @State private var isStarting = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            statusSection
            Divider()
            dnsSection
            Divider()
            obsURLSection
            Divider()
            logSection
        }
        .frame(width: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 1) {
                Text("PS5 Stream Interceptor")
                    .font(.headline)
                Text("RTMP → nginx → OBS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                    ProgressView().controlSize(.small)
                } else {
                    Text(state.isRunning ? "Stop" : "Start")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(state.isRunning ? .red : .purple)
            .disabled(isStarting)
            .frame(width: 70)
        }
        .padding()
    }

    // MARK: - Service Status

    var statusSection: some View {
        HStack(spacing: 32) {
            StatusDot(label: "RTMP :1935", status: state.rtmpStatus)
            StatusDot(label: "DNS  :53",   status: state.dnsStatus)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - PS5 DNS Instructions

    var dnsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Set on PS5 → Settings → Network → Advanced → DNS", systemImage: "network")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                dnsRow(label: "Primary",   value: state.localIP)
                dnsRow(label: "Secondary", value: "1.1.1.1")
            }
        }
        .padding()
    }

    func dnsRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .fontDesign(.monospaced)
                .font(.system(size: 14, weight: .medium))
                .textSelection(.enabled)
        }
    }

    // MARK: - OBS URL

    var obsURLSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("OBS → Sources → Media Source → uncheck Local File → paste URL", systemImage: "tv")
                .font(.caption)
                .foregroundStyle(.secondary)

            if state.streamKey != nil {
                HStack(spacing: 8) {
                    Text(state.obsURL)
                        .fontDesign(.monospaced)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)

                    Button(copiedOBS ? "✓" : "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(state.obsURL, forType: .string)
                        copiedOBS = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedOBS = false }
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 55)
                }
            } else {
                Text(state.isRunning ? "⏳ Waiting for PS5 to go live…" : "Start intercepting first")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                    .padding(.vertical, 4)
            }
        }
        .padding()
    }

    // MARK: - Log

    var logSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Log", systemImage: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { state.logs.removeAll() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(state.logs, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .frame(height: 110)
        }
    }
}

// MARK: - StatusDot

struct StatusDot: View {
    let label: String
    let status: ServiceStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(status == .running ? 0.7 : 0), radius: 4)
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(status == .running ? .primary : .secondary)
        }
    }

    var color: Color {
        switch status {
        case .stopped:  return .gray
        case .starting: return .yellow
        case .running:  return .green
        case .error:    return .red
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
