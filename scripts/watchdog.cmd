@echo off
setlocal
set LOG=%USERPROFILE%\.nordvpn\scripts\watchdog.log
set TARGET_SSID=SSN

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$e=(Get-NetAdapter -Name 'Ethernet*' -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up') -ne $null;" ^
  "$w=(netsh wlan show interfaces 2>$null | findstr /C:\"SSID\" | findstr /V /C:\"BSSID\") -match '%TARGET_SSID%';" ^
  "$v=(Get-Process -Name 'openvpn' -ErrorAction SilentlyContinue) -ne $null;" ^
  "if (($e -or $w) -and -not $v) { & '%USERPROFILE%\.nordvpn\nord.ps1' us -tcp }" >> "%LOG%" 2>&1
