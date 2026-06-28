@echo off
setlocal enabledelayedexpansion
set LOG=%USERPROFILE%\.nordvpn\scripts\wifi-disconnect.log
set TARGET_SSID=SSN
if not exist "%USERPROFILE%\.nordvpn\scripts\" mkdir "%USERPROFILE%\.nordvpn\scripts\" >nul 2>&1
echo [%DATE% %TIME%] Triggered >> "%LOG%" 2>&1

for /f "tokens=1,* delims=:" %%a in ('netsh wlan show interfaces 2^>nul ^| findstr /C:"SSID" ^| findstr /V /C:"BSSID"') do set "RAW=%%b"
if not defined RAW goto :nossid

set "SSID=!RAW:~1!"
if /i not "!SSID!"=="%TARGET_SSID%" (
  echo SSID=[!SSID!] not_equal [%TARGET_SSID%] - leaving VPN connected >> "%LOG%" 2>&1
  goto :eof
)
echo SSID=[!SSID!] was connected - disconnecting VPN >> "%LOG%" 2>&1
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$v=(Get-Process -Name 'openvpn' -ErrorAction SilentlyContinue) -ne $null;" ^
  "if ($v) { & '%USERPROFILE%\.nordvpn\nord.ps1' disconnect }" >> "%LOG%" 2>&1
goto :eof

:nossid
echo No SSID found - WiFi disconnected, checking Ethernet fallback >> "%LOG%" 2>&1
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$e=(Get-NetAdapter -Name 'Ethernet*' -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up') -ne $null;" ^
  "if (-not $e) { & '%USERPROFILE%\.nordvpn\nord.ps1' disconnect }" >> "%LOG%" 2>&1
