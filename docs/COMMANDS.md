# NordVPN Auto-Connect — Command Reference

## nord.ps1 / nord.cmd Commands

| Command | Description | Example |
|---|---|---|
| `nord <country>` | Connect to a country server (auto UDP) | `nord us` |
| `nord <country> -tcp` | Connect using TCP protocol | `nord us -tcp` |
| `nord disconnect` | Disconnect VPN | `nord disconnect` |
| `nord status` | Show connection status + IP | `nord status` |
| `nord list` | List available countries | `nord list` |
| `nord health` | Full 8-point health check | `nord health` |
| `nord reconnect` | Disconnect + reconnect to last server | `nord reconnect` |
| `nord monitor` | Show monitor status | `nord monitor` |
| `nord monitor enable` | Enable all 5 auto tasks | `nord monitor enable` |
| `nord monitor disable` | Disable all 5 auto tasks | `nord monitor disable` |

## Scheduled Tasks

| Task | Trigger | Action |
|---|---|---|
| NordVPN-Ethernet-Connect | Boot + SessionUnlock + Event 10000 Type=0 | on-network-connect.cmd |
| NordVPN-WiFi-Connect | Boot + SessionUnlock + Event 10000 Type=1 | on-wifi-connect.cmd |
| NordVPN-Ethernet-Disconnect | Event 10001 Type=0 | on-network-disconnect.cmd |
| NordVPN-WiFi-Disconnect | Event 10001 Type=1 | on-wifi-disconnect.cmd |
| NordVPN-Watchdog | Every 5 minutes | watchdog.cmd |

## Task Management Commands

```powershell
# Enable/disable individual tasks
schtasks /change /tn "NordVPN-Ethernet-Connect" /enable
schtasks /change /tn "NordVPN-Ethernet-Connect" /disable

# Run task manually
schtasks /run /tn "NordVPN-Ethernet-Connect"

# View task details
schtasks /query /tn "NordVPN-Ethernet-Connect" /fo list /v
```

## Log Files

| Log | Location | Contents |
|---|---|---|
| Connect | ~\.nordvpn\scripts\connect.log | Ethernet connect events |
| WiFi Connect | ~\.nordvpn\scripts\wifi-connect.log | WiFi connect events with SSID |
| Disconnect | ~\.nordvpn\scripts\disconnect.log | Ethernet disconnect events |
| WiFi Disconnect | ~\.nordvpn\scripts\wifi-disconnect.log | WiFi disconnect events |
| Watchdog | ~\.nordvpn\scripts\watchdog.log | Watchdog runs |
| OpenVPN | ~\.nordvpn\<country>-tcp.log | OpenVPN connection log |

## Health Check Output Legend

- `[PASS]` — Everything is working correctly
- `[FAIL]` — Something is broken
- `[WARN]` — Site-specific block (not a system issue)
