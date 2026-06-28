# NordVPN Auto-Connect — Quick Start

## Already Installed
```powershell
nord status          # Check if connected
nord health          # Run full diagnostics
nord disconnect      # Turn off VPN
nord us -tcp         # Connect to US via TCP
```

## If This Is a Fresh Machine
1. Install OpenVPN (openvpn.net/community-downloads)
2. Copy `scripts\*` to `%USERPROFILE%\.nordvpn\scripts\`
3. Copy `scripts\nord.ps1` to `%USERPROFILE%\.nordvpn\nord.ps1`
4. Copy `*.ovpn` to `%USERPROFILE%\.nordvpn\configs\`
5. Edit `%USERPROFILE%\.nordvpn\auth.txt` with NordVPN service credentials
6. Copy `scripts\nord.cmd` to `C:\Windows\nord.cmd` (admin)
7. **Disable IPv6**: Run `Disable-IPv6.ps1` (included)
8. **Register tasks**: Run `Register-Tasks.ps1` (included)
9. Test: Plug in Ethernet → wait 15s → `nord status` → "Connected"

## Files You Must Edit
- `auth.txt` — Your NordVPN service username/password
- `on-wifi-connect.cmd` line 4 — Change `SSN` to your college WiFi name
- `on-wifi-disconnect.cmd` line 4 — Same SSID

## Key Shortcuts
| What | Command |
|---|---|
| Full health check | `nord health` |
| Auto-connect on/off | `nord monitor enable/disable` |
| Reconnect with new IP | `nord reconnect` |
| View logs | `type %USERPROFILE%\.nordvpn\scripts\*.log` |

## If Something Breaks
1. `nord health` — tells you exactly which check failed
2. Check logs in `%USERPROFILE%\.nordvpn\scripts\`
3. `nord monitor disable; nord monitor enable` — re-registers all tasks
4. Check OpenVPN is installed at `C:\Program Files\OpenVPN\bin\openvpn.exe`
