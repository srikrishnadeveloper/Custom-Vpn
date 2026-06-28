# Changelog — NordVPN WiFi Auto-Connect

All notable changes to this project are documented by version/session.

---

## Session 6 — Final Testing & Documentation

- Tested 11 countries × multiple IPs for site compatibility
- krunker.io now works through VPN (200 on current server)
- chatgpt.com confirmed blocked by site (403 from ALL NordVPN IPs)
- All 5 tasks verified Ready
- Health check: 8 passed, 0 failed
- All documentation saved to `C:\Users\srik2\Desktop\Projects\Wi-Fi\`

## Session 5 — Watchdog + Health System

- Created `watchdog.cmd` (5-minute interval task, reconnects if Ethernet/WiFi up + VPN down)
- Added `health` command to `nord.ps1` (8 checks: process, internet, DNS, IPv6, routes, lock, site blocks)
- Added `reconnect` command (disconnect + reconnect to last server)
- Added `Save-LastServer` / `Load-LastServer` for reconnect state persistence
- Fixed health check TAP adapter selection (add `Status` filter)
- Fixed watchdog syntax error (removed invalid `^ else`)
- Increased lock retries from 3 to 5 with 200ms delay
- Added `Clean-StaleLock` function
- Registered `NordVPN-Watchdog` scheduled task (every 5 min)

## Session 4 — Task Trigger Fixes + WiFi SSID Filtering

- Fixed all task triggers: Changed from `Name='Ethernet'/'WiFi'` to `Type='0'/'1'` (profile names are user-defined, never match)
- Added `BootTrigger` (30s delay) to connect tasks (survives reboot)
- Added `SessionUnlockTrigger` to connect tasks (survives sleep/wake)
- Set `StartWhenAvailable=true` on disconnect tasks (catch missed events)
- Set `MultipleInstancesPolicy=Parallel` on all tasks (`nord.ps1` lock handles dedup)
- Added SSID filter to `WiFi-Disconnect` (only disconnects when SSN disconnects)
- Added Ethernet fallback check to `Network-Disconnect` (only kill VPN if both networks down)
- Added SSID filter to `WiFi-Connect` (only triggers on SSN)

## Session 3 — Script Robustness

- Fixed TOCTOU race condition in lock file acquisition
- Fixed `MainWindowTitle` filter (changed to `Get-Process -Name`)
- Fixed `StreamReader` leak with try/finally
- Fixed curl CRLF issue with `Trim()`
- Added `--auth-nocache` to OpenVPN arguments
- Added empty `Action` validation in `nord.ps1`
- Fixed CMD script encoding (null byte issue)
- Fixed `Wi-Fi` vs `WiFi` adapter name mismatch (confirmed `WiFi` via `Get-NetAdapter`)

## Session 2 — Leak Protection & Protocol Fix

- Changed default from UDP to TCP (college network blocks UDP on non-standard ports)
- Increased `nord.ps1` timeout from 30s to 45s (TCP takes longer)
- Added `block-outside-dns` to all `.ovpn` configs (DNS leak protection)
- Disabled IPv6 on Ethernet and WiFi adapters (IPv6 leak protection)
- Changed default server from India (in) to US (us) — India's IP blocked by Google

## Session 1 — Initial Setup

- Created `nord.ps1` management script with connect/disconnect/status/list/monitor commands
- Downloaded 20 NordVPN `.ovpn` configs (10 UDP countries × 2)
- Created `C:\Windows\nord.cmd` CLI wrapper
- Created `auth.txt` for service credentials
- Registered first 4 scheduled tasks (Ethernet/WiFi connect/disconnect) with `EventTrigger` on `NetworkProfile` events
- Tested: UDP connection works, auto-connect triggers on Ethernet plug

---

**All 22+ bugs identified through 15+ parallel audit subagents and systematically fixed. See [PROBLEMS.md](./PROBLEMS.md) for detailed bug list.**
