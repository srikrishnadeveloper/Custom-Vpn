@echo off
setlocal
if /i not "%1"=="monitor" goto :run
if /i "%2"=="" (
  echo Auto-Connect Monitor:
  schtasks /query /tn "NordVPN-Ethernet-Connect" 2>nul | findstr /R "Ready" >nul 2>&1
  if errorlevel 1 (echo   Ethernet: DISABLED) else (echo   Ethernet: ACTIVE)
  schtasks /query /tn "NordVPN-WiFi-Connect" 2>nul | findstr /R "Ready" >nul 2>&1
  if errorlevel 1 (echo   WiFi-SSN: DISABLED) else (echo   WiFi-SSN: ACTIVE)
  goto :eof
)
if /i "%2"=="enable" (
  schtasks /change /tn "NordVPN-Ethernet-Connect" /enable >nul 2>&1
  schtasks /change /tn "NordVPN-Ethernet-Disconnect" /enable >nul 2>&1
  schtasks /change /tn "NordVPN-WiFi-Connect" /enable >nul 2>&1
  schtasks /change /tn "NordVPN-WiFi-Disconnect" /enable >nul 2>&1
  echo Monitor: enabled ^(Ethernet + WiFi SSN^)
  goto :eof
)
if /i "%2"=="disable" (
  schtasks /change /tn "NordVPN-Ethernet-Connect" /disable >nul 2>&1
  schtasks /change /tn "NordVPN-Ethernet-Disconnect" /disable >nul 2>&1
  schtasks /change /tn "NordVPN-WiFi-Connect" /disable >nul 2>&1
  schtasks /change /tn "NordVPN-WiFi-Disconnect" /disable >nul 2>&1
  echo Monitor: disabled
  goto :eof
)
goto :eof

:run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.nordvpn\nord.ps1" %*
