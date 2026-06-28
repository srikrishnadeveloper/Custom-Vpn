# NordVPN Auto-Connect — Windows Setup Guide

Clean install guide for Windows 10/11.

---

## 1 — Install OpenVPN

Download the community installer:

```
https://openvpn.net/community-downloads/
```

Run the installer. Accept defaults. **Do not** change the install path.

Reboot after installation completes.

---

## 2 — Create directory structure

Open PowerShell as Administrator and run:

```
mkdir "$env:USERPROFILE\.nordvpn\configs"
mkdir "$env:USERPROFILE\.nordvpn\scripts"
```

---

## 3 — Get NordVPN credentials

1. Go to https://my.nordaccount.com
2. Sign in
3. Services > NordVPN > Manual setup
4. Copy the **service username** (looks like `12345678`, **not** your email address)
5. Copy the **service password**

Create the auth file:

```
$user = Read-Host "Enter NordVPN service username"
$pass = Read-Host -AsSecureString "Enter NordVPN service password"
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
$plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
"$user`n$plain" | Out-File -FilePath "$env:USERPROFILE\.nordvpn\auth.txt" -Encoding Ascii -NoNewline
```

Verify:

```
Get-Content "$env:USERPROFILE\.nordvpn\auth.txt"
```

You should see exactly two lines — username on line 1, password on line 2. No extra whitespace, no BOM, no trailing blank line.

---

## 4 — Copy config files

```
$src = "C:\Users\srik2\Desktop\Projects\Wi-Fi\scripts"
Copy-Item -Path "$src\*.ovpn" -Destination "$env:USERPROFILE\.nordvpn\configs\"
```

Verify:

```
Get-ChildItem "$env:USERPROFILE\.nordvpn\configs\*.ovpn"
```

---

## 5 — Copy scripts

```
$src = "C:\Users\srik2\Desktop\Projects\Wi-Fi\scripts"
Copy-Item -Path "$src\nord.ps1" -Destination "$env:USERPROFILE\.nordvpn\nord.ps1"
Copy-Item -Path "$src\*.cmd" -Destination "$env:USERPROFILE\.nordvpn\scripts\"
```

Verify:

```
Get-ChildItem "$env:USERPROFILE\.nordvpn" -Recurse
```

Expected layout:

```
.nordvpn\
├── auth.txt
├── nord.ps1
├── configs\
│   └── us-tcp.ovpn
└── scripts\
    ├── nord.cmd
    ├── on-network-connect.cmd
    ├── on-network-disconnect.cmd
    ├── on-wifi-connect.cmd
    ├── on-wifi-disconnect.cmd
    └── watchdog.cmd
```

---

## 6 — Install CLI wrapper

**Option A — System-wide (requires Administrator):**

```
Copy-Item -Path "$env:USERPROFILE\.nordvpn\scripts\nord.cmd" -Destination "C:\Windows\nord.cmd"
```

Now `nord` is available from any Command Prompt.

**Option B — Add to PATH (no admin):**

```
$path = [Environment]::GetEnvironmentVariable("PATH", "User")
$nord = "$env:USERPROFILE\.nordvpn"
if ($path -notlike "*$nord*") {
    [Environment]::SetEnvironmentVariable("PATH", "$path;$nord", "User")
}
```

Then close and reopen your terminal, or run:

```
$env:PATH = "$env:PATH;$env:USERPROFILE\.nordvpn"
```

After either option, verify:

```
nord list
```

You should see available server codes.

---

## 7 — Disable IPv6

Run in PowerShell as Administrator:

```
Get-NetAdapterBinding -Name "Ethernet","WiFi" -ComponentID ms_tcpip6 | Disable-NetAdapterBinding -PassThru
```

Verify:

```
Get-NetAdapterBinding -Name "Ethernet","WiFi" -ComponentID ms_tcpip6 | Select-Object Name, ComponentID, Enabled
```

Every row should show `Enabled: False`.

---

## 8 — Register scheduled tasks

Run each block in PowerShell **as Administrator**.

### Task 1 — Ethernet-Connect

Triggered at startup, user logon, and when Ethernet comes up.

```
@'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Connects NordVPN when Ethernet is available</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
    <LogonTrigger>
      <UserId>SYSTEM</UserId>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <EventTrigger>
      <Subscription><QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[EventID=10000]]</Select></Query></QueryList></Subscription>
      <Enabled>true</Enabled>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>SYSTEM</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <Enabled>true</Enabled>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>C:\Windows\System32\cmd.exe</Command>
      <Arguments>/c "%USERPROFILE%\.nordvpn\scripts\on-network-connect.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
'@ | Out-File -FilePath "$env:TEMP\nord-eth-connect.xml" -Encoding Unicode

schtasks /create /tn "NordVPN-Ethernet-Connect" /xml "$env:TEMP\nord-eth-connect.xml" /f
```

### Task 2 — WiFi-Connect

Triggered at startup, user logon, and when WiFi connects.

```
@'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Connects NordVPN on SSN WiFi</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
    <LogonTrigger>
      <UserId>SYSTEM</UserId>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <EventTrigger>
      <Subscription><QueryList><Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"><Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational">*[System[EventID=8001]]</Select></Query></QueryList></Subscription>
      <Enabled>true</Enabled>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>SYSTEM</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <Enabled>true</Enabled>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>C:\Windows\System32\cmd.exe</Command>
      <Arguments>/c "%USERPROFILE%\.nordvpn\scripts\on-wifi-connect.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
'@ | Out-File -FilePath "$env:TEMP\nord-wifi-connect.xml" -Encoding Unicode

schtasks /create /tn "NordVPN-WiFi-Connect" /xml "$env:TEMP\nord-wifi-connect.xml" /f
```

### Task 3 — Ethernet-Disconnect

Triggered when Ethernet disconnects.

```
schtasks /create /tn "NordVPN-Ethernet-Disconnect" /tr "cmd /c \"%USERPROFILE%\.nordvpn\scripts\on-network-disconnect.cmd\"" /sc onevent /ec Microsoft-Windows-NetworkProfile/Operational /mo "*[System[EventID=10001]]" /ru SYSTEM /rl HIGHEST /f
```

### Task 4 — WiFi-Disconnect

Triggered when WiFi disconnects.

```
schtasks /create /tn "NordVPN-WiFi-Disconnect" /tr "cmd /c \"%USERPROFILE%\.nordvpn\scripts\on-wifi-disconnect.cmd\"" /sc onevent /ec Microsoft-Windows-WLAN-AutoConfig/Operational /mo "*[System[EventID=8003]]" /ru SYSTEM /rl HIGHEST /f
```

### Task 5 — Watchdog

Runs every 5 minutes to recover from unexpected disconnects.

```
schtasks /create /tn "NordVPN-Watchdog" /tr "cmd /c \"%USERPROFILE%\.nordvpn\scripts\watchdog.cmd\"" /sc minute /mo 5 /ru SYSTEM /rl HIGHEST /f
```

### Verify all tasks

```
schtasks /query /tn "NordVPN-Ethernet-Connect" /v /fo list | findstr "TaskName\|Status\|Triggers\|Task To Run"
schtasks /query /tn "NordVPN-WiFi-Connect" /v /fo list | findstr "TaskName\|Status\|Triggers\|Task To Run"
schtasks /query /tn "NordVPN-Ethernet-Disconnect" /v /fo list | findstr "TaskName\|Status\|Triggers\|Task To Run"
schtasks /query /tn "NordVPN-WiFi-Disconnect" /v /fo list | findstr "TaskName\|Status\|Triggers\|Task To Run"
schtasks /query /tn "NordVPN-Watchdog" /v /fo list | findstr "TaskName\|Status\|Triggers\|Task To Run"
```

Every task should show `Status: Ready`.

---

## 9 — Verify installation

Open a **Command Prompt** (not PowerShell) and run:

```
nord monitor
```

Expected output:

```
Auto-Connect Monitor:
  Ethernet: ACTIVE
  WiFi-SSN: ACTIVE
```

Run the full health check:

```
nord health
```

Each check should show `[PASS]`. If any `[FAIL]` appears, fix the issue before proceeding.

---

## 10 — Test

### Ethernet test

1. Plug an Ethernet cable into the computer
2. Wait 15 seconds
3. Run:
   ```
   nord status
   ```

Expected output:

```
Connected (203.0.113.x)
```

### WiFi test

1. Disconnect Ethernet
2. Connect to WiFi **SSN**
3. Wait 15 seconds
4. Run:
   ```
   nord status
   ```

Expected output:

```
Connected (203.0.113.x)
```

### Disconnect test

1. Run:
   ```
   nord disconnect
   ```
2. Verify:
   ```
   nord status
   ```
   Output: `Disconnected`
3. Wait 5 minutes — the Watchdog should reconnect if Ethernet or SSN WiFi is still active.
4. Check:
   ```
   nord status
   ```
   Output: `Connected (203.0.113.x)`

---

## 11 — Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `OpenVPN not found. Install from...` | OpenVPN is not installed or not in the default location | Install from https://openvpn.net/community-downloads/ and reboot |
| `Missing ...auth.txt` | Auth file does not exist | Follow Step 3 to create it |
| `No config for 'us'` | Config files not copied | Run Step 4, verify files exist in `%USERPROFILE%\.nordvpn\configs\` |
| `Already running (PID xxxx)` | A connection is already active | Run `nord disconnect` and retry |
| `AUTH_FAILED` | Bad credentials in auth.txt | Regenerate credentials at my.nordaccount.com > Services > NordVPN > Manual setup, then update `auth.txt` |
| `[FAIL] IPv6 is enabled` | IPv6 not disabled on adapters | Run the command in Step 7 as Administrator |
| `[FAIL] OpenVPN process is not running` | Not connected or connection dropped | Run `nord us -tcp` to connect, or wait for Watchdog |
| `[FAIL] Internet is not reachable` | No internet connectivity | Check your physical connection |
| No automatic connection after boot | Scheduled task is disabled or errored | Run `nord monitor enable`, check `schtasks /query /tn "NordVPN-Ethernet-Connect"` |

### Log files

Each script writes its own log for debugging:

```
%USERPROFILE%\.nordvpn\scripts\connect.log
%USERPROFILE%\.nordvpn\scripts\disconnect.log
%USERPROFILE%\.nordvpn\scripts\wifi-connect.log
%USERPROFILE%\.nordvpn\scripts\wifi-disconnect.log
%USERPROFILE%\.nordvpn\scripts\watchdog.log
%USERPROFILE%\.nordvpn\us-tcp.log
```

Check the most recent entries:

```
Get-Content "$env:USERPROFILE\.nordvpn\scripts\connect.log" -Tail 10
Get-Content "$env:USERPROFILE\.nordvpn\us-tcp.log" -Tail 10
```

### Manual connection

To bypass the auto-connect system and connect directly:

```
nord us -tcp
```

### Enable / disable the monitor

```
nord monitor enable
nord monitor disable
```

Disable temporarily stops all auto-connect tasks from running without deleting them.
