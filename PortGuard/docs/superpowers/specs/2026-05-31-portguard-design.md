# PortGuard — Design Spec

> macOS menubar app for developer network observability. Open-core: free OSS + Pro €15 one-time.

## Context

PortGuard gives developers real-time visibility into active processes, open ports, and outbound connections — without opening a terminal. Built outside the MAS (Developer ID + notarization) because `lsof`/`nettop` and system-wide process reading are incompatible with the MAS sandbox.

**Language:** All code, comments, commit messages, documentation, and UI strings are in English.

---

## Architecture

Stack: SwiftUI App protocol, `LSUIElement = YES` (no Dock icon), `PortGuardCore` Swift Package for pure testable logic.

```
PortGuardApp
├── MenuBarManager          — NSStatusItem + NSPopover
├── DataEngine
│   ├── LsofPoller          — spawn lsof -i -n -P, parse, diff
│   ├── ProcessMonitor      — NSWorkspace notifications
│   └── DataStore           — @Observable, single source of truth
├── AlertEngine (Pro)       — rule evaluation → UNUserNotificationCenter
├── HistoryStore (Pro)      — SQLite via GRDB, append-only snapshots
└── LicenseManager          — Gumroad license key API, local validation
```

No special entitlements. Developer ID + notarization + Sparkle 2.

## Data Flow

1. `LsofPoller` runs every N seconds (user-configurable), produces `LsofDiff` (added/removed/changed)
2. `ProcessMonitor` listens to NSWorkspace for instant launch/quit events
3. `DataStore` (`@Observable`) merges and notifies SwiftUI
4. `AlertEngine` (Pro) evaluates rules against `LsofDiff` → native notifications

## Repository Structure

```
PortGuard/
├── PortGuard/                        — main Xcode target (SwiftUI)
│   ├── App/
│   │   ├── PortGuardApp.swift        — App entry point, LSUIElement
│   │   └── AppDelegate.swift
│   ├── MenuBar/
│   │   ├── MenuBarManager.swift      — NSStatusItem, NSPopover lifecycle
│   │   └── StatusItemView.swift      — SwiftUI view for status item
│   ├── UI/
│   │   ├── PopoverRootView.swift     — 3-tab container + search bar
│   │   ├── ProcessesTabView.swift
│   │   ├── PortsTabView.swift
│   │   ├── ConnectionsTabView.swift
│   │   ├── QuickLookupView.swift     — global floating overlay
│   │   └── SettingsView.swift
│   ├── Pro/
│   │   ├── AlertEngine.swift
│   │   ├── AlertRuleBuilderView.swift
│   │   ├── HistoryStore.swift
│   │   └── ExportManager.swift
│   └── License/
│       ├── LicenseManager.swift
│       └── LicenseActivationView.swift
├── PortGuardCore/                    — Swift Package, pure logic
│   ├── Package.swift
│   ├── Sources/PortGuardCore/
│   │   ├── Models.swift              — ConnectionRecord, PortRecord, ProcessRecord, LsofDiff
│   │   ├── LsofPoller.swift          — spawn + parse + diff
│   │   ├── ProcessMonitor.swift      — NSWorkspace observer
│   │   └── DataStore.swift           — @Observable, merges all sources
│   └── Tests/PortGuardCoreTests/
│       ├── LsofParserTests.swift
│       ├── DiffEngineTests.swift
│       └── DataStoreTests.swift
├── PortGuardTests/                   — UI/integration tests
└── docs/
    ├── superpowers/
    │   ├── specs/
    │   └── plans/
    └── index.html                    — landing page
```

## UI/UX

**Menubar icon:** connection count badge; turns amber/red when Pro alerts fire.

**Popover (400×520pt):**
- Always-visible `SearchBar` at top — filters all three tabs simultaneously
- Tabs: **Processes** | **Ports** | **Connections**
- Footer: `RefreshIntervalPicker` (1s/2s/5s/10s/30s/custom) + `Alert Rules` button (Pro) + `Export` button (Pro)

**Processes tab:** list of processes with ≥1 active connection. Columns: icon, name, PID, connection count. Sortable. Click row → expands inline to show all connections for that process.

**Ports tab:** ports in LISTEN state. Columns: port, protocol, process name, PID. Unsigned-process rows show a warning badge (validated via `SecStaticCodeRef`).

**Connections tab:** ESTABLISHED outbound connections. Columns: process, local port, remote host (lazy reverse DNS), remote port, state. Bytes column populated from `nettop` when available.

**Quick Lookup (⌥⌘P):** global floating panel (like Spotlight), filters across all data in real-time, dismissed with Escape.

**Settings:** refresh interval, global shortcut (recorder), login item toggle, license key entry, About.

## Free vs Pro

**Free (MIT):** all three tabs, configurable refresh, in-popover search, Quick Lookup global shortcut.

**Pro (€15 one-time, perpetual):**
- **Custom alerts** *(v1 priority)*: visual rule builder, `AlertEngine` evaluates on each `LsofDiff`, fires `UNUserNotification`
- **Persistent history**: GRDB SQLite, snapshot every N minutes, timeline slider in popover
- **Export**: CSV/JSON snapshot from context menu

## Licensing

Gumroad license key API. Local validation: HMAC of key + device fingerprint (IOPlatformUUID). No server required for v1. Graceful degradation: Pro features locked, no crash.

## Distribution

- GitHub Releases: signed + notarized DMG
- Sparkle 2: appcast hosted on GitHub Pages
- Website: `docs/index.html` deployed to GitHub Pages
