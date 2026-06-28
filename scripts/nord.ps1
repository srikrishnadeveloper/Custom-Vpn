param(
    [string]$Action = "us",
    [switch]$TCP,
    [int]$Timeout = 45
)

$ErrorActionPreference = "Stop"

$homeDir = $env:USERPROFILE
if (-not $homeDir) { $homeDir = "$env:SystemDrive\Users\default" }

$configDir = "$homeDir\.nordvpn\configs"
$authFile = "$homeDir\.nordvpn\auth.txt"
$suffix = if ($TCP) { "-tcp" } else { "" }
$config = "$configDir\$Action$suffix.ovpn"
$lockFile = "$homeDir\.nordvpn\.nord.lock"

if ($Action -match '[^\w-]' -or [string]::IsNullOrWhiteSpace($Action)) {
    Write-Error "Usage: nord <country|disconnect|status|list|monitor> [-tcp]"
    return
}

function Get-LockPid {
    try { return [System.IO.File]::ReadAllText($lockFile).Trim() } catch { return $null }
}

function Clean-StaleLock {
    $existing = Get-LockPid
    if (-not $existing -or $existing -notmatch '^\d+$') {
        try { [System.IO.File]::Delete($lockFile) } catch {}
        return
    }
    try {
        $ep = [System.Diagnostics.Process]::GetProcessById([int]$existing)
        $pn = $ep.ProcessName -replace '\.exe$', ''
        if ($pn -ne 'powershell' -and $pn -ne 'pwsh') {
            try { [System.IO.File]::Delete($lockFile) } catch {}
        }
    } catch {
        try { [System.IO.File]::Delete($lockFile) } catch {}
    }
}

function Acquire-Lock {
    Clean-StaleLock
    for ($retry = 0; $retry -lt 5; $retry++) {
        try {
            $stream = [System.IO.File]::Open($lockFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($pid.ToString())
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
            $stream.Close()
            return $true
        } catch {
            Start-Sleep -Milliseconds 200
            $existing = Get-LockPid
            if ($existing -match '^\d+$') {
                try {
                    $ep = [System.Diagnostics.Process]::GetProcessById([int]$existing)
                    $pn = $ep.ProcessName -replace '\.exe$', ''
                    if ($pn -eq 'powershell' -or $pn -eq 'pwsh') {
                        Write-Warning "Already running (PID $existing). Use: nord disconnect"
                        return $false
                    }
                } catch [System.ArgumentException] {
                    try { [System.IO.File]::Delete($lockFile) } catch {}
                    continue
                }
            }
            try { [System.IO.File]::Delete($lockFile) } catch {}
        }
    }
    return $false
}

function Release-Lock {
    try {
        $pidInFile = Get-LockPid
        if ($pidInFile -eq $pid.ToString()) {
            [System.IO.File]::Delete($lockFile)
        }
    } catch {}
}

function Get-IP {
    try {
        $output = curl.exe -s --max-time 3 "https://api.ipify.org" 2>$null
        $ip = ($output | Select-Object -First 1).Trim()
        if ($ip -match '^\d+\.\d+\.\d+\.\d+$') { return $ip }
    } catch {}
    try { return (Invoke-WebRequest -Uri "https://api.ipify.org" -TimeoutSec 3 -UseBasicParsing).Content.Trim() } catch {}
    return $null
}

function Disconnect-VPN {
    try {
        Get-Process -Name "openvpn" -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.Kill() } catch {}
        }
    } catch {}
    Write-Output "Disconnected"
}

function Status-VPN {
    $proc = Get-Process -Name "openvpn" -ErrorAction SilentlyContinue
    if ($proc) {
        $ip = Get-IP
        if ($ip) { Write-Output "Connected ($ip)" } else { Write-Output "Connected" }
    } else { Write-Output "Disconnected" }
}

$lastServerFile = "$homeDir\.nordvpn\.nord.last"

function Save-LastServer {
    param([string]$Server, [switch]$WasTCP)
    try {
        $data = @{ server = $Server; tcp = [bool]$WasTCP } | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($lastServerFile, $data, [System.Text.Encoding]::UTF8)
    } catch {}
}

function Load-LastServer {
    try {
        $data = [System.IO.File]::ReadAllText($lastServerFile).Trim() | ConvertFrom-Json
        return $data
    } catch { return $null }
}

function Health-Check {
    $passCount = 0
    $failCount = 0

    $proc = Get-Process -Name "openvpn" -ErrorAction SilentlyContinue
    if ($proc) { Write-Output "[PASS] OpenVPN process is running"; $passCount++ }
    else { Write-Output "[FAIL] OpenVPN process is not running"; $failCount++ }

    $internetOk = $false
    $testSites = @("https://api.ipify.org", "https://www.google.com", "https://www.cloudflare.com")
    foreach ($site in $testSites) {
        try {
            $null = Invoke-WebRequest -Uri $site -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            $internetOk = $true
            break
        } catch {
            try {
                $null = curl.exe -s --max-time 3 $site 2>$null
                $internetOk = $true
                break
            } catch {}
        }
    }
    if ($internetOk) { Write-Output "[PASS] Internet is reachable"; $passCount++ }
    else { Write-Output "[FAIL] Internet is not reachable"; $failCount++ }

    $dnsOk = $false
    try {
        $dnsServers = Get-DnsClientServerAddress -ErrorAction Stop | Where-Object { $_.InterfaceAlias -like "*TAP*" -or $_.InterfaceAlias -like "*Nord*" }
        foreach ($dns in $dnsServers) {
            if ($dns.ServerAddresses -contains "103.86.96.100") {
                $dnsOk = $true
                break
            }
        }
    } catch {}
    if ($dnsOk) { Write-Output "[PASS] DNS using NordVPN server 103.86.96.100"; $passCount++ }
    else { Write-Output "[FAIL] DNS not using NordVPN server 103.86.96.100 on TAP adapter"; $failCount++ }

    $ipv6Ok = $true
    try {
        $ipv6Bindings = Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction Stop | Where-Object { $_.Name -like "*Ethernet*" -or $_.Name -like "*Wi-Fi*" -or $_.Name -like "*WiFi*" }
        foreach ($b in $ipv6Bindings) {
            if ($b.Enabled) {
                $ipv6Ok = $false
                break
            }
        }
    } catch {}
    if ($ipv6Ok) { Write-Output "[PASS] IPv6 disabled on Ethernet/WiFi adapters"; $passCount++ }
    else { Write-Output "[FAIL] IPv6 is enabled on one or more Ethernet/WiFi adapters"; $failCount++ }

    $routesOk = $false
    try {
        $tapAdapter = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" -and ($_.Name -like "*TAP*" -or $_.Name -like "*Nord*") } | Select-Object -First 1
        if ($tapAdapter) {
            $route1 = Get-NetRoute -DestinationPrefix "0.0.0.0/1" -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -eq $tapAdapter.InterfaceIndex }
            $route2 = Get-NetRoute -DestinationPrefix "128.0.0.0/1" -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -eq $tapAdapter.InterfaceIndex }
            if ($route1 -and $route2) { $routesOk = $true }
        }
    } catch {}
    if ($routesOk) { Write-Output "[PASS] VPN routes 0.0.0.0/1 and 128.0.0.0/1 present via TAP"; $passCount++ }
    else { Write-Output "[FAIL] VPN routes not found in routing table"; $failCount++ }

    $lockOk = $true
    $existing = Get-LockPid
    if ($existing -and $existing -match '^\d+$') {
        try {
            $ep = [System.Diagnostics.Process]::GetProcessById([int]$existing)
            $pn = $ep.ProcessName -replace '\.exe$', ''
            if ($pn -ne 'powershell' -and $pn -ne 'pwsh') {
                $lockOk = $false
            }
        } catch {
            $lockOk = $false
        }
    }
    if ($lockOk) { Write-Output "[PASS] Lock file is valid"; $passCount++ }
    else { Write-Output "[FAIL] Lock file is stale (PID $existing)"; $failCount++ }

    $blockedSites = @(
        @{ Name = "krunker.io"; Url = "https://krunker.io" },
        @{ Name = "chatgpt.com"; Url = "https://chatgpt.com" }
    )
    foreach ($s in $blockedSites) {
        try {
            $code = curl.exe -s -o nul -w "%{http_code}" --max-time 8 $s.Url 2>$null
            $code = "$code".Trim()
            if ($code -eq "200") { Write-Output "[PASS] $($s.Name) returns 200 (accessible)"; $passCount++ }
            elseif ($code -eq "403") { Write-Output "[WARN] $($s.Name) returns 403 (VPN IP blocked by site)"; $passCount++ }
            elseif ($code -eq "000") { Write-Output "[WARN] $($s.Name) unreachable (connection failed)"; $failCount++ }
            else { Write-Output "[WARN] $($s.Name) returns $code"; $failCount++ }
        } catch { Write-Output "[WARN] $($s.Name) test failed"; $failCount++ }
    }

    Write-Output ""
    Write-Output "Summary: $passCount passed, $failCount failed"
}

if ($Action -in "disconnect","down","off","stop") { Disconnect-VPN; return }
if ($Action -in "status","state","check") { Status-VPN; return }

if ($Action -eq "list") {
    $files = Get-ChildItem "$configDir\*.ovpn" -Name -ErrorAction SilentlyContinue
    if (-not $files) { Write-Output "No configs found in $configDir"; return }
    $files | ForEach-Object { $_ -replace '\.ovpn$','' } | Sort-Object
    return
}

if ($Action -eq "monitor") {
    Write-Output "Use: nord monitor (from cmd.exe)"
    return
}

if ($Action -eq "health") {
    Health-Check
    return
}

if ($Action -eq "reconnect") {
    $lastData = Load-LastServer
    if (-not $lastData -or [string]::IsNullOrWhiteSpace($lastData.server)) {
        Write-Error "No previous connection found. Connect first with: nord <server>"
        return
    }
    if ($lastData.tcp) { $TCP = $true; $suffix = "-tcp" }
    Disconnect-VPN
    Start-Sleep -Seconds 2
    $Action = $lastData.server
    $config = "$configDir\$Action$suffix.ovpn"
}

if (-not (Test-Path $authFile)) {
    Write-Error "Missing $authFile -- add your NordVPN service credentials"
    Write-Output "Get them: https://my.nordaccount.com > Services > NordVPN > Manual setup"
    return
}

$auth = Get-Content $authFile -TotalCount 2 -ErrorAction SilentlyContinue
$auth = $auth | ForEach-Object { $_.TrimStart("`u{FEFF}") }
if ($auth.Count -lt 2 -or [string]::IsNullOrWhiteSpace($auth[0]) -or [string]::IsNullOrWhiteSpace($auth[1])) {
    Write-Error "auth.txt must have username on line 1 and password on line 2"
    return
}
if ($auth[0] -eq "YOUR_NORDVPN_USERNAME") {
    Write-Error "Edit auth.txt with your real NordVPN service credentials (not your email)"
    Write-Output "Get them: https://my.nordaccount.com > Services > NordVPN > Manual setup"
    return
}

if (-not (Test-Path $config)) {
    $available = Get-ChildItem "$configDir\*.ovpn" -Name -ErrorAction SilentlyContinue | ForEach-Object { $_ -replace '\.ovpn$','' } | Sort-Object
    if (-not $available) { $available = @("<none>") }
    Write-Output "Available: $($available -join ', ')"
    Write-Error "No config for '$Action'."
    return
}

$openvpnPaths = @(
    "C:\Program Files\OpenVPN\bin\openvpn.exe",
    "C:\Program Files\OpenVPN Connect\openvpn.exe",
    "$homeDir\AppData\Local\OpenVPN\bin\openvpn.exe"
)
$openvpnExe = $null
foreach ($p in $openvpnPaths) { if (Test-Path $p) { $openvpnExe = $p; break } }
if (-not $openvpnExe) {
    $openvpnExe = Get-Command "openvpn.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}
if (-not $openvpnExe) {
    Write-Error "OpenVPN not found. Install from https://openvpn.net/community-downloads/"
    return
}

if (-not (Acquire-Lock)) { return }

try {
    Disconnect-VPN
    Start-Sleep -Seconds 2

    Write-Output "NordVPN -> $Action ..."
    $logFile = Join-Path "$homeDir\.nordvpn" ($Action + $suffix + ".log")

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $openvpnExe
    $psi.Arguments = "--config `"$config`" --auth-user-pass `"$authFile`" --log `"$logFile`" --auth-nocache"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    if (-not $proc -or $proc.HasExited) {
        Write-Error "OpenVPN failed to start"
        return
    }

    $connected = $false
    $authFailed = $false
    $fatal = $false
    $lastSize = 0
    $checkInterval = 1
    $reader = $null

    for ($i = 0; $i -lt $Timeout; $i += $checkInterval) {
        Start-Sleep -Seconds $checkInterval
        if ($proc.HasExited) { break }
        if (Test-Path $logFile) {
            $currentSize = (Get-Item $logFile).Length
            if ($currentSize -gt $lastSize) {
                try {
                    if (-not $reader) {
                        $fs = [System.IO.FileStream]::new($logFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        $reader = [System.IO.StreamReader]::new($fs)
                    }
                    $reader.BaseStream.Seek($lastSize, [System.IO.SeekOrigin]::Begin) | Out-Null
                    while (-not $reader.EndOfStream) {
                        $text = $reader.ReadLine()
                        if ($text -match "Initialization Sequence Completed") { $connected = $true; break }
                        if ($text -match "AUTH_FAILED") { $authFailed = $true; break }
                        if ($text -match "FATAL:" -or $text -match "Exiting due to fatal error") { $fatal = $true; break }
                    }
                    $lastSize = $currentSize
                } catch {}
                if ($connected -or $authFailed -or $fatal) { break }
            }
        }
    }

    if ($authFailed) {
        Write-Error "Authentication failed. Update your credentials in $authFile"
        if (-not $proc.HasExited) { $proc.Kill() }
        return
    }

    if ($connected) {
        Write-Output "Initialization Sequence Completed"
        Save-LastServer -Server $Action -WasTCP:$TCP
    } else {
        if (Test-Path $logFile) {
            $lastLines = Get-Content $logFile -Tail 3 -ErrorAction SilentlyContinue
            Write-Warning "Connection may have failed. Last log lines:"
            $lastLines | ForEach-Object { Write-Output "  $_" }
        }
        if (-not $proc.HasExited) { $proc.Kill() }
    }
    Status-VPN
}
finally {
    if ($reader) { $reader.Close() }
    Release-Lock
}
