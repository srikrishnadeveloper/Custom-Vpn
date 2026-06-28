# NordVPN Auto-Connect — Architecture

## Event Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EVENT FLOW                                         │
│                                                                             │
│  Ethernet Plugged    ──►  Windows Event ID 10000 (Type=0)                   │
│  WiFi Connected      ──►  Windows Event ID 10000 (Type=1)                   │
│  Network Disconnect  ──►  Windows Event ID 10001 (Type=0/1)                 │
│                                                                             │
│       │                                                                     │
│       ▼                                                                     │
│  Task Scheduler  ──►  NordVPN-Ethernet-Connect (Type=0)                     │
│                    ──►  NordVPN-WiFi-Connect    (Type=1)                     │
│                    ──►  NordVPN-Ethernet-Disconnect (Type=0)                 │
│                    ──►  NordVPN-WiFi-Disconnect  (Type=1)                    │
│                    ──►  NordVPN-Watchdog        (Every 5 min)                │
│       │                                                                     │
│       ▼                                                                     │
│  on-network-connect.cmd  ──►  nord.ps1 us -tcp                              │
│  on-wifi-connect.cmd     ──►  nord.ps1 us -tcp  (SSID=SSN)                  │
│  on-network-disconnect.cmd  ──►  nord.ps1 disconnect                        │
│  on-wifi-disconnect.cmd  ──►  nord.ps1 disconnect  (SSID=SSN)               │
│  watchdog.cmd            ──►  nord.ps1 us -tcp  (if down)                   │
│       │                                                                     │
│       ▼                                                                     │
│  nord.ps1  ──►  Acquire-Lock                                                │
│              ──►  Kill existing OpenVPN                                      │
│              ──►  Start OpenVPN (hidden, TCP port 1231-1234)                 │
│              ──►  Wait for "Initialization Sequence Completed"               │
│              ──►  Routes: 0.0.0.0/1 + 128.0.0.0/1 via TAP                    │
│              ──►  DNS: 103.86.96.100, 103.86.99.101                          │
│              ──►  Release-Lock                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Scheduled Tasks

| Task Name | Trigger(s) | Action | Run As | Settings |
|---|---|---|---|---|
| `NordVPN-Ethernet-Connect` | Boot (30s delay), SessionUnlock, Event 10000 Type=0 | `on-network-connect.cmd` | Current user | Parallel, StartWhenAvailable |
| `NordVPN-WiFi-Connect` | Boot (30s delay), SessionUnlock, Event 10000 Type=1 | `on-wifi-connect.cmd` | Current user | Parallel, StartWhenAvailable |
| `NordVPN-Ethernet-Disconnect` | Event 10001 Type=0 | `on-network-disconnect.cmd` | Current user | Parallel, StartWhenAvailable |
| `NordVPN-WiFi-Disconnect` | Event 10001 Type=1 | `on-wifi-disconnect.cmd` | Current user | Parallel, StartWhenAvailable |
| `NordVPN-Watchdog` | Every 5 min, indefinite repetition | `watchdog.cmd` | Current user | Parallel, StartWhenAvailable |

## nord.ps1 Architecture

### Lock Mechanism

```
Acquire-Lock
  │
  ├── Clean-StaleLock
  │     ├── Read PID from ~\.nordvpn\.nord.lock
  │     ├── If PID doesn't match a running powershell/pwsh process → delete lock
  │     └── If file is empty/non-numeric → delete lock
  │
  └── Retry loop (5 attempts, 200ms delay)
        ├── Open lock file with FileShare.None (exclusive write)
        ├── Write current PID to lock file
        └── On conflict:
              ├── Read existing PID
              ├── If existing PID is a valid powershell/pwsh → warn "Already running" and exit
              └── Else → delete stale lock and retry

Release-Lock
  ├── Verify lock file contains our PID
  └── Delete lock file
```

### Connect Flow

```
nord.ps1 <country> [-tcp]
  │
  ├── Validate action parameter (alphanumeric + hyphens only)
  ├── Read auth.txt (line 1 = username, line 2 = password)
  ├── Validate auth.txt — reject placeholder values and missing fields
  ├── Locate .ovpn config at ~\.nordvpn\configs\<country>[-tcp].ovpn
  ├── Locate openvpn.exe (checked paths):
  │     ├── C:\Program Files\OpenVPN\bin\openvpn.exe
  │     ├── C:\Program Files\OpenVPN Connect\openvpn.exe
  │     ├── ~\AppData\Local\OpenVPN\bin\openvpn.exe
  │     └── PATH fallback
  │
  ├── Acquire-Lock  (returns false if already running)
  ├── Disconnect-VPN (kill all existing OpenVPN processes)
  ├── Start OpenVPN hidden (WindowStyle.Hidden, CreateNoWindow)
  │     └── --config <file> --auth-user-pass <authfile> --log <file> --auth-nocache
  │
  └── Poll log file for status (1s intervals, 45s timeout):
        ├── "Initialization Sequence Completed" → success
        ├── "AUTH_FAILED" → kill process, print error
        ├── "FATAL:" / "Exiting due to fatal error" → kill process
        └── Timeout → print last 3 log lines, kill process
```

### Disconnect

```
Disconnect-VPN
  └── Get-Process -Name "openvpn" | ForEach-Object Kill()
```

### Health Checks (8 total)

| # | Check | Method | Pass Criteria |
|---|---|---|---|
| 1 | Process | `Get-Process -Name "openvpn"` | OpenVPN process is running |
| 2 | Internet | HTTP GET to ipify.org, google.com, cloudflare.com | At least one returns 200 |
| 3 | DNS | `Get-DnsClientServerAddress` on TAP/Nord adapter | `103.86.96.100` present |
| 4 | IPv6 | `Get-NetAdapterBinding -ComponentID ms_tcpip6` | IPv6 disabled on Ethernet/WiFi |
| 5 | Routes | `Get-NetRoute 0.0.0.0/1` and `128.0.0.0/1` | Both routes via TAP adapter |
| 6 | Lock | Validate PID in lock file matches running process | Lock file is valid |
| 7 | krunker.io | `curl.exe` GET with 8s timeout | HTTP 200 or 403 |
| 8 | chatgpt.com | `curl.exe` GET with 8s timeout | HTTP 200 or 403 |

### Reconnect

```
Save-LastServer → writes JSON to ~\.nordvpn\.nord.last
  { "server": "us", "tcp": true }

Load-LastServer → reads JSON from ~\.nordvpn\.nord.last

nord reconnect
  ├── Load last server from .nord.last
  ├── Disconnect-VPN
  ├── Sleep 2s
  └── Connect to saved server with saved protocol
```

## Network Stack

### Routing

All traffic is redirected through the TAP adapter using two complementary default routes:

- `0.0.0.0/1` via TAP (covers 0.0.0.0–127.255.255.255)
- `128.0.0.0/1` via TAP (covers 128.0.0.0–255.255.255.255)

Both routes have metric 0, ensuring VPN routes take priority over physical adapter defaults.

Push from OpenVPN server: `redirect-gateway def1` which creates these two `/1` routes instead of a single `0.0.0.0/0` to avoid overwriting the physical adapter's default gateway.

### DNS

- TAP adapter DNS servers: `103.86.96.100` (primary), `103.86.99.101` (secondary) — NordVPN's non-logging DNS resolvers
- `block-outside-dns` directive in `.ovpn` config — blocks all DNS queries not directed at the TAP adapter on Windows
- Prevents DNS leaks even if an application bypasses the VPN interface

### IPv6

- IPv6 is **disabled** on physical Ethernet and Wi-Fi adapters via `Disable-NetAdapterBinding -ComponentID ms_tcpip6`
- Prevents IPv6 traffic from leaking outside the VPN tunnel (OpenVPN routes IPv4 only)
- TAP adapter retains IPv6 disabled by default

### Protocol

- **TCP** on ports **1231–1234** (with `remote-random` for load balancing)
- UDP is blocked on the college network; TCP is the only reliable transport
- OpenVPN falls back across the four port entries on connection failure

## Script Architecture

### nord.ps1 (Main)

| Aspect | Detail |
|---|---|
| Path | `~\.nordvpn\nord.ps1` |
| Purpose | Core VPN management — connect, disconnect, status, health, reconnect, list, monitor |
| Arguments | `<action> [tcp]` — action is a country code, `disconnect`, `status`, `health`, `reconnect`, `list`, or `monitor` |
| Configs location | `~\.nordvpn\configs\*.ovpn` (40 `.ovpn` files, 2 variants each: UDP + TCP) |
| Logs | `~\.nordvpn\<country>[-tcp].log` |
| Lock file | `~\.nordvpn\.nord.lock` (hidden, contains PID) |
| Last server | `~\.nordvpn\.nord.last` (hidden, JSON) |
| Auth file | `~\.nordvpn\auth.txt` (line 1 = username, line 2 = password) |

### nord.cmd (CLI Wrapper)

| Aspect | Detail |
|---|---|
| Path | `C:\Windows\nord.cmd` |
| Purpose | Provides `nord` command from any terminal |
| Structure | Batch `goto` dispatch |
| Special commands | `nord monitor` — checks task enabled status; `nord monitor enable` / `nord monitor disable` — toggles scheduled tasks |
| Passthrough | All other args forwarded to `powershell.exe -File nord.ps1 <args>` |

### on-network-connect.cmd

| Aspect | Detail |
|---|---|
| Path | `C:\Users\<user>\.nordvpn\scripts\on-network-connect.cmd` |
| Trigger | Task Scheduler on Ethernet connect (Event 10000 Type=0) |
| Logic | Checks: (1) Is any Ethernet adapter up? (2) Is OpenVPN already running? If Ethernet is up and VPN is down, calls `nord.ps1 us -tcp` |
| Log | `~\.nordvpn\scripts\connect.log` |

### on-wifi-connect.cmd

| Aspect | Detail |
|---|---|
| Path | `C:\Users\<user>\.nordvpn\scripts\on-wifi-connect.cmd` |
| Trigger | Task Scheduler on WiFi connect (Event 10000 Type=1) |
| Logic | Parses `netsh wlan show interfaces` for SSID; if SSID matches `SSN` and OpenVPN is not running, calls `nord.ps1 us -tcp` |
| Log | `~\.nordvpn\scripts\wifi-connect.log` |

### on-network-disconnect.cmd

| Aspect | Detail |
|---|---|
| Path | `C:\Users\<user>\.nordvpn\scripts\on-network-disconnect.cmd` |
| Trigger | Event 10001 Type=0 |
| Logic | If Ethernet is up → exit (spurious trigger); if WiFi is up → exit (still have connectivity); otherwise → call `nord.ps1 disconnect` |
| Log | `~\.nordvpn\scripts\disconnect.log` |

### on-wifi-disconnect.cmd

| Aspect | Detail |
|---|---|
| Path | `C:\Users\<user>\.nordvpn\scripts\on-wifi-disconnect.cmd` |
| Trigger | Event 10001 Type=1 |
| Logic | Reads SSID from `netsh wlan show interfaces`. If SSID matches `SSN` → disconnect VPN. If no SSID found (WiFi fully down) → check Ethernet fallback; if no Ethernet → disconnect VPN. Non-matching SSID → leave VPN connected. |
| Log | `~\.nordvpn\scripts\wifi-disconnect.log` |

### watchdog.cmd

| Aspect | Detail |
|---|---|
| Path | `C:\Users\<user>\.nordvpn\scripts\watchdog.cmd` |
| Trigger | Task Scheduler every 5 minutes |
| Logic | Checks: (1) Is Ethernet up OR WiFi connected to `SSN`? (2) Is OpenVPN running? If connected to a known network but VPN is down → reconnect with `nord.ps1 us -tcp` |
| Log | `~\.nordvpn\scripts\watchdog.log` |

## Security

### Credential Storage

- Credentials stored in `~\.nordvpn\auth.txt` — **NordVPN service credentials** (username/password from NordAccount manual setup), **not** email/password
- File format: line 1 = username (32-char alphanumeric), line 2 = password (32-char mixed case)
- `auth-nocache` flag passed to OpenVPN — prevents OpenVPN from caching credentials in memory after authentication

### OpenVPN Configuration

- 40 server configs (20 countries × TCP/UDP) in `~\.nordvpn\configs\`
- All configs include `block-outside-dns` to prevent DNS leaks
- TLS authentication with `tls-auth` static key (pre-shared key required before TLS handshake)
- `remote-cert-tls server` — strict server certificate verification
- `verify-x509-name` — pins connection to a specific server certificate CN
- `auth SHA512` — HMAC digest algorithm
- `cipher AES-256-CBC` — data channel encryption

### What is NOT stored in the repository

- No NordVPN credentials or auth.txt
- No `.nord.lock` or `.nord.last` files (user-local runtime state)
- No OpenVPN log files
- No private keys or certificates (CA cert is bundled in `.ovpn`; it's public)

### Notes

- Lock file contains only a PID (numeric, newline-terminated) — no secrets
- Log files contain OpenVPN connection output only — no credentials logged
- All scripts run as the current user (no SYSTEM elevation for the VPN process)
