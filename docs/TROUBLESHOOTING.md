# Troubleshooting

## Connection Issues

| Symptom | Likely Cause | Check This | Fix |
|---|---|---|---|
| "OpenVPN not found" | OpenVPN not installed | Check `C:\Program Files\OpenVPN\bin\openvpn.exe` | Install from [openvpn.net](https://openvpn.net) |
| "auth.txt must have username/password" | Missing or wrong credentials | Check `auth.txt` has 2 lines | Get service creds from [nordaccount.com](https://nordaccount.com) |
| "No config for X" | Config file missing | Check `configs/` folder | Copy `.ovpn` files |
| "Already running" | Another nord.ps1 instance | Check lock file: `~/.nordvpn/.nord.lock` | Wait or kill stale process |
| VPN connects but no internet | DNS leak or routing issue | Run `nord health` | Check `block-outside-dns`, IPv6 disabled |
| VPN won't connect via UDP | College blocks UDP | Check `connect.log` for timeout | Use TCP: `nord us -tcp` |
| Connection hangs at 45s | Server unreachable or auth failure | Check `<country>.log` in `~/.nordvpn` | Try different server |

## Auto-Connect Issues

| Symptom | Likely Cause | Check This | Fix |
|---|---|---|---|
| VPN doesn't auto-connect on Ethernet plug | Task not registered | `schtasks /query /tn NordVPN*` | Run `nord monitor enable` |
| VPN doesn't auto-connect after reboot | BootTrigger failed | Check task triggers | Re-register tasks |
| VPN connects but wrong SSID | WiFi script needs config | Check `on-wifi-connect.cmd` line 4 | Change `TARGET_SSID` to your college WiFi |
| VPN keeps disconnecting | Disconnect task too aggressive | Check `connect.log` | Update SSID filter in `on-wifi-disconnect.cmd` |

## Health Check Failures

| Failure | Meaning | Fix |
|---|---|---|
| OpenVPN process not running | VPN is down | `nord us -tcp` |
| Internet not reachable | No internet at all | Check physical connection |
| DNS not using NordVPN | DNS leak | Check `block-outside-dns` in `.ovpn` |
| IPv6 enabled | IPv6 leak risk | Disable IPv6 on adapters |
| VPN routes not found | TAP adapter issue | Reinstall TAP adapter or restart OpenVPN |
| Lock file stale | Previous crash | Lock auto-cleaned on next connect |
| Site returns 403 | Site blocks VPN IP | Try reconnect for new IP |

## Task Registration

If tasks are missing or corrupt:

```powershell
nord monitor disable
nord monitor enable
```

## Log Locations

- `~/.nordvpn/scripts/connect.log` - Ethernet connect events
- `~/.nordvpn/scripts/wifi-connect.log` - WiFi connect events
- `~/.nordvpn/scripts/disconnect.log` - Disconnect events
- `~/.nordvpn/scripts/watchdog.log` - Watchdog runs
- `~/.nordvpn/*.log` - OpenVPN connection logs

## Recovery

1. `nord health` - full diagnostics
2. `nord monitor disable; nord monitor enable` - reset all tasks
3. Check each log file in order
4. Restart OpenVPN service if needed
5. Reboot as last resort
