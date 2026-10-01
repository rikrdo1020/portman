# Portman

A native macOS menu bar app to monitor and kill development services running in the background — TCP ports, Docker containers, CPU usage, and idle detection.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square)
![License MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![No dependencies](https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square)

---

## The problem

You start a Next.js dev server, spin up a Postgres container, run a background API — then close your laptop and forget about all of it. Hours later your battery is drained and fans are spinning. There was nothing in your menu bar telling you any of those processes were still running.

Portman fixes that.

---

## Features

- **Real-time port scanning** — lists every TCP process listening on your machine, filtered to dev ports (3000–9999 + common DB ports by default)
- **Docker integration** — shows running containers with CPU and memory stats
- **CPU + memory metrics** — aggregated per process group (so `node` + its `esbuild`/worker children show the true combined cost)
- **Idle detection** — alerts when a service has had no active connections for N minutes but is still burning CPU
- **One-click kill** — sends `SIGTERM` to the entire process group, then `SIGKILL` after 3 seconds; no orphan processes
- **Kill all** — stops every dev service and container at once, with confirmation
- **Left and right click** — both open the panel (no context menu hiding it)
- **Light and dark menu bar icon** — switches automatically with the system
- **Zero battery cost when idle** — polls every 15 s when closed, 3 s when open, pauses on screen lock
- **No Electron, no Node, no external dependencies** — pure Swift + AppKit + SwiftUI

---

## Screenshot

> Panel showing ports, Docker containers, and an idle service alert.

*(Add a screenshot here)*

---

## Requirements

| | |
|---|---|
| macOS | 14.0 Sonoma or later |
| Architecture | Apple Silicon (arm64) |
| Build tool | Xcode Command Line Tools (`xcode-select --install`) |
| Optional | Docker Desktop (for container monitoring) |

> No Xcode.app needed — Command Line Tools alone are enough.

---

## Install

### Option A — Build from source

```bash
git clone https://github.com/rikrdo1020/portman.git
cd portman
./Scripts/bundle.sh
open build/Portman.app
```

To install to `/Applications` and optionally add a Login Item:

```bash
./Scripts/install.sh
```

### Option B — Download release

Download the latest `.app` from the [Releases](https://github.com/rikrdo1020/portman/releases) page, unzip, and drag to `/Applications`.

> **Gatekeeper notice:** The app is ad-hoc signed (not notarized). On first launch, right-click → Open if macOS blocks it.

---

## Usage

Click the server icon in your menu bar (or two-finger click). The panel opens showing:

| Section | What it shows |
|---|---|
| **PORTS** | TCP listeners classified as dev services |
| **DOCKER** | Running containers (requires Docker Desktop running) |
| **OTHER** | Non-dev system ports — collapsed by default, toggle in Settings |

**Killing a service**

Hover over any row — a kill button appears on the right. Click it to send `SIGTERM` to the entire process group. The row disappears immediately (optimistic removal) and a `SIGKILL` follows after 3 s if the process is still alive.

**Kill all**

Footer → Kill all → confirm. Kills every dev port and container at once.

**Idle alert**

When a service has had no established TCP connections for longer than your threshold (default 20 min) *and* its CPU is above the minimum threshold (default 1%), the row turns orange with a flame icon and a system notification fires.

---

## Settings

Open via the sliders icon in the panel header.

| Setting | Default | Description |
|---|---|---|
| Dev port range | 3000–9999 | Ports in this range are shown under PORTS |
| Inactive time | 20 min | Minutes with no connections before idle alert |
| Min CPU to alert | 1.0% | CPU floor for idle alerts (filters sleeping processes) |
| Show system ports | off | Toggle visibility of non-dev ports in OTHER |

Settings persist across launches via `UserDefaults`.

---

## How it works

### Port scanning

```
lsof -nP -iTCP -sTCP:LISTEN -F pcnLR
```

`-F` format outputs one field per line with a letter prefix (`p`=pid, `c`=command, `n`=address, …). This handles commands with spaces in their name (`Code Helper`, `LM Studio`) that break column-based parsing.

Results are filtered by:
- **User**: only processes belonging to the current login user
- **Command denylist**: `ControlCenter`, `rapportd`, `OneDrive`, `sharingd`, `Microsoft*`, etc.
- **Port range + known commands**: `node`, `python*`, `ruby`, `java`, `deno`, `bun`, `go`, `cargo` are always dev regardless of port

### CPU aggregation

A single `ps -Ao pid=,ppid=,pgid=,%cpu=,rss=` call per cycle builds a process table. CPU is summed by `pgid` (process group ID) so a Node server with an esbuild child and several workers shows the real combined cost, not just the parent's slice.

### Idle detection

Each cycle, `lsof -nP -iTCP -sTCP:ESTABLISHED` returns every pid with an active connection. Pids with no established connections for longer than the threshold and CPU above the floor are marked `idleBurning`. The menu bar icon turns orange; a `UNUserNotification` fires once per crossing.

### Docker

`docker ps` lists containers; `docker stats --no-stream` fetches metrics in a separate 30 s cycle to avoid blocking the faster port poll. If the Docker daemon is not running, the panel shows a soft warning — no crash, no spinner.

### Killing processes

```swift
Darwin.killpg(pgid, SIGTERM)
// → SIGKILL after 3 s if process group still alive
```

Killing the process **group** (not just the pid) ensures workers, watchers, and forked children are all terminated. No orphan processes.

### No `sudo` required

`lsof` and `ps` on macOS report the current user's own processes without elevated privileges. No helper tool, no privileged daemon.

---

## Project structure

```
Sources/Portman/
├── App/
│   ├── ServicesPanelApp.swift   @main entry point
│   └── AppDelegate.swift        NSStatusItem + NSPopover, click handling
├── Models/
│   └── Service.swift            Service, ServiceKind, Metrics, HealthState
├── Core/
│   ├── Shell.swift              Process runner (absolute paths, timeout)
│   ├── PortScanner.swift        lsof parser + dev service classifier
│   ├── ProcessMetrics.swift     ps sampling, pgid aggregation
│   ├── DockerClient.swift       docker ps / stats / stop
│   ├── IdleWatcher.swift        connection tracking + idle state
│   ├── Preferences.swift        UserDefaults-backed settings
│   └── PhIcon.swift             Phosphor SVG icon loader
├── Store/
│   └── ServicesStore.swift      @MainActor ObservableObject, poll loop, actions
└── Views/
    ├── PanelView.swift          Main popover panel
    ├── ServiceRow.swift         Individual service row
    └── SettingsWindow.swift     Preferences window
Resources/
├── Info.plist                   LSUIElement=1, no Dock icon
├── AppIcon.icns                 App icon (all sizes)
└── Icons/                       Phosphor SVGs + menu bar PNGs
Scripts/
├── bundle.sh                    swift build → .app → codesign
└── install.sh                   Copy to /Applications + LaunchAgent
```

---

## Build scripts

### `Scripts/bundle.sh`

1. Runs `swift build -c release --arch arm64`
2. Assembles `Portman.app/Contents/{MacOS,Resources}`
3. Copies `Info.plist`, `AppIcon.icns`, and all resource files
4. Ad-hoc signs with `codesign --force --sign -`

### `Scripts/install.sh`

Copies `build/Portman.app` to `/Applications` and optionally writes a `LaunchAgent` plist at `~/Library/LaunchAgents/com.ricardobarria.portman.plist` so the app starts at login.

---

## Icons

UI icons are from [Phosphor Icons](https://phosphoricons.com/) (MIT license), bundled as SVGs and loaded at runtime via `NSImage(contentsOf:)` — macOS 12+ renders SVG natively.

The menu bar icon ships in light and dark variants (`menubar-light.png`, `menubar-dark.png`) and switches automatically with `AppleInterfaceThemeChangedNotification`.

---

## Contributing

Pull requests welcome.

```bash
# Clone and build
git clone https://github.com/rikrdo1020/portman.git
cd portman
swift build

# Run (note: must be the .app bundle to appear in menu bar)
./Scripts/bundle.sh && open build/Portman.app
```

Issues, feature ideas, and port denylist additions (for noisy system processes on your machine) are especially welcome — the classifier is only as good as the denylist.

---

## License

MIT — see [LICENSE](LICENSE).
