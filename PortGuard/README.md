# PortGuard

**Real-time process, port, and connection monitoring in your Mac menubar.**

Built for developers who want to know "who is using port 3000?" without opening a terminal. No firewall, no kernel extension — just observability.

![macOS](https://img.shields.io/badge/macOS-14+-000000?style=flat&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.10-FA7343?style=flat&logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Features

| | Free | Pro |
|---|:---:|:---:|
| Live ports, processes & connections | ✓ | ✓ |
| Search by process, port, or host | ✓ | ✓ |
| Unsigned-process warning | ✓ | ✓ |
| Quick Lookup overlay (⌥⌘P) | ✓ | ✓ |
| **Kill process** (with confirmation) | | ✓ |
| Custom alert rules | | ✓ |
| Export — CSV / JSON | | ✓ |
| Persistent connection history (24 h) | | ✓ |

---

## Download

**[→ Latest Release](https://github.com/Invernomut0/PortGuard/releases/latest)**

Download `PortGuard.dmg`, open it, drag to Applications.

> **First launch:** macOS may show a Gatekeeper warning. Go to **System Settings → Privacy & Security** and click "Open Anyway". PortGuard is distributed outside the App Store because `lsof` access is blocked by the sandbox.

---

## Usage

Click the **network icon** in your menu bar to open the popover.

| Tab | What it shows |
|---|---|
| **Processes** | Every process with open connections, expandable to see each socket |
| **Ports** | All ports currently in LISTEN state |
| **Connections** | Established outbound connections with reverse DNS |

- **Search** — filters all three tabs simultaneously
- **Quick Lookup** — press **⌥⌘P** from anywhere to open a floating search overlay
- **Right-click** the menu bar icon for Settings and Quit

---

## Pro

**One-time purchase · Perpetual license · No subscription**

[Buy on Gumroad →](https://invernomuto.gumroad.com/l/portguard)

### Kill process

Any process visible in the **Ports** or **Processes** tab has a kill button (Pro only). Clicking it shows a confirmation dialog before sending `SIGTERM`.

### Custom alert rules

Get a native macOS notification when:
- A specific port opens or closes
- A process makes a new outbound connection
- Any new connection is established

Configure rules via the **bell icon** in the popover footer.

### Export

One-click snapshot of all current connections, saved as **CSV** or **JSON**.

### Persistent history

Connections are snapshotted every 5 minutes and retained for 24 hours in `~/Library/Application Support/PortGuard/history.json`.

### Activating your license

1. Right-click the menu bar icon → **Settings…**
2. Go to the **License** section
3. Paste your key (`XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX`)
4. Click **Activate**

The key is stored securely in macOS Keychain and re-validated at launch.

---

## Architecture

```
PortGuardCore/            Swift Package — pure logic, fully tested
├── Models.swift          ConnectionRecord, PortRecord, LsofDiff, AlertRule…
├── LsofPoller.swift      Spawns lsof +c 0 -i -n -P, parses output, diffs
├── ProcessMonitor.swift  NSWorkspace launch/quit notifications
└── DataStore.swift       @Observable, single source of truth

PortGuard/                Xcode app target — SwiftUI UI + Pro features
├── App/                  AppDelegate, PortGuardApp (global hotkey, poller wiring)
├── MenuBar/              NSStatusItem, NSPopover, right-click context menu
├── UI/                   PopoverRootView, 3 tabs, QuickLookup, Settings
├── Pro/                  AlertEngine, HistoryStore, ExportManager
└── License/              LicenseManager (Gumroad API + Keychain)
```

**Data flow:**
```
lsof (every N seconds, off main thread)
  → LsofParser        → [ConnectionRecord]
  → LsofDiffEngine    → LsofDiff (added / removed / unchanged)
  → DataStore.apply() → SwiftUI re-renders
                      → AlertEngine.evaluate() → UNUserNotification (Pro)
```

---

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel
- Distributed **outside the Mac App Store** — requires no sandbox for `lsof` access

---

## Build

```bash
git clone https://github.com/Invernomut0/PortGuard.git
cd PortGuard
open PortGuard/PortGuard.xcodeproj
```

Run the core package tests:

```bash
cd PortGuard/PortGuardCore
swift test
```

---

## License

MIT — see [LICENSE](LICENSE).

Pro features are compiled into the same binary and gated by license key validation.

---

*Built and maintained by [@Invernomut0](https://github.com/Invernomut0).*
