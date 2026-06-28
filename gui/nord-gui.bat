@echo off
title NordVPN Manager
if not exist "%~dp0nord-gui.ps1" (
    echo GUI script not found. Run from the correct directory.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0nord-gui.ps1"
if errorlevel 1 (
    echo Failed to launch GUI. Check PowerShell is available.
    pause
)
