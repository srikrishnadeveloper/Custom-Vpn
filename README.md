# NordVPN Auto-Connect: Zero-cost VPN for College Networks

Lightweight event-driven Windows system that auto-connects NordVPN when college Ethernet or WiFi network "SSN" is detected. Zero idle memory, DNS/IPv6 leak protection, no persistent processes.

---

## The Problem

College networks block gaming, streaming, and many websites. Running NordVPN's desktop app full-time wastes ~400MB RAM, fights with captive portals, and its kill switch sometimes leaks DNS. The official app also runs as a heavy Electron-based tray process that you have to manually connect/disconnect every time you plug in or switch networks.

## The Solution

An event-driven, zero-runtime-cost system:

- **No persistent process** — 0MB RAM when not on a college network
- **~14MB RAM** only when the OpenVPN process is active
- **Triggers via Windows Task Scheduler** on real network events (`Microsoft-Windows-NetworkProfile/Operational`, `Microsoft-Windows-WLAN-AutoConfig/Operational`)
- **Graceful cleanup** — disconnects VPN on unplug, leaves it connected on sleep/lock
- **5-minute watchdog** as a safety net for missed events
- **Lock file mechanism** — prevents concurrent OpenVPN instances across triggers

## Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│                    Windows Task Scheduler              │
│                                                       │
│  Event-Triggers                                       │
│  ┌────────────────┐  ┌──────────────────────────┐    │
│  │ Ethernet Plug   │  │ WiFi "SSN" connects      │    │
│  │ (Event ID 100)  │  │ (Event ID 11005)         │    │
│  └───────┬────────┘  └──────────┬───────────────┘    │
│          │                      │                      │
│  ┌───────▼────────┐  ┌──────────▼───────────────┐    │
│  │ on-network-    │  │ on-wifi-connect.cmd       │    │
│  │ connect.cmd    │  │ (checks SSID == "SSN")    │    │
│  └───────┬────────┘  └──────────┬───────────────┘    │
│          │                      │                      │
│  ┌───────▼──────────────────────▼───────────────┐    │
│  │           nord.ps1 us -tcp                    │    │
│  │  (acquires lock, spawns openvpn.exe,         │    │
│  │   waits for "Initialization Sequence")       │    │
│  └───────────────────────────────────────────────┘    │
│                                                       │
│  ┌────────────────┐  ┌──────────────────────────┐    │
│  │ Ethernet Unplug │  │ WiFi "SSN" disconnects   │    │
│  │ (Event ID 101)  │  │ (Event ID 11006)         │    │
│  └───────┬────────┘  └──────────┬───────────────┘    │
│          │                      │                      │
│  ┌───────▼────────┐  ┌──────────▼───────────────┐    │
│  │ on-network-    │  │ on-wifi-disconnect.cmd    │    │
│  │ disconnect.cmd │  │ (disconnects only if no   │    │
│  └───────┬────────┘  │  Ethernet/WiFi fallback)  │    │
│          │           └──────────┬───────────────┘    │
│          │                      │                      │
│  ┌───────▼──────────────────────▼───────────────┐    │
│  │           nord.ps1 disconnect                 │    │
│  │  (kills all openvpn.exe processes)            │    │
│  └───────────────────────────────────────────────┘    │
│                                                       │
│  Watchdog (Time Trigger, every 5 min)                 │
│  ┌───────────────────────────────────────────────┐    │
│  │ watchdog.cmd                                   │    │
│  │ "If on Ethernet/SSN and VPN not running,       │    │
│  │  connect. Otherwise do nothing."               │    │
│  └───────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

### Scheduled Tasks

| Task Name | Trigger | Action |
|---|---|---|
| `NordVPN-Ethernet-Connect` | Event ID 100 (profile connected) | `on-network-connect.cmd` → `nord.ps1 us -tcp` |
| `NordVPN-Ethernet-Disconnect` | Event ID 101 (profile disconnected) | `on-network-disconnect.cmd` → `nord.ps1 disconnect` |
| `NordVPN-WiFi-Connect` | Event ID 11005 (SSID "SSN" connected) | `on-wifi-connect.cmd` → `nord.ps1 us -tcp` |
| `NordVPN-WiFi-Disconnect` | Event ID 11006 (SSID "SSN" disconnected) | `on-wifi-disconnect.cmd` → `nord.ps1 disconnect` |
| `NordVPN-Watchdog` | Every 5 minutes | `watchdog.cmd` — connects if needed |

### OpenVPN Configs

40 config files (20 countries × UDP + TCP) stored in `%USERPROFILE%\.nordvpn\configs\`. Each config includes:

- `block-outside-dns` — prevents DNS leaks beyond the VPN tunnel
- `auth-user-pass` — reads credentials from `auth.txt`
- TLS authentication with static key
- SHA512 auth, AES-256-CBC cipher
- TCP fallback on port 1231-1234 (college networks often block UDP)

### Leak Prevention

- **IPv6 disabled** on Ethernet and WiFi adapters via `Disable-NetAdapterBinding -ComponentID ms_tcpip6`
- **block-outside-dns** directive in every `.ovpn` config — Windows DNS traffic is forced through the TAP adapter
- **Route kill** via OpenVPN's default route push (all IPv4 traffic through tunnel)
- **Connection validation** — nord.ps1 waits for `Initialization Sequence Completed` in the OpenVPN log before reporting success

---

## Quick Start

### 1. Install OpenVPN Community Edition

Download from [openvpn.net/community-downloads/](https://openvpn.net/community-downloads/). Use the default install path (`C:\Program Files\OpenVPN\`).

### 2. Save Your NordVPN Credentials

Get your service credentials from [NordAccount](https://my.nordaccount.com) > Services > NordVPN > Manual setup.

Create `%USERPROFILE%\.nordvpn\auth.txt`:

```
your_nordvpn_username
your_nordvpn_password
```

### 3. Enable Auto-Connect

```cmd
nord monitor enable
```

This enables all 4 event-triggered scheduled tasks. From now on, plugging in college Ethernet or connecting to WiFi "SSN" will automatically start NordVPN (US-TCP). Unplugging or leaving the network disconnects.

---

## Usage

```cmd
nord <command>
```

### Commands

| Command | Description |
|---|---|
| `nord status` | Show connection state and public IP |
| `nord us -tcp` | Connect to US server via TCP (recommended for college) |
| `nord us` | Connect to US server via UDP |
| `nord de` | Connect to Germany (replace with any country code) |
| `nord list` | List all available configs |
| `nord disconnect` | Kill all OpenVPN processes |
| `nord health` | Run comprehensive diagnostics (6 checks) |
| `nord reconnect` | Reconnect to the last-used server |
| `nord monitor enable` | Enable all auto-connect scheduled tasks |
| `nord monitor disable` | Disable all auto-connect scheduled tasks |
| `nord monitor` | Show whether auto-connect is active |

### Country Configs

20 countries available: `au`, `br`, `ca`, `ch`, `de`, `es`, `fr`, `hk`, `in`, `it`, `jp`, `kr`, `nl`, `no`, `nz`, `se`, `sg`, `uk`, `us`, `za`

Append `-tcp` for TCP mode (e.g. `nord jp -tcp`). TCP is recommended on college networks where UDP is often rate-limited or blocked.

---

## Key Features

- **Auto-connect on Ethernet plug** — plug in dorm Ethernet, VPN starts within seconds
- **Auto-connect on WiFi "SSN"** — join the college WiFi, VPN starts automatically
- **Auto-disconnect on unplug** — unplug Ethernet or leave SSN range, VPN cleans up
- **Survives reboot, sleep, lock** — triggered by real network events, not user session
- **SSID-aware WiFi disconnect** — won't disconnect if you just switched to another WiFi; only disconnects when SSN is truly gone and no Ethernet fallback exists
- **5-minute watchdog** — safety net if an event is missed (rare with Task Scheduler, but covered)
- **Lock file prevents duplicates** — `~/.nordvpn/.nord.lock` with PID validation prevents race conditions between simultaneous triggers
- **Connection validation** — waits up to 45 seconds for `Initialization Sequence Completed` before returning
- **Auth failure detection** — reads log in real-time, detects `AUTH_FAILED` immediately
- **Health check** — `nord health` runs 6 tests: process running, internet reachable, DNS via 103.86.96.100, IPv6 disabled, VPN routes present, lock file valid

---

## Network Flow

```
┌──────────┐     ┌────────────┐     ┌─────────────┐     ┌──────────────┐
│  College  │────▶│ Physical   │────▶│ OpenVPN TAP │────▶│ NordVPN      │
│  Network  │     │ Adapter    │     │ Adapter      │     │ Server       │
│  (SSN /   │     │ (Ethernet  │     │ (10.8.0.x)   │     │ (US TCP)     │
│  Ethernet)│     │  or WiFi)  │     │              │     │              │
└──────────┘     └────────────┘     └─────────────┘     └──────────────┘
                       │                                      │
                  IPv6 Disabled                          DNS: 103.86.96.100
                  (ms_tcpip6 unbound)                    block-outside-dns

    All traffic: Physical Adapter ──▶ TAP Adapter ──▶ NordVPN Server ──▶ Internet
    DNS queries: TAP adapter only, never touch college DNS servers
    Leaks: IPv6 disabled at adapter level + DNS forced via block-outside-dns
```

---

## Known Limitations

- **krunker.io** — blocks all shared VPN datacenter IPs. Returns HTTP 403 regardless of server or protocol. This is a site-level block, not fixable with any VPN.
- **chatgpt.com** — also blocks NordVPN IP ranges via datacenter IP detection. Returns HTTP 403.
- These are not NordVPN issues or configuration issues — these websites actively block all known VPN/cloud provider IP ranges.

---

## File Structure

```
Wi-Fi/
├── README.md                          # This document
├── scripts/
│   ├── nord.ps1                       # Core PowerShell script: connect, disconnect, status,
│   │                                  # health check, reconnect, list, lock management
│   ├── nord.cmd                       # CLI entry point (`nord <command>`), also handles
│   │                                  # `nord monitor enable/disable/status`
│   ├── on-network-connect.cmd         # Ethernet plug trigger — starts VPN if not running
│   ├── on-network-disconnect.cmd      # Ethernet unplug trigger — disconnects VPN only if
│   │                                  # no other network (WiFi/Ethernet) is active
│   ├── on-wifi-connect.cmd            # WiFi connect trigger — checks SSID == "SSN",
│   │                                  # starts VPN if match
│   ├── on-wifi-disconnect.cmd         # WiFi disconnect trigger — disconnects from SSN,
│   │                                  # checks Ethernet fallback before killing VPN
│   ├── watchdog.cmd                   # 5-min safety net — connects if on SSN/Ethernet
│   │                                  # but VPN is not running
│   ├── us-tcp.ovpn                    # Sample config (US-TCP). All 40 configs deployed
│   │                                  # to %USERPROFILE%\.nordvpn\configs\
│   └── auth.txt                       # NordVPN service credentials (REPLACE WITH YOURS)
└── docs/                              # Reserved for future documentation
```

### Deployed Runtime Structure (`%USERPROFILE%\.nordvpn\`)

```
~\.nordvpn\
├── nord.ps1                           # Core script
├── nord.cmd                           # CLI wrapper (add to PATH)
├── auth.txt                           # Your NordVPN credentials
├── configs\
│   ├── us.ovpn, us-tcp.ovpn          # 40 country configs (20 × UDP + TCP)
│   ├── de.ovpn, de-tcp.ovpn
│   └── ... (20 countries)
├── scripts\
│   ├── connect.log                    # Ethernet connect trigger log
│   ├── disconnect.log                 # Ethernet disconnect trigger log
│   ├── wifi-connect.log               # WiFi connect trigger log
│   ├── wifi-disconnect.log            # WiFi disconnect trigger log
│   └── watchdog.log                   # Watchdog trigger log
├── .nord.lock                         # PID lock file (prevents concurrent VPN spawns)
└── .nord.last                         # Last-connected server (used by `nord reconnect`)
```

### Scheduled Task Registration

The scheduled tasks are registered manually (or via a setup script) pointing to `%USERPROFILE%\.nordvpn\scripts\*.cmd`. Each task runs as the current user, triggered only when the user is logged in, with highest privileges.

---

## Zero-Cost Guarantee

| Scenario | RAM Used | Processes |
|---|---|---|
| Not on college network | 0 MB | 0 |
| On SSN/Ethernet, connected | ~14 MB | 1 (`openvpn.exe`) |
| NordVPN desktop app equivalent | ~400 MB | ~5 (Electron, tray, service, etc.) |
# Custom-Vpn
