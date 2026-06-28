@echo off
setlocal
set LOG=%USERPROFILE%\.nordvpn\scripts\connect.log
if not exist "%USERPROFILE%\.nordvpn\scripts\" mkdir "%USERPROFILE%\.nordvpn\scripts\" >nul 2>&1
echo [%DATE% %TIME%] Triggered >> "%LOG%" 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$e=(Get-NetAdapter -Name 'Ethernet*' -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up') -ne $null;" ^
  "$v=(Get-Process -Name 'openvpn' -ErrorAction SilentlyContinue) -ne $null;" ^
  "if ($e -and -not $v) { & '%USERPROFILE%\.nordvpn\nord.ps1' us -tcp }" >> "%LOG%" 2>&1
