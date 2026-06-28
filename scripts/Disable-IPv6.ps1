try {
    Get-NetAdapterBinding -Name "Ethernet","WiFi" -ComponentID ms_tcpip6 -ErrorAction Stop |
        Disable-NetAdapterBinding -PassThru -ErrorAction Stop

    Get-NetAdapterBinding -ComponentID ms_tcpip6 |
        Where-Object { $_.Name -match "Ethernet|WiFi" } |
        Format-Table Name, Enabled

    Write-Host "SUCCESS: IPv6 has been disabled on Ethernet and WiFi adapters." -ForegroundColor Green
}
catch {
    Write-Host "FAILURE: $_" -ForegroundColor Red
}
