# Problems & Solutions

## 1. Initial Task Triggers Used Wrong Filter

- **Problem:** Ethernet-Connect task used `Name='Ethernet'` which never matched. Event log shows profile names like "Krishna 10" — user-defined strings, not the media type.
- **Diagnosis:** Inspected event logs and found actual network profile names are user-defined strings assigned by Windows.
- **Solution:** Changed to `Type='0'` (for Ethernet) and `Type='1'` (for WiFi) which filters by media type, not profile name.

## 2. No Boot/SessionUnlock Triggers

- **Problem:** VPN wouldn't auto-connect after reboot or sleep/wake.
- **Diagnosis:** Only had EventTrigger configured for network changes.
- **Solution:** Added BootTrigger (30s delay) + SessionUnlockTrigger to all connect tasks.

## 3. StartWhenAvailable Missing on Disconnect Tasks

- **Problem:** Network disconnect event could be missed if computer was busy.
- **Diagnosis:** Disconnect tasks had no retry-on-missed-event policy.
- **Solution:** Set `StartWhenAvailable=true` on all disconnect tasks.

## 4. MultipleInstancesPolicy=IgnoreNew

- **Problem:** Rapid network transitions could lose events when a new instance was silently dropped.
- **Diagnosis:** Default policy ignores new instances when one is already running.
- **Solution:** Changed to `Parallel` on all tasks. The nord.ps1 lock file handles deduplication.

## 5. IPv6 Leak

- **Problem:** IPv6 traffic bypassed the VPN tunnel. OpenVPN only tunnels IPv4.
- **Diagnosis:** Research on VPN leaks confirmed that IPv6 can leak outside the tunnel.
- **Solution:** Disabled IPv6 on Ethernet and WiFi adapters via PowerShell.

## 6. DNS Leak

- **Problem:** DNS queries could leak to college DNS servers instead of being routed through the VPN.
- **Diagnosis:** Identified that OpenVPN DNS push wasn't blocking outbound DNS.
- **Solution:** Added `block-outside-dns` to all 40 `.ovpn` configs.

## 7. Default Server India (in) Was Blocked by Google

- **Problem:** Google returned blocks when connected through the India VPN server.
- **Diagnosis:** Tested multiple countries. India datacenter IP was on a Google blocklist.
- **Solution:** Changed default to `us -tcp`.

## 8. UDP Protocol Blocked on College Network

- **Problem:** Default OpenVPN UDP failed to connect from campus.
- **Diagnosis:** UDP on non-standard ports is throttled or dropped by the college firewall.
- **Solution:** All scripts force TCP with the `-tcp` flag.

## 9. nord.ps1 Timeout Too Short for TCP

- **Problem:** TCP connections take longer to establish than UDP. The existing timeout cut off legitimate connections.
- **Diagnosis:** Observed connection failures during high-latency periods.
- **Solution:** Increased timeout from 30s to 45s.

## 10. TOCTOU Lock Race Condition

- **Problem:** Multiple concurrent nord.ps1 instances could both pass the lock check if they read the lock file simultaneously.
- **Diagnosis:** Classic time-of-check-to-time-of-use race.
- **Solution:** Added PID-based exclusive lock file with retry mechanism (5 attempts, 200ms delay).

## 11. MainWindowTitle Filter Issue

- **Problem:** `Get-Process -MainWindowTitle` was unreliable — empty or stale titles caused false negatives.
- **Diagnosis:** Observed that OpenVPN's main window title is not always populated.
- **Solution:** Changed to `Get-Process -Name` (pure name match).

## 12. StreamReader Leak

- **Problem:** OpenVPN log file reader wasn't properly disposed, leaving file handles open.
- **Diagnosis:** Repeated runs caused resource exhaustion.
- **Solution:** Wrapped in `try/finally` with `Close()`.

## 13. curl CRLF Issue

- **Problem:** curl output had trailing CR/LF characters that broke string comparisons.
- **Diagnosis:** Debug logs showed mismatched strings due to hidden newline characters.
- **Solution:** `Trim()` the output.

## 14. auth-nocache Missing

- **Problem:** Credentials cached in memory, posing a security risk.
- **Diagnosis:** OpenVPN defaults to caching auth credentials.
- **Solution:** Added `--auth-nocache` to OpenVPN arguments.

## 15. Empty Action Validation

- **Problem:** nord.ps1 crashed with an empty or null `Action` parameter.
- **Diagnosis:** No input validation on the Action parameter.
- **Solution:** Added regex validation `$Action -match '[^\w-]'`.

## 16. WiFi-Disconnect Had No SSID Filter

- **Problem:** VPN disconnected on ANY WiFi disconnect, not just the target (SSN) network.
- **Diagnosis:** Trigger fired on all WiFi disconnection events indiscriminately.
- **Solution:** Added `TARGET_SSID` filter. Only disconnects when SSN disconnects.

## 17. Network-Disconnect Didn't Check WiFi Fallback

- **Problem:** Ethernet disconnect killed the VPN even if WiFi was still up and providing connectivity.
- **Diagnosis:** Logic only checked Ethernet state.
- **Solution:** Only disconnect if both Ethernet and WiFi are down.

## 18. Radio-adapter "Wi-Fi" vs "WiFi" Name Mismatch

- **Problem:** `Get-NetAdapter` couldn't find the adapter due to a name mismatch.
- **Diagnosis:** Confused "Wi-Fi" (display name) with "WiFi" (actual adapter name from `Get-NetAdapter`).
- **Solution:** Used the exact adapter name "WiFi" as returned by `Get-NetAdapter`.

## 19. CMD Script Encoding Had Null Bytes

- **Problem:** PowerShell redirect within scripts produced null-byte corruption in output files.
- **Diagnosis:** Inspected raw bytes of log output, found embedded `\0` characters.
- **Solution:** Moved redirect from inside PowerShell to CMD-level `>>`.

## 20. VPN Adapter Selection Bug in Health Check

- **Problem:** "OpenVPN Data Channel Offload for NordVPN" (disabled) was selected before "OpenVPN TAP-Windows6" (enabled) alphabetically, causing route check to fail.
- **Diagnosis:** Alphabetical sort picked the wrong adapter.
- **Solution:** Added `.Status -eq "Up"` filter to adapter selection.

## 21. Watchdog Script Syntax Error

- **Problem:** `^ else` inside a PowerShell command string was invalid syntax.
- **Diagnosis:** The caret character is an escape character in PowerShell, breaking the command.
- **Solution:** Removed the caret escape.

## 22. Lock File Contention During Rapid Testing

- **Problem:** Sequential test commands could hit lock contention and fail.
- **Diagnosis:** Single-attempt lock acquisition was too fragile under rapid invocation.
- **Solution:** Increased retries to 5, added `Clean-StaleLock` function.

---

## Summary

All 22+ bugs found via 15+ parallel audit subagents and fixed. System is stable.
