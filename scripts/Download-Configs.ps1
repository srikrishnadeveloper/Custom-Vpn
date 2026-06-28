param(
    [string]$Destination = "$env:USERPROFILE\.nordvpn\configs",
    [switch]$Force
)

$ZipUrl = "https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip"
$ZipPath = "$env:TEMP\nord-configs.zip"
$ExtractPath = "$env:TEMP\nord-configs"
$Countries = @(
    "us", "de", "nl", "gb", "ch", "se", "no", "fr", "jp",
    "ca", "au", "in", "kr", "sg", "br", "za", "it", "es", "hk", "nz"
)

Write-Host "[1/8] Creating destination folder..." -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $Destination)) {
    $null = New-Item -ItemType Directory -Path $Destination -Force
}

Write-Host "[2/8] Downloading config archive..." -ForegroundColor Cyan
try {
    $ProgressPreference = 'SilentlyContinue'
    $response = Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "  Invoke-WebRequest failed, trying curl.exe..." -ForegroundColor Yellow
    $curlResult = & curl.exe -L -o $ZipPath $ZipUrl 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download with both Invoke-WebRequest and curl.exe"
    }
}

Write-Host "[3/8] Extracting archive..." -ForegroundColor Cyan
if (Test-Path -LiteralPath $ExtractPath) {
    Remove-Item -Path $ExtractPath -Recurse -Force
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)

Write-Host "[4/8] Finding TCP configs..." -ForegroundColor Cyan
$tcpFolder = Join-Path $ExtractPath "ovpn_tcp"
if (-not (Test-Path -LiteralPath $tcpFolder)) {
    throw "ovpn_tcp folder not found in extracted archive"
}
$allConfigs = Get-ChildItem -Path $tcpFolder -Filter "*.ovpn"

Write-Host "[5/8] Filtering by country..." -ForegroundColor Cyan
$matchingConfigs = $allConfigs | Where-Object {
    $name = $_.BaseName
    $match = $false
    foreach ($country in $Countries) {
        if ($name -like "$country*") {
            $match = $true
            break
        }
    }
    $match
}

Write-Host "[6/8] Copying configs with block-outside-dns..." -ForegroundColor Cyan
$count = 0
foreach ($config in $matchingConfigs) {
    $content = Get-Content -Path $config.FullName -Raw
    $content = $content -replace '(?<=auth-user-pass\r?\n)', "block-outside-dns`r`n"
    $destFile = Join-Path $Destination $config.Name
    if ($Force -and (Test-Path -LiteralPath $destFile)) {
        Remove-Item -Path $destFile -Force
    }
    Set-Content -Path $destFile -Value $content -NoNewline
    $count++
}

Write-Host "[7/8] Cleaning up temp files..." -ForegroundColor Cyan
Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[8/8] Done!" -ForegroundColor Cyan
Write-Host "Downloaded $count NordVPN configs to: $Destination" -ForegroundColor Green
