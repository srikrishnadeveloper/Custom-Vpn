param(
    [string]$Action = "status"
)

$ErrorActionPreference = "Stop"

$homeDir = $env:USERPROFILE
if (-not $homeDir) { $homeDir = "$env:SystemDrive\Users\default" }

$lockFile = "$homeDir\.nordvpn\.nord.lock"

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

function Get-IP {
    try {
        $output = curl.exe -s --max-time 3 "https://api.ipify.org" 2>$null
        $ip = ($output | Select-Object -First 1).Trim()
        if ($ip -match '^\d+\.\d+\.\d+\.\d+$') { return $ip }
    } catch {}
    try { return (Invoke-WebRequest -Uri "https://api.ipify.org" -TimeoutSec 3 -UseBasicParsing).Content.Trim() } catch {}
    return $null
}

function Status-VPN {
    $proc = Get-Process -Name "openvpn" -ErrorAction SilentlyContinue
    if ($proc) {
        $ip = Get-IP
        $result = @{ connected = $true; ip = if ($ip) { $ip } else { $null } }
        Write-Output ($result | ConvertTo-Json -Compress)
    } else {
        Write-Output (@{ connected = $false; ip = $null } | ConvertTo-Json -Compress)
    }
}

function Health-Check {
    $passCount = 0
    $failCount = 0
    $checks = @()

    $proc = Get-Process -Name "openvpn" -ErrorAction SilentlyContinue
    if ($proc) { $checks += @{ name = "OpenVPN process"; status = "pass" }; $passCount++ }
    else { $checks += @{ name = "OpenVPN process"; status = "fail" }; $failCount++ }

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
    if ($internetOk) { $checks += @{ name = "Internet"; status = "pass" }; $passCount++ }
    else { $checks += @{ name = "Internet"; status = "fail" }; $failCount++ }

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
    if ($dnsOk) { $checks += @{ name = "DNS"; status = "pass" }; $passCount++ }
    else { $checks += @{ name = "DNS"; status = "fail" }; $failCount++ }

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
    if ($ipv6Ok) { $checks += @{ name = "IPv6"; status = "pass" }; $passCount++ }
    else { $checks += @{ name = "IPv6"; status = "fail" }; $failCount++ }

    $routesOk = $false
    try {
        $tapAdapter = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" -and ($_.Name -like "*TAP*" -or $_.Name -like "*Nord*") } | Select-Object -First 1
        if ($tapAdapter) {
            $route1 = Get-NetRoute -DestinationPrefix "0.0.0.0/1" -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -eq $tapAdapter.InterfaceIndex }
            $route2 = Get-NetRoute -DestinationPrefix "128.0.0.0/1" -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -eq $tapAdapter.InterfaceIndex }
            if ($route1 -and $route2) { $routesOk = $true }
        }
    } catch {}
    if ($routesOk) { $checks += @{ name = "Routes"; status = "pass" }; $passCount++ }
    else { $checks += @{ name = "Routes"; status = "fail" }; $failCount++ }

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
    if ($lockOk) { $checks += @{ name = "Lock file"; status = "pass" }; $passCount++ }
    else { $checks += @{ name = "Lock file"; status = "fail" }; $failCount++ }

    $blockedSites = @(
        @{ Name = "krunker.io"; Url = "https://krunker.io" },
        @{ Name = "chatgpt.com"; Url = "https://chatgpt.com" }
    )
    foreach ($s in $blockedSites) {
        try {
            $code = curl.exe -s -o nul -w "%{http_code}" --max-time 8 $s.Url 2>$null
            $code = "$code".Trim()
            if ($code -eq "200") {
                $checks += @{ name = $s.Name; status = "pass"; code = 200 }
                $passCount++
            } elseif ($code -eq "403") {
                $checks += @{ name = $s.Name; status = "warn"; code = 403 }
                $passCount++
            } elseif ($code -eq "000") {
                $checks += @{ name = $s.Name; status = "fail" }
                $failCount++
            } else {
                $checks += @{ name = $s.Name; status = "fail"; code = [int]$code }
                $failCount++
            }
        } catch {
            $checks += @{ name = $s.Name; status = "fail" }
            $failCount++
        }
    }

    Write-Output (@{ pass = $passCount; fail = $failCount; checks = $checks } | ConvertTo-Json -Depth 3)
}

if ($Action -in "status","state","check") { Status-VPN; return }
if ($Action -eq "health") { Health-Check; return }

Write-Output (@{ error = "Unknown action: $Action. Use 'status' or 'health'." } | ConvertTo-Json -Compress)
