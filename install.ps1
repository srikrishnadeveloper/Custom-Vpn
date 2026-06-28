param(
    [string]$NordUser = "",
    [string]$NordPass = "",
    [string]$WifiSSID = "SSN",
    [switch]$Silent,
    [switch]$SkipOpenVPN,
    [switch]$Uninstall
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NordDir = "$env:USERPROFILE\.nordvpn"
$ConfigDir = "$NordDir\configs"
$ScriptsDir = "$NordDir\scripts"
$ErrorLog = @()

function Write-ProgressMsg {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "[.] $Message" -ForegroundColor Cyan
    }
}

function Write-Success {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "[~] $Message" -ForegroundColor Green
    }
}

function Write-WarningMsg {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "[!] $Message" -ForegroundColor Yellow
    }
}

function Write-ErrorMsg {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "[X] $Message" -ForegroundColor Red
    }
}

function Write-LogError {
    param([string]$Message)
    $global:ErrorLog += $Message
    Write-ErrorMsg $Message
}

function Remove-Task {
    param([string]$Name)
    schtasks /delete /f /tn "\$Name" 2>$null
}

# Uninstall mode
if ($Uninstall) {
    Write-ProgressMsg "Uninstalling NordVPN auto-connect..."

    $taskNames = @(
        "NordVPN-Ethernet-Connect",
        "NordVPN-WiFi-Connect",
        "NordVPN-Ethernet-Disconnect",
        "NordVPN-WiFi-Disconnect",
        "NordVPN-Watchdog"
    )
    foreach ($tn in $taskNames) {
        Remove-Task -Name $tn
    }
    Write-Success "Scheduled tasks removed."

    if (Test-Path $NordDir) {
        try {
            Remove-Item -Path $NordDir -Recurse -Force
            Write-Success "Removed $NordDir"
        } catch {
            Write-LogError "Failed to remove $NordDir : $_"
        }
    } else {
        Write-ProgressMsg "$NordDir does not exist."
    }

    $nordCmdDest = "C:\Windows\nord.cmd"
    if (Test-Path $nordCmdDest) {
        try {
            Remove-Item -Path $nordCmdDest -Force
            Write-Success "Removed $nordCmdDest"
        } catch {
            Write-LogError "Failed to remove $nordCmdDest : $_"
        }
    }

    Write-Host ""
    Write-Host "Uninstall complete." -ForegroundColor Green
    Write-Host "Note: IPv6 settings were not reverted. Re-enable via:" -ForegroundColor Yellow
    Write-Host "  Get-NetAdapterBinding -ComponentID ms_tcpip6 | Enable-NetAdapterBinding -ComponentID ms_tcpip6 -Confirm:`$false" -ForegroundColor White
    exit 0
}

# Step 1: Check Admin
Write-ProgressMsg "Checking administrator privileges..."
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-WarningMsg "Not running as administrator. Restarting with elevated rights..."
    $elevatedArgs = @()
    if ($NordUser) { $elevatedArgs += "-NordUser `"$NordUser`"" }
    if ($NordPass) { $elevatedArgs += "-NordPass `"$NordPass`"" }
    if ($WifiSSID -ne "SSN") { $elevatedArgs += "-WifiSSID `"$WifiSSID`"" }
    if ($Silent) { $elevatedArgs += "-Silent" }
    if ($SkipOpenVPN) { $elevatedArgs += "-SkipOpenVPN" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($elevatedArgs -join ' ')"
    exit 0
}
Write-Success "Administrator privileges confirmed."

# Step 2: Check OpenVPN
if (-not $SkipOpenVPN) {
    Write-ProgressMsg "Checking OpenVPN installation..."
    $OpenVpnPath = "C:\Program Files\OpenVPN\bin\openvpn.exe"
    $OpenVpnPath86 = "C:\Program Files (x86)\OpenVPN\bin\openvpn.exe"
    if (Test-Path $OpenVpnPath) {
        Write-Success "OpenVPN found at $OpenVpnPath"
    } elseif (Test-Path $OpenVpnPath86) {
        Write-Success "OpenVPN found at $OpenVpnPath86"
        $OpenVpnPath = $OpenVpnPath86
    } else {
        Write-WarningMsg "OpenVPN is not installed."
        if (-not $Silent) {
            Write-Host ""
            Write-Host "OpenVPN is required for NordVPN connections." -ForegroundColor Yellow
            Write-Host "Please download and install from: https://openvpn.net/community-downloads/" -ForegroundColor Yellow
            Write-Host ""
            $choice = Read-Host "Press Enter after installing OpenVPN, or type 'skip' to skip"
            if ($choice -eq 'skip') {
                Write-WarningMsg "Skipping OpenVPN check."
            }
        } else {
            Write-WarningMsg "OpenVPN not found. Install manually from https://openvpn.net/community-downloads/"
        }
    }
} else {
    Write-ProgressMsg "Skipping OpenVPN check (per -SkipOpenVPN flag)."
}

# Step 3: Create directories
Write-ProgressMsg "Creating directory structure..."
try {
    $null = New-Item -ItemType Directory -Path $NordDir -Force
    $null = New-Item -ItemType Directory -Path $ConfigDir -Force
    $null = New-Item -ItemType Directory -Path $ScriptsDir -Force
    Write-Success "Directories created at $NordDir"
} catch {
    Write-LogError "Failed to create directories: $_"
}

# Step 4: Copy .ovpn files from scripts\*.ovpn
Write-ProgressMsg "Copying OpenVPN configuration files..."
try {
    $ovpnSourceDir = Join-Path $ScriptDir "scripts"
    $ovpnFiles = Get-ChildItem -Path $ovpnSourceDir -Filter "*.ovpn" -File -ErrorAction SilentlyContinue
    if ($ovpnFiles.Count -gt 0) {
        foreach ($file in $ovpnFiles) {
            Copy-Item -Path $file.FullName -Destination "$ConfigDir\$($file.Name)" -Force
        }
        Write-Success "Copied $($ovpnFiles.Count) .ovpn configuration files."
    } else {
        Write-WarningMsg "No .ovpn files found in $ovpnSourceDir"
    }
} catch {
    Write-LogError "Failed to copy .ovpn files: $_"
}

# Step 5: Copy scripts
Write-ProgressMsg "Copying PowerShell and batch scripts..."
try {
    $nordScript = Get-ChildItem -Path (Join-Path $ScriptDir "scripts") -Filter "nord.ps1" -File -ErrorAction SilentlyContinue
    if ($nordScript) {
        Copy-Item -Path $nordScript.FullName -Destination "$NordDir\nord.ps1" -Force
        Write-Success "Copied nord.ps1"
    } else {
        Write-WarningMsg "nord.ps1 not found in installer directory."
    }

    $cmdScripts = Get-ChildItem -Path (Join-Path $ScriptDir "scripts") -Filter "*.cmd" -File -ErrorAction SilentlyContinue
    if ($cmdScripts.Count -gt 0) {
        foreach ($file in $cmdScripts) {
            Copy-Item -Path $file.FullName -Destination "$ScriptsDir\$($file.Name)" -Force
        }
        Write-Success "Copied $($cmdScripts.Count) .cmd script files."
    } else {
        Write-WarningMsg "No .cmd files found in installer directory."
    }
} catch {
    Write-LogError "Failed to copy scripts: $_"
}

# Step 6: Credentials
Write-ProgressMsg "Setting up NordVPN credentials..."
$AuthFile = "$NordDir\auth.txt"
if ($NordUser -and $NordPass) {
    try {
        "$NordUser`n$NordPass" | Out-File -FilePath $AuthFile -Encoding ascii -Force
        Write-Success "Credentials written to $AuthFile"
    } catch {
        Write-LogError "Failed to write credentials: $_"
    }
} elseif (-not $Silent) {
    try {
        $inputUser = Read-Host "Enter NordVPN username (email or service credentials)"
        $inputPass = Read-Host "Enter NordVPN password" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($inputPass)
        $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        "$inputUser`n$plainPass" | Out-File -FilePath $AuthFile -Encoding ascii -Force
        Write-Success "Credentials written to $AuthFile"
    } catch {
        Write-LogError "Failed to prompt for credentials: $_"
    }
} else {
    Write-WarningMsg "No credentials provided. Create $AuthFile manually with username on line 1, password on line 2."
}

# Step 7: WiFi SSID
Write-ProgressMsg "Updating WiFi SSID references..."
$onConnectCmd = "$ScriptsDir\on-wifi-connect.cmd"
$onDisconnectCmd = "$ScriptsDir\on-wifi-disconnect.cmd"
if ($WifiSSID -ne "SSN") {
    try {
        if (Test-Path $onConnectCmd) {
            (Get-Content $onConnectCmd) -replace "SSN", $WifiSSID | Set-Content $onConnectCmd -Force
            Write-Success "Updated SSID in on-wifi-connect.cmd"
        } else {
            Write-WarningMsg "on-wifi-connect.cmd not found at $onConnectCmd"
        }
        if (Test-Path $onDisconnectCmd) {
            (Get-Content $onDisconnectCmd) -replace "SSN", $WifiSSID | Set-Content $onDisconnectCmd -Force
            Write-Success "Updated SSID in on-wifi-disconnect.cmd"
        } else {
            Write-WarningMsg "on-wifi-disconnect.cmd not found at $onDisconnectCmd"
        }
    } catch {
        Write-LogError "Failed to update SSID in scripts: $_"
    }
} else {
    Write-ProgressMsg "Using default SSID 'SSN'."
}

# Step 8: Create temp auth.txt placeholder
Write-ProgressMsg "Ensuring auth.txt exists for file-existence checks..."
try {
    if (-not (Test-Path $AuthFile)) {
        "placeholder_username`nplaceholder_password" | Out-File -FilePath $AuthFile -Encoding ascii -Force
        Write-Success "Placeholder auth.txt created."
    } else {
        Write-ProgressMsg "auth.txt already exists."
    }
} catch {
    Write-LogError "Failed to create placeholder auth.txt: $_"
}

# Step 9: Disable IPv6
Write-ProgressMsg "Disabling IPv6 on all network adapters..."
try {
    $adapters = Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    if ($adapters) {
        $disabledCount = 0
        foreach ($adapter in $adapters) {
            try {
                if ($adapter.Enabled) {
                    Disable-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -Confirm:$false -ErrorAction Stop
                    $disabledCount++
                }
            } catch {
                Write-LogError "Failed to disable IPv6 on adapter '$($adapter.Name)': $_"
            }
        }
        if ($disabledCount -gt 0) {
            Write-Success "IPv6 disabled on $disabledCount adapter(s)."
        } else {
            Write-ProgressMsg "IPv6 already disabled on all adapters."
        }
    } else {
        Write-WarningMsg "No network adapters found for IPv6 configuration."
    }
} catch {
    Write-LogError "Failed to query or disable IPv6 bindings: $_"
}

# Step 10: Register tasks
Write-ProgressMsg "Registering scheduled tasks..."
$registerTasksScript = Join-Path (Join-Path $ScriptDir "scripts") "Register-Tasks.ps1"
try {
    if (Test-Path $registerTasksScript) {
        & $registerTasksScript
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Scheduled tasks registered successfully."
        } else {
            Write-LogError "Register-Tasks.ps1 exited with code $LASTEXITCODE."
        }
    } else {
        Write-WarningMsg "Register-Tasks.ps1 not found in installer directory. Skipping task registration."
    }
} catch {
    Write-LogError "Failed to execute Register-Tasks.ps1: $_"
}

# Step 11: CLI wrapper
Write-ProgressMsg "Installing CLI wrapper..."
$nordCmdSource = Join-Path (Join-Path $ScriptDir "scripts") "nord.cmd"
$nordCmdDest = "C:\Windows\nord.cmd"
if ($IsAdmin) {
    try {
        if (Test-Path $nordCmdSource) {
            Copy-Item -Path $nordCmdSource -Destination $nordCmdDest -Force
            Write-Success "CLI wrapper installed to $nordCmdDest"
        } else {
            Write-WarningMsg "nord.cmd not found in installer directory. Skipping CLI wrapper installation."
        }
    } catch {
        Write-LogError "Failed to copy nord.cmd to C:\Windows: $_"
    }
} else {
    Write-WarningMsg "Not running as admin. Cannot copy nord.cmd to C:\Windows."
    if (Test-Path $nordCmdSource) {
        $userPath = "$NordDir\nord.cmd"
        try {
            Copy-Item -Path $nordCmdSource -Destination $userPath -Force
            Write-ProgressMsg "Copied nord.cmd to $userPath"
            Write-WarningMsg "Add $NordDir to your PATH to use 'nord' from any terminal."
        } catch {
            Write-LogError "Failed to copy nord.cmd to user directory: $_"
        }
    }
}

# Step 12: Test
Write-ProgressMsg "Running health check..."
try {
    $nordScript = "$NordDir\nord.ps1"
    if (Test-Path $nordScript) {
        $healthResult = & $nordScript health 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Health check passed."
        } else {
            Write-WarningMsg "Health check reported issues: $healthResult"
        }
    } else {
        Write-WarningMsg "nord.ps1 not found at $nordScript. Cannot run health check."
    }
} catch {
    Write-LogError "Failed to run health check: $_"
}

# Step 13: Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "    NordVPN Auto-Connect Install Summary     " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($ErrorLog.Count -eq 0) {
    Write-Host "  All steps completed successfully." -ForegroundColor Green
} else {
    Write-Host "  Completed with $($ErrorLog.Count) error(s):" -ForegroundColor Yellow
    foreach ($err in $ErrorLog) {
        Write-Host "    - $err" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  Installation Directory: $NordDir" -ForegroundColor White
Write-Host "  Config Files: $ConfigDir" -ForegroundColor White
Write-Host "  SSID Configured: $WifiSSID" -ForegroundColor White

Write-Host ""
Write-Host "  Manual Steps Required (if any):" -ForegroundColor Yellow
if (-not (Test-Path "C:\Program Files\OpenVPN\bin\openvpn.exe") -and -not (Test-Path "C:\Program Files (x86)\OpenVPN\bin\openvpn.exe")) {
    Write-Host "    [ ] Install OpenVPN from https://openvpn.net/community-downloads/" -ForegroundColor Yellow
}
if (-not $NordUser -or -not $NordPass) {
    Write-Host "    [ ] Verify credentials in $AuthFile" -ForegroundColor Yellow
}
if (-not (Test-Path $registerTasksScript)) {
    Write-Host "    [ ] Register scheduled tasks manually using Register-Tasks.ps1" -ForegroundColor Yellow
}
if (-not (Test-Path $nordCmdDest)) {
    Write-Host "    [ ] Add $NordDir to your PATH or run scripts directly" -ForegroundColor Yellow
}
Write-Host "    [ ] Reboot to finalize IPv6 changes" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To test:  & `"$NordDir\nord.ps1`" health" -ForegroundColor White
Write-Host "  To connect:  & `"$NordDir\nord.ps1`" connect" -ForegroundColor White
Write-Host "  To disconnect:  & `"$NordDir\nord.ps1`" disconnect" -ForegroundColor White
Write-Host ""

if ($ErrorLog.Count -gt 0) {
    exit 1
}
