# PortGuard

**Real-time process, port, and connection monitoring in your Mac menubar.**

Built for developers who want to know "who is using port 3000?" without opening a terminal. No firewall, no kernel extension — just observability.

![macOS](https://img.shields.io/badge/macOS-14+-000000?style=flat&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.10-FA7343?style=flat&logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Features

- **Three tabs** — Processes (with expandable detail), Ports in LISTEN state, Outbound connections
- **Real-time polling** — configurable from 1 to 30 seconds via `lsof`, instant process events via NSWorkspace
- **Quick Lookup** — press ⌥⌘P anywhere to search ports and processes in a floating overlay
- **Search** — always-visible search bar filters all tabs simultaneously
- **Pro: Custom alerts** — notify when a port opens/closes or a process makes a new connection
- **Pro: Persistent history** — connection snapshots stored locally, browse the timeline
- **Pro: Export** — one-click CSV or JSON snapshot of all current connections

## Download

**[→ Latest Release](https://github.com/Invernomut0/PortGuard/releases/latest)**

Download `PortGuard.dmg`, open it, drag to Applications.

> **First launch:** macOS may show a Gatekeeper warning. Go to **System Settings → Privacy & Security** and click "Open Anyway".

## Pro

**€15 one-time · Perpetual license · No subscription**

Custom alerts, persistent history, and export. [Buy on Gumroad →](https://gumroad.com/l/portguard)

Activate in **right-click → Settings… → License**.

---

## Architecture

```
PortGuardCore/          Swift Package — pure logic, fully tested
├── Models.swift        ConnectionRecord, PortRecord, ProcessRecord, LsofDiff, AlertRule
├── LsofPoller.swift    spawn lsof +c 0 -i -n -P, parse, diff
├── ProcessMonitor.swift NSWorkspace launch/quit notifications
└── DataStore.swift     @Observable, single source of truth

PortGuard/              Xcode app target — SwiftUI UI + Pro features
├── App/                AppDelegate, PortGuardApp
├── MenuBar/            NSStatusItem, NSPopover, right-click menu
├── UI/                 PopoverRootView, 3 tabs, QuickLookup, Settings
├── Pro/                AlertEngine, HistoryStore, ExportManager
└── License/            LicenseManager (Gumroad API + Keychain)
```

**Data flow:** `LsofPoller` polls every N seconds off the main thread → `LsofDiffEngine` computes added/removed → `DataStore` applies diff → SwiftUI re-renders. `AlertEngine` (Pro) evaluates rules against each diff and fires `UNUserNotification`.

## Requirements

- macOS 14 Ventura or later
- Distributed **outside the Mac App Store** — `lsof` and system-wide process reading require no sandbox

## Build

```bash
git clone https://github.com/Invernomut0/PortGuard.git
cd PortGuard
open PortGuard/PortGuard.xcodeproj
```

Run tests for the core package:

```bash
cd PortGuard/PortGuardCore
swift test
```

## Distribution

Sign with Developer ID + notarize:

```bash
cd PortGuard/PortGuard
./scripts/notarize.sh your@apple.id YOURTEAMID
```

See `scripts/ExportOptions.plist` — replace `REPLACE_WITH_YOUR_TEAM_ID` before running.

## License

MIT — see [LICENSE](LICENSE).

Pro features are closed-source and compiled into the same binary, gated by license key validation.
