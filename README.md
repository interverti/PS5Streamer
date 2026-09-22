# PS5 Stream Interceptor

Intercepts PS5 RTMP streams locally so you can route them anywhere — OBS, X, Discord, record — without Twitch ever seeing them.

```
PS5 ──RTMP──▶ Mac (nginx-rtmp :1935)
                     │
                     ▼
                    OBS ──▶ X / Discord / Record / anywhere
```

## How it works

1. PS5 links a Twitch account (just to unlock the broadcast UI)
2. App sets up a fake DNS server (dnsmasq) that lies to the PS5 — `live.twitch.tv` → your Mac IP
3. PS5 pushes RTMP to your Mac instead of Twitch
4. nginx-rtmp receives it; OBS pulls it as a Media Source
5. You stream/record wherever you want from OBS

---

## Prerequisites

```bash
# nginx with RTMP module (denji tap)
brew tap denji/nginx
brew install nginx-full

# dnsmasq
brew install dnsmasq
```

---

## Build

### 1. Install xcodegen
```bash
brew install xcodegen
```

### 2. Generate Xcode project
```bash
cd ~/PS5Streamer
xcodegen generate
open PS5Streamer.xcodeproj
```

### 3. Set your Team
In Xcode → PS5Streamer target → Signing → select your Apple ID team.

### 4. Build & Run
`Cmd+R` — that's it.

---

## Usage

1. **Start Intercepting** — app prompts for admin password (needed for dnsmasq on port 53)
2. **Set PS5 DNS** — on PS5: Settings → Network → Advanced → DNS → Manual
   - Primary: `<your Mac IP shown in the app>`
   - Secondary: `1.1.1.1`
3. **Go Live on PS5** — use the Twitch broadcast option
4. **Copy OBS URL** — paste it in OBS as a Media Source (uncheck Local File)
5. Stream/record from OBS to anywhere

---

## Restreaming (optional)

Uncomment lines in nginx.conf (auto-generated to `/tmp/ps5streamer/nginx.conf`):

```nginx
# push rtmp://live.twitch.tv/app/YOUR_TWITCH_KEY;
# push rtmp://ingest.pscp.tv:80/x/YOUR_X_KEY;
# push rtmp://a.rtmp.youtube.com/live2/YOUR_YOUTUBE_KEY;
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| PS5 DNS not using Mac | Disable PS5 WiFi, reconnect, re-enter DNS |
| Stream key not detected | Check `/tmp/ps5streamer/nginx-error.log` |
| dnsmasq won't start | Check `/tmp/ps5streamer/dnsmasq-err.log` |
| nginx not found | Confirm `brew install nginx-full` (denji tap, not default) |
| OBS shows black | Make sure PS5 is actively broadcasting |
| Wrong regional ingest | Check `/tmp/ps5streamer/dnsmasq.log` for the exact hostname |

---

## File layout

```
PS5Streamer/
├── Models/
│   └── AppState.swift          — published state, orchestrates services
├── Views/
│   └── ContentView.swift       — SwiftUI UI
├── Services/
│   ├── NetworkService.swift    — detects your Mac's LAN IP
│   ├── ConfigGenerator.swift   — writes nginx.conf + dnsmasq.conf to /tmp
│   ├── ProcessManager.swift    — spawns nginx; installs/loads dnsmasq LaunchDaemon
│   └── StreamKeyServer.swift   — NWListener on :9988, receives nginx on_publish callback
└── PS5StreamerApp.swift
```
