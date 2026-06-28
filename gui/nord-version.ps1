$script:version = "1.0.0"
$script:releaseDate = "2026-06-28"

function Get-Version {
    $info = @{
        version     = $script:version
        releaseDate = $script:releaseDate
        name        = "NordVPN Auto-Connect"
    }
    return $info | ConvertTo-Json
}

function Compare-Versions {
    param([string]$v1, [string]$v2)
    $parts1 = $v1 -split '\.'
    $parts2 = $v2 -split '\.'
    for ($i = 0; $i -lt [Math]::Max($parts1.Length, $parts2.Length); $i++) {
        $p1 = if ($i -lt $parts1.Length) { [int]$parts1[$i] } else { 0 }
        $p2 = if ($i -lt $parts2.Length) { [int]$parts2[$i] } else { 0 }
        if ($p1 -gt $p2) { return 1 }
        if ($p1 -lt $p2) { return -1 }
    }
    return 0
}

function Check-Update {
    $remoteUrl = "https://raw.githubusercontent.com/srikrishnadeveloper/Custom-Vpn/main/gui/nord-version.ps1"
    try {
        $remoteContent = (Invoke-WebRequest -Uri $remoteUrl -UseBasicParsing -TimeoutSec 10).Content
        $remoteScript = [System.Management.Automation.Language.Parser]::ParseInput($remoteContent, [ref]$null, [ref]$null)
        $remoteVersion = $null
        $remoteReleaseDate = $null
        foreach ($ast in $remoteScript.EndBlock.Statements) {
            if ($ast -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                $varName = $ast.Left.VariablePath.UserPath
                $varValue = $ast.Right.Value
                if ($varName -eq "version") { $remoteVersion = $varValue }
                if ($varName -eq "releaseDate") { $remoteReleaseDate = $varValue }
            }
        }
        if (-not $remoteVersion) {
            Write-Host "Unable to check"
            return
        }
        $comparison = Compare-Versions $remoteVersion $script:version
        if ($comparison -gt 0) {
            Write-Host "Update available: $remoteVersion (released $remoteReleaseDate)"
            Write-Host "Current version: $script:version"
            Write-Host "Run the following to update:"
            Write-Host "  Invoke-WebRequest -Uri '$remoteUrl' -OutFile '`$PSCommandPath'" -ForegroundColor Cyan
        } elseif ($comparison -eq 0) {
            Write-Host "You are up to date (version $script:version)"
        } else {
            Write-Host "Local version ($script:version) is newer than remote ($remoteVersion)"
        }
    } catch {
        Write-Host "Unable to check"
    }
}
