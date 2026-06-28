param([switch]$Fix)

$script:exitCode = 0
$script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Write-Result {
    param([string]$Check, [bool]$Pass, [string]$Message)
    $symbol = if ($Pass) { "PASS" } else { "FAIL" }
    $color = if ($Pass) { "Green" } else { "Red" }
    Write-Host ("{0,-10} {1,-40} {2}" -f $symbol, $Check, $Message) -ForegroundColor $color
    if (-not $Pass) { $script:exitCode = 1 }
}

function Test-Admin {
    if (-not $script:isAdmin) {
        Write-Result "admin" $false "Not running as administrator"
        if ($Fix) {
            $choice = Read-Host "Restart as administrator? (Y/N)"
            if ($choice -eq 'Y') {
                Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $(if($Fix){'-Fix'}else{''})"
                exit
            }
        }
    } else {
        Write-Result "admin" $true "Running as administrator"
    }
}

function Test-NordVpnDir {
    $path = "$env:USERPROFILE\.nordvpn"
    if (Test-Path $path) {
        Write-Result ".nordvpn dir" $true $path
    } else {
        Write-Result ".nordvpn dir" $false "Missing: $path"
        if ($Fix) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }
}

function Test-EssentialFiles {
    $files = @(
        "$env:USERPROFILE\.nordvpn\nord.ps1",
        "$env:USERPROFILE\.nordvpn\auth.txt",
        "$env:USERPROFILE\.nordvpn\scripts\on-network-connect.cmd",
        "$env:USERPROFILE\.nordvpn\scripts\watchdog.cmd"
    )
    $ovpnFiles = Get-ChildItem "$env:USERPROFILE\.nordvpn\configs\*.ovpn" -ErrorAction SilentlyContinue
    if ($ovpnFiles.Count -eq 0) {
        Write-Result "configs/*.ovpn" $false "No .ovpn files found in configs\"
    } else {
        Write-Result "configs/*.ovpn" $true "$($ovpnFiles.Count) .ovpn file(s) found"
    }

    foreach ($f in $files) {
        $name = $f.Replace("$env:USERPROFILE\.nordvpn\", "")
        if (Test-Path $f) {
            if ($name -eq "auth.txt") {
                $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
                if ($content -and $content -notmatch "YOUR_NORDVPN_USERNAME") {
                    Write-Result $name $true "Exists with real credentials"
                } else {
                    Write-Result $name $false "Exists but has placeholder credentials"
                }
            } else {
                Write-Result $name $true "Exists"
            }
        } else {
            Write-Result $name $false "Missing: $f"
        }
    }
}

function Test-AuthTxtCredentials {
    $path = "$env:USERPROFILE\.nordvpn\auth.txt"
    if (Test-Path $path) {
        $content = Get-Content $path -Raw -ErrorAction SilentlyContinue
        if ($content -match "YOUR_NORDVPN_USERNAME") {
            Write-Result "auth.txt creds" $false "Contains placeholder 'YOUR_NORDVPN_USERNAME'"
        } elseif ([string]::IsNullOrWhiteSpace($content)) {
            Write-Result "auth.txt creds" $false "File is empty"
        } else {
            Write-Result "auth.txt creds" $true "Credentials look valid"
        }
    } else {
        Write-Result "auth.txt creds" $false "File not found"
    }
}

function Test-OpenVpnBinary {
    $path = "C:\Program Files\OpenVPN\bin\openvpn.exe"
    if (Test-Path $path) {
        Write-Result "OpenVPN binary" $true $path
    } else {
        Write-Result "OpenVPN binary" $false "Missing: $path"
    }
}

function Test-NordCmd {
    $path = "C:\Windows\nord.cmd"
    if (Test-Path $path) {
        Write-Result "C:\Windows\nord.cmd" $true "Exists"
    } else {
        Write-Result "C:\Windows\nord.cmd" $false "Missing: $path"
        if ($Fix -and $script:isAdmin) {
            $target = "$env:USERPROFILE\.nordvpn\nord.ps1"
            if (Test-Path $target) {
                "@echo off`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$target`" %*" | Out-File $path -Encoding ASCII
                Write-Result "C:\Windows\nord.cmd" $true "Created by -Fix"
            }
        }
    }
}

function Test-ScheduledTasks {
    $tasks = @(
        "NordVPN-Ethernet-Connect",
        "NordVPN-WiFi-Connect",
        "NordVPN-Ethernet-Disconnect",
        "NordVPN-WiFi-Disconnect",
        "NordVPN-Watchdog"
    )
    foreach ($task in $tasks) {
        $t = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
        if ($t) {
            $state = $t.State
            if ($state -eq "Ready" -or $state -eq "Running") {
                Write-Result $task $true "Enabled ($state)"
            } else {
                Write-Result $task $false "Disabled ($state)"
                if ($Fix) {
                    Enable-ScheduledTask -TaskName $task | Out-Null
                    Write-Result $task $true "Enabled by -Fix" -ErrorAction SilentlyContinue
                }
            }
        } else {
            Write-Result $task $false "Task not found"
            if ($Fix -and $script:isAdmin) {
                $scriptRoot = "$env:USERPROFILE\.nordvpn"
                $action = New-ScheduledTaskAction -Execute "C:\Windows\nord.cmd" -Argument "connect"
                $trigger = New-ScheduledTaskTrigger -AtStartup
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
                Write-Result $task $true "Re-registered by -Fix" -ErrorAction SilentlyContinue
            }
        }
    }
}

function Test-IPv6Disabled {
    $adapters = Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    $failCount = 0
    foreach ($adapter in $adapters) {
        if ($adapter.Enabled -eq $true) {
            Write-Result "IPv6: $($adapter.Name)" $false "IPv6 is ENABLED"
            $failCount++
            if ($Fix -and $script:isAdmin) {
                Disable-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -Confirm:$false | Out-Null
                Write-Result "IPv6: $($adapter.Name)" $true "Disabled by -Fix" -ErrorAction SilentlyContinue
            }
        }
    }
    if ($failCount -eq 0) {
        Write-Result "IPv6 disabled" $true "All adapters have IPv6 disabled"
    }
}

function Start-HealthCheck {
    Write-Host "`nNordVPN Auto-Connect - Permission Check`n" -ForegroundColor Cyan
    Test-Admin
    Test-NordVpnDir
    Test-EssentialFiles
    Test-AuthTxtCredentials
    Test-OpenVpnBinary
    if ($script:isAdmin) { Test-NordCmd }
    Test-ScheduledTasks
    Test-IPv6Disabled
    Write-Host ""
    if ($script:exitCode -eq 0) {
        Write-Host "All checks PASSED" -ForegroundColor Green
    } else {
        Write-Host "Some checks FAILED - run with -Fix to attempt repairs" -ForegroundColor Yellow
    }
    exit $script:exitCode
}

Start-HealthCheck
