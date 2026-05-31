---
title: "PortGuard Pro"
subtitle: "Thank you for your purchase"
geometry: margin=2.5cm
fontsize: 12pt
linestretch: 1.5
colorlinks: true
linkcolor: "0a84ff"
---

# Welcome to PortGuard Pro

Thank you for purchasing PortGuard Pro. This document contains everything you need to activate your license and get started.

---

## Download PortGuard

If you haven't already, download the latest version from GitHub Releases:

**https://github.com/lorenzov/portguard/releases/latest**

1. Download `PortGuard.dmg`
2. Open the DMG and drag PortGuard to your Applications folder
3. Launch PortGuard — it will appear in your menubar

> **First launch:** macOS may show a Gatekeeper warning. Go to **System Settings → Privacy & Security** and click "Open Anyway".

---

## Activate Your License

1. **Right-click** the PortGuard icon in your menubar
2. Select **Settings…**
3. Find the **License** section
4. Paste your license key into the text field
5. Click **Activate**

Your license key is included in the purchase confirmation email from Gumroad. It looks like: `XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX`

Once activated, you will see **"Pro — activated"** with a green checkmark.

> Your license key is stored securely in macOS Keychain. You only need to activate once — Pro features remain enabled even when offline.

---

## Pro Features

### Custom Alert Rules

Get notified when something changes on your network:

1. Click the **bell icon** (🔔) in the popover footer
2. Click **+** to add a new rule
3. Choose a trigger:
   - **Port opened** — notify when a specific port starts listening
   - **Port closed** — notify when a port stops listening
   - **New outbound connection** — notify when a process connects out
   - **Process connected** — notify when a specific app makes any connection
4. Optionally filter by port number or process name
5. Click **Add**

Rules fire native macOS notifications and are saved across restarts.

### Persistent History

PortGuard snapshots your connections every 5 minutes and stores them locally in `~/Library/Application Support/PortGuard/history.json`. Use this to investigate what was running and connecting hours ago.

### Export

Click the **export icon** (↑) in the popover footer to save a snapshot of all current connections as:

- **CSV** — open in Numbers, Excel, or any spreadsheet app
- **JSON** — use with scripts, jq, or any data tool

---

## Quick Lookup

Press **⌥⌘P** (Option + Command + P) from anywhere on your Mac to open a floating search overlay. Type a port number or process name to find it instantly. Press **Escape** to dismiss.

---

## System Requirements

- macOS 14 Ventura or later
- Apple Silicon or Intel Mac
- Distributed outside the Mac App Store (no sandbox — required for `lsof` access)

---

## Support

If you have questions, found a bug, or want to request a feature:

- **GitHub Issues:** https://github.com/lorenzov/portguard/issues
- **Email:** lorenzo@portguard.app

Your license key is valid for the current major version and all future updates. No subscription, no expiry.

---

*PortGuard is built and maintained independently. Thank you for supporting indie Mac development.*
