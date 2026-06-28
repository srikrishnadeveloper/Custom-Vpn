param(
    [switch]$Disable
)

$scriptsDir = "$env:USERPROFILE\.nordvpn\scripts"
$nordPs1 = "$env:USERPROFILE\.nordvpn\nord.ps1"
$username = $env:USERNAME
$tasks = @(
    @{Name='NordVPN-Ethernet-Connect'; Cmd='on-network-connect.cmd'}
    @{Name='NordVPN-WiFi-Connect'; Cmd='on-wifi-connect.cmd'}
    @{Name='NordVPN-Ethernet-Disconnect'; Cmd='on-network-disconnect.cmd'}
    @{Name='NordVPN-WiFi-Disconnect'; Cmd='on-wifi-disconnect.cmd'}
    @{Name='NordVPN-Watchdog'; Cmd='watchdog.cmd'}
)

function Disable-AllTasks {
    Write-Host "Disabling all NordVPN tasks..." -ForegroundColor Yellow
    foreach ($t in $tasks) {
        $taskName = $t.Name
        $taskPath = "\$taskName"
        $existing = schtasks /query /tn $taskPath 2>$null
        if ($LASTEXITCODE -eq 0) {
            schtasks /change /tn $taskPath /disable
            Write-Host "  Disabled: $taskName" -ForegroundColor Gray
        } else {
            Write-Host "  Not found: $taskName" -ForegroundColor DarkGray
        }
    }
    Write-Host "All tasks disabled." -ForegroundColor Green
}

if ($Disable) {
    Disable-AllTasks
    exit 0
}

Write-Host "Registering NordVPN Task Scheduler tasks..." -ForegroundColor Cyan

foreach ($t in $tasks) {
    $taskName = $t.Name
    $taskPath = "\$taskName"
    $cmd = $t.Cmd

    schtasks /delete /f /tn $taskPath 2>$null
    if ($LASTEXITCODE -eq 0 -or $true) { $null = $true }
}

function New-TaskXml {
    param([string]$TaskName)

    $actionCmd = "%USERPROFILE%\.nordvpn\scripts\$($scriptsDir -replace '.*\\','')"
    if ($TaskName -eq 'NordVPN-Ethernet-Connect') {
        $cmd
    } elseif ($TaskName -eq 'NordVPN-WiFi-Connect') {
        $cmd
    } else {
        $cmd
    }
}

$ethernetConnectXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Connects NordVPN when Ethernet network connects</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT30S</Delay>
    </BootTrigger>
    <SessionStateChangeTrigger>
      <Enabled>true</Enabled>
      <StateChange>8</StateChange>
    </SessionStateChangeTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000 and (Level=4 or Level=0)]] and *[EventData[Data[@Name='InterfaceType']='0']]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$username</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <Enabled>true</Enabled>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <StartWhenAvailable>true</StartWhenAvailable>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c "%USERPROFILE%\.nordvpn\scripts\on-network-connect.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$wifiConnectXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Connects NordVPN when WiFi network connects</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT30S</Delay>
    </BootTrigger>
    <SessionStateChangeTrigger>
      <Enabled>true</Enabled>
      <StateChange>8</StateChange>
    </SessionStateChangeTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000 and (Level=4 or Level=0)]] and *[EventData[Data[@Name='InterfaceType']='1']]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$username</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <Enabled>true</Enabled>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <StartWhenAvailable>true</StartWhenAvailable>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c "%USERPROFILE%\.nordvpn\scripts\on-wifi-connect.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$ethernetDisconnectXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Disconnects NordVPN when Ethernet disconnects</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10001 and (Level=4 or Level=0)]] and *[EventData[Data[@Name='InterfaceType']='0']]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$username</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <Enabled>true</Enabled>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <StartWhenAvailable>true</StartWhenAvailable>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c "%USERPROFILE%\.nordvpn\scripts\on-network-disconnect.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$wifiDisconnectXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Disconnects NordVPN when WiFi disconnects</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10001 and (Level=4 or Level=0)]] and *[EventData[Data[@Name='InterfaceType']='1']]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$username</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <Enabled>true</Enabled>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <StartWhenAvailable>true</StartWhenAvailable>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c "%USERPROFILE%\.nordvpn\scripts\on-wifi-disconnect.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$watchdogXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>NordVPN connectivity watchdog - checks VPN status every 5 minutes</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <Enabled>true</Enabled>
      <StartBoundary>2024-01-01T00:00:00</StartBoundary>
      <Repetition>
        <Interval>PT5M</Interval>
        <Duration>P1D</Duration>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$username</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <Enabled>true</Enabled>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <StartWhenAvailable>true</StartWhenAvailable>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c "%USERPROFILE%\.nordvpn\scripts\watchdog.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Write-Host "Creating NordVPN-Ethernet-Connect..." -ForegroundColor Cyan
$tmp = "$env:TEMP\_task_ethernet_connect.xml"
$ethernetConnectXml | Out-File -FilePath $tmp -Encoding Unicode
schtasks /create /tn "\NordVPN-Ethernet-Connect" /xml $tmp /ru $username /f
Remove-Item $tmp -Force

Write-Host "Creating NordVPN-WiFi-Connect..." -ForegroundColor Cyan
$tmp = "$env:TEMP\_task_wifi_connect.xml"
$wifiConnectXml | Out-File -FilePath $tmp -Encoding Unicode
schtasks /create /tn "\NordVPN-WiFi-Connect" /xml $tmp /ru $username /f
Remove-Item $tmp -Force

Write-Host "Creating NordVPN-Ethernet-Disconnect..." -ForegroundColor Cyan
$tmp = "$env:TEMP\_task_ethernet_disconnect.xml"
$ethernetDisconnectXml | Out-File -FilePath $tmp -Encoding Unicode
schtasks /create /tn "\NordVPN-Ethernet-Disconnect" /xml $tmp /ru $username /f
Remove-Item $tmp -Force

Write-Host "Creating NordVPN-WiFi-Disconnect..." -ForegroundColor Cyan
$tmp = "$env:TEMP\_task_wifi_disconnect.xml"
$wifiDisconnectXml | Out-File -FilePath $tmp -Encoding Unicode
schtasks /create /tn "\NordVPN-WiFi-Disconnect" /xml $tmp /ru $username /f
Remove-Item $tmp -Force

Write-Host "Creating NordVPN-Watchdog..." -ForegroundColor Cyan
$tmp = "$env:TEMP\_task_watchdog.xml"
$watchdogXml | Out-File -FilePath $tmp -Encoding Unicode
schtasks /create /tn "\NordVPN-Watchdog" /xml $tmp /ru $username /f
Remove-Item $tmp -Force

Write-Host "SUCCESS: All 5 NordVPN tasks registered." -ForegroundColor Green
