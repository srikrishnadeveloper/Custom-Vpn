@echo off
setlocal
set LOG=%USERPROFILE%\.nordvpn\scripts\disconnect.log
if not exist "%USERPROFILE%\.nordvpn\scripts\" mkdir "%USERPROFILE%\.nordvpn\scripts\" >nul 2>&1
echo [%DATE% %TIME%] Triggered >> "%LOG%" 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$e=(Get-NetAdapter -Name 'Ethernet*' -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up') -ne $null;" ^
  "$v=(Get-Process -Name 'openvpn' -ErrorAction SilentlyContinue) -ne $null;" ^
  "if ($e -or -not $v) { exit 0 }" ^
  "$w=(Get-NetAdapter -Name 'WiFi' -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up') -ne $null;" ^
  "if ($w) { exit 0 }" ^
  "& '%USERPROFILE%\.nordvpn\nord.ps1' disconnect" >> "%LOG%" 2>&1
