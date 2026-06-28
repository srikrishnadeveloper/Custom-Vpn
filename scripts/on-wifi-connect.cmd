@echo off
setlocal
set LOG=%USERPROFILE%\.nordvpn\scripts\wifi-connect.log
set TARGET_SSID=SSN
if not exist "%USERPROFILE%\.nordvpn\scripts\" mkdir "%USERPROFILE%\.nordvpn\scripts\" >nul 2>&1
echo [%DATE% %TIME%] Triggered >> "%LOG%" 2>&1

for /f "tokens=1,* delims=:" %%a in ('netsh wlan show interfaces 2^>nul ^| findstr /C:"SSID" ^| findstr /V /C:"BSSID"') do set "RAW=%%b"
if not defined RAW (
  echo No SSID found >> "%LOG%" 2>&1
  exit /b 0
)
set "SSID=%RAW:~1%"
if /i not "%SSID%"=="%TARGET_SSID%" (
  echo SSID=[%SSID%] != [%TARGET_SSID%] - skipped >> "%LOG%" 2>&1
  exit /b 0
)
echo SSID=[%SSID%] match [%TARGET_SSID%] >> "%LOG%" 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$v=(Get-Process -Name 'openvpn' -ErrorAction SilentlyContinue) -ne $null;" ^
  "if (-not $v) { & '%USERPROFILE%\.nordvpn\nord.ps1' us -tcp }" >> "%LOG%" 2>&1
