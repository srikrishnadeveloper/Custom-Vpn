Add-Type -AssemblyName System.Windows.Forms,System.Drawing

$nordPs1 = "$env:USERPROFILE\.nordvpn\nord.ps1"
$authFile = "$env:USERPROFILE\.nordvpn\auth.txt"
$wifiScript = "$env:USERPROFILE\.nordvpn\on-wifi-connect.cmd"
$logDir = "$env:USERPROFILE\.nordvpn\scripts"
$selectedServer = "us"
$selectedProtocol = "tcp"
$lastCheck = Get-Date

$form = New-Object System.Windows.Forms.Form
$form.Text = "NordVPN Auto-Connect Manager"
$form.Size = New-Object System.Drawing.Size(550, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = "#1e1e1e"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

function Invoke-Nord {
    param($Args)
    try {
        if (Test-Path $nordPs1) {
            $output = & $nordPs1 $Args 2>&1
            return $output
        }
        return "nord.ps1 not found at $nordPs1"
    } catch {
        return "Error: $_"
    }
}

function Update-Status {
    $result = Invoke-Nord "status"
    $ip = ""
    $connected = $false
    foreach ($line in $result) {
        if ($line -match "Status:\s*Connected") { $connected = $true }
        if ($line -match "IP:\s*(\d+\.\d+\.\d+\.\d+)") { $ip = $matches[1] }
    }
    if ($connected -and $ip) {
        $statusLabel.Text = "Connected ($ip)"
        $statusLabel.ForeColor = "#4caf50"
        $indicator.BackColor = "#4caf50"
    } elseif ($connected) {
        $statusLabel.Text = "Connected"
        $statusLabel.ForeColor = "#4caf50"
        $indicator.BackColor = "#4caf50"
    } else {
        $statusLabel.Text = "Disconnected"
        $statusLabel.ForeColor = "#f44336"
        $indicator.BackColor = "#f44336"
    }
    $now = Get-Date
    $diff = $now - $lastCheck
    if ($diff.TotalMinutes -lt 1) {
        $statusBar.Text = "Last check: just now"
    } else {
        $statusBar.Text = "Last check: $([math]::Floor($diff.TotalMinutes)) min ago"
    }
    $lastCheck = $now
}

function Invoke-Connect {
    $connStr = "$selectedServer -$selectedProtocol"
    Invoke-Nord $connStr
    Update-Status
}

function Invoke-Disconnect {
    Invoke-Nord "disconnect"
    Update-Status
}

function Invoke-Reconnect {
    Invoke-Nord "reconnect"
    Update-Status
}

function Show-SettingsDialog {
    $sForm = New-Object System.Windows.Forms.Form
    $sForm.Text = "NordVPN Settings"
    $sForm.Size = New-Object System.Drawing.Size(350, 250)
    $sForm.StartPosition = "CenterParent"
    $sForm.FormBorderStyle = "FixedDialog"
    $sForm.MaximizeBox = $false
    $sForm.MinimizeBox = $false
    $sForm.BackColor = "#1e1e1e"
    $sForm.ForeColor = "White"

    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Text = "NordVPN Username:"
    $userLabel.Location = New-Object System.Drawing.Point(12, 15)
    $userLabel.Size = New-Object System.Drawing.Size(120, 20)
    $userLabel.ForeColor = "White"

    $userBox = New-Object System.Windows.Forms.TextBox
    $userBox.Location = New-Object System.Drawing.Point(140, 12)
    $userBox.Size = New-Object System.Drawing.Size(190, 22)
    $userBox.BackColor = "#2d2d2d"
    $userBox.ForeColor = "White"
    $userBox.BorderStyle = "FixedSingle"
    if (Test-Path $authFile) {
        $lines = Get-Content $authFile -ErrorAction SilentlyContinue
        if ($lines.Count -ge 1) { $userBox.Text = $lines[0] }
    }

    $passLabel = New-Object System.Windows.Forms.Label
    $passLabel.Text = "NordVPN Password:"
    $passLabel.Location = New-Object System.Drawing.Point(12, 45)
    $passLabel.Size = New-Object System.Drawing.Size(120, 20)
    $passLabel.ForeColor = "White"

    $passBox = New-Object System.Windows.Forms.TextBox
    $passBox.Location = New-Object System.Drawing.Point(140, 42)
    $passBox.Size = New-Object System.Drawing.Size(190, 22)
    $passBox.BackColor = "#2d2d2d"
    $passBox.ForeColor = "White"
    $passBox.BorderStyle = "FixedSingle"
    $passBox.UseSystemPasswordChar = $true
    if (Test-Path $authFile) {
        $lines = Get-Content $authFile -ErrorAction SilentlyContinue
        if ($lines.Count -ge 2) { $passBox.Text = $lines[1] }
    }

    $wifiLabel = New-Object System.Windows.Forms.Label
    $wifiLabel.Text = "Target WiFi SSID:"
    $wifiLabel.Location = New-Object System.Drawing.Point(12, 75)
    $wifiLabel.Size = New-Object System.Drawing.Size(120, 20)
    $wifiLabel.ForeColor = "White"

    $wifiBox = New-Object System.Windows.Forms.TextBox
    $wifiBox.Location = New-Object System.Drawing.Point(140, 72)
    $wifiBox.Size = New-Object System.Drawing.Size(190, 22)
    $wifiBox.BackColor = "#2d2d2d"
    $wifiBox.ForeColor = "White"
    $wifiBox.BorderStyle = "FixedSingle"
    $wifiBox.Text = "AMPLIFIER_EXT"

    $saveBtn = New-Object System.Windows.Forms.Button
    $saveBtn.Text = "Save"
    $saveBtn.Location = New-Object System.Drawing.Point(140, 110)
    $saveBtn.Size = New-Object System.Drawing.Size(90, 28)
    $saveBtn.BackColor = "#0078d4"
    $saveBtn.ForeColor = "White"
    $saveBtn.FlatStyle = "Flat"
    $saveBtn.Add_Click({
        try {
            "$($userBox.Text)`n$($passBox.Text)" | Out-File $authFile -Encoding ascii
            $cmdContent = "@echo off`r`nif `"%SSID%`"==`"$($wifiBox.Text)`" (`r`npowershell -NoProfile -WindowStyle Hidden -File `"$nordPs1`" us -tcp`r`n)"
            $cmdContent | Out-File $wifiScript -Encoding ascii
            [System.Windows.Forms.MessageBox]::Show("Settings saved successfully.", "NordVPN", "OK", "Information")
            $sForm.Close()
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error saving settings: $_", "Error", "OK", "Error")
        }
    })

    $sForm.Controls.AddRange(@($userLabel, $userBox, $passLabel, $passBox, $wifiLabel, $wifiBox, $saveBtn))
    $sForm.ShowDialog()
}

function Update-MonitorStatus {
    $result = Invoke-Nord "monitor status"
    $monitoring = $false
    $remaining = ""
    foreach ($line in $result) {
        if ($line -match "running") { $monitoring = $true }
        if ($line -match "all tasks ready" -or $line -match "remaining") { $remaining = $line }
    }
    if ($monitoring) {
        $monitorOnBtn.BackColor = "#0078d4"
        $monitorOffBtn.BackColor = "#2d2d2d"
        $taskStatus.Text = "Status: $($remaining.Trim())"
        $taskStatus.ForeColor = "White"
    } else {
        $monitorOnBtn.BackColor = "#2d2d2d"
        $monitorOffBtn.BackColor = "#d32f2f"
        $taskStatus.Text = "Status: Not Running"
        $taskStatus.ForeColor = "#ffab00"
    }
}

$y = 0

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "NordVPN Auto-Connect Manager"
$titleLabel.Location = New-Object System.Drawing.Point(10, 8)
$titleLabel.Size = New-Object System.Drawing.Size(520, 26)
$titleLabel.ForeColor = "#0078d4"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$titleLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($titleLabel)
$y = 40

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(10, $y)
$statusPanel.Size = New-Object System.Drawing.Size(520, 40)
$statusPanel.BackColor = "#2d2d2d"
$form.Controls.Add($statusPanel)

$indicator = New-Object System.Windows.Forms.Label
$indicator.Location = New-Object System.Drawing.Point(12, 10)
$indicator.Size = New-Object System.Drawing.Size(20, 20)
$indicator.BackColor = "#f44336"
$statusPanel.Controls.Add($indicator)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Checking..."
$statusLabel.Location = New-Object System.Drawing.Point(40, 8)
$statusLabel.Size = New-Object System.Drawing.Size(350, 24)
$statusLabel.ForeColor = "White"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statusPanel.Controls.Add($statusLabel)

$refreshBtn = New-Object System.Windows.Forms.Button
$refreshBtn.Text = "Refresh"
$refreshBtn.Location = New-Object System.Drawing.Point(430, 7)
$refreshBtn.Size = New-Object System.Drawing.Size(75, 26)
$refreshBtn.BackColor = "#0078d4"
$refreshBtn.ForeColor = "White"
$refreshBtn.FlatStyle = "Flat"
$refreshBtn.Add_Click({ Update-Status })
$statusPanel.Controls.Add($refreshBtn)

$y += 50

$connLabel = New-Object System.Windows.Forms.Label
$connLabel.Text = "Connection"
$connLabel.Location = New-Object System.Drawing.Point(10, $y)
$connLabel.Size = New-Object System.Drawing.Size(520, 20)
$connLabel.ForeColor = "#0078d4"
$connLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($connLabel)
$y += 22

$connectBtn = New-Object System.Windows.Forms.Button
$connectBtn.Text = "Connect"
$connectBtn.Location = New-Object System.Drawing.Point(10, $y)
$connectBtn.Size = New-Object System.Drawing.Size(90, 32)
$connectBtn.BackColor = "#107c10"
$connectBtn.ForeColor = "White"
$connectBtn.FlatStyle = "Flat"
$connectBtn.Add_Click({ Invoke-Connect })
$form.Controls.Add($connectBtn)

$disconnectBtn = New-Object System.Windows.Forms.Button
$disconnectBtn.Text = "Disconnect"
$disconnectBtn.Location = New-Object System.Drawing.Point(108, $y)
$disconnectBtn.Size = New-Object System.Drawing.Size(90, 32)
$disconnectBtn.BackColor = "#d32f2f"
$disconnectBtn.ForeColor = "White"
$disconnectBtn.FlatStyle = "Flat"
$disconnectBtn.Add_Click({ Invoke-Disconnect })
$form.Controls.Add($disconnectBtn)

$reconnectBtn = New-Object System.Windows.Forms.Button
$reconnectBtn.Text = "Reconnect"
$reconnectBtn.Location = New-Object System.Drawing.Point(206, $y)
$reconnectBtn.Size = New-Object System.Drawing.Size(90, 32)
$reconnectBtn.BackColor = "#ff8c00"
$reconnectBtn.ForeColor = "White"
$reconnectBtn.FlatStyle = "Flat"
$reconnectBtn.Add_Click({ Invoke-Reconnect })
$form.Controls.Add($reconnectBtn)

$y += 40

$serverLabel = New-Object System.Windows.Forms.Label
$serverLabel.Text = "Server:"
$serverLabel.Location = New-Object System.Drawing.Point(10, $y)
$serverLabel.Size = New-Object System.Drawing.Size(50, 24)
$serverLabel.ForeColor = "White"
$serverLabel.TextAlign = "MiddleLeft"
$form.Controls.Add($serverLabel)

$serverCombo = New-Object System.Windows.Forms.ComboBox
$serverCombo.Location = New-Object System.Drawing.Point(60, $y)
$serverCombo.Size = New-Object System.Drawing.Size(100, 24)
$serverCombo.BackColor = "#2d2d2d"
$serverCombo.ForeColor = "White"
$serverCombo.DropDownStyle = "DropDownList"
$countries = @("us","de","nl","gb","ch","se","no","fr","jp","ca","au","in","kr","sg","br","za","it","es","hk","nz")
foreach ($c in $countries) { $serverCombo.Items.Add($c) }
$serverCombo.SelectedIndex = 0
$serverCombo.Add_SelectedIndexChanged({ $selectedServer = $serverCombo.Text })
$form.Controls.Add($serverCombo)

$tcpBtn = New-Object System.Windows.Forms.Button
$tcpBtn.Text = "TCP"
$tcpBtn.Location = New-Object System.Drawing.Point(175, $y)
$tcpBtn.Size = New-Object System.Drawing.Size(50, 24)
$tcpBtn.BackColor = "#0078d4"
$tcpBtn.ForeColor = "White"
$tcpBtn.FlatStyle = "Flat"
$tcpBtn.Add_Click({
    $selectedProtocol = "tcp"
    $tcpBtn.BackColor = "#0078d4"
    $udpBtn.BackColor = "#2d2d2d"
})
$form.Controls.Add($tcpBtn)

$udpBtn = New-Object System.Windows.Forms.Button
$udpBtn.Text = "UDP"
$udpBtn.Location = New-Object System.Drawing.Point(230, $y)
$udpBtn.Size = New-Object System.Drawing.Size(50, 24)
$udpBtn.BackColor = "#2d2d2d"
$udpBtn.ForeColor = "White"
$udpBtn.FlatStyle = "Flat"
$udpBtn.Add_Click({
    $selectedProtocol = "udp"
    $udpBtn.BackColor = "#0078d4"
    $tcpBtn.BackColor = "#2d2d2d"
})
$form.Controls.Add($udpBtn)

$y += 32

$autoLabel = New-Object System.Windows.Forms.Label
$autoLabel.Text = "Auto-Connect"
$autoLabel.Location = New-Object System.Drawing.Point(10, $y)
$autoLabel.Size = New-Object System.Drawing.Size(520, 20)
$autoLabel.ForeColor = "#0078d4"
$autoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($autoLabel)
$y += 22

$monitorOnBtn = New-Object System.Windows.Forms.Button
$monitorOnBtn.Text = "Monitor: ON"
$monitorOnBtn.Location = New-Object System.Drawing.Point(10, $y)
$monitorOnBtn.Size = New-Object System.Drawing.Size(100, 28)
$monitorOnBtn.BackColor = "#2d2d2d"
$monitorOnBtn.ForeColor = "White"
$monitorOnBtn.FlatStyle = "Flat"
$monitorOnBtn.Add_Click({
    Invoke-Nord "monitor enable"
    $monitorOnBtn.BackColor = "#0078d4"
    $monitorOffBtn.BackColor = "#2d2d2d"
    $taskStatus.Text = "Tasks: All Ready"
    $taskStatus.ForeColor = "White"
})
$form.Controls.Add($monitorOnBtn)

$monitorOffBtn = New-Object System.Windows.Forms.Button
$monitorOffBtn.Text = "Monitor: OFF"
$monitorOffBtn.Location = New-Object System.Drawing.Point(118, $y)
$monitorOffBtn.Size = New-Object System.Drawing.Size(100, 28)
$monitorOffBtn.BackColor = "#d32f2f"
$monitorOffBtn.ForeColor = "White"
$monitorOffBtn.FlatStyle = "Flat"
$monitorOffBtn.Add_Click({
    Invoke-Nord "monitor disable"
    $monitorOffBtn.BackColor = "#d32f2f"
    $monitorOnBtn.BackColor = "#2d2d2d"
    $taskStatus.Text = "Monitor: Disabled"
    $taskStatus.ForeColor = "#ffab00"
})
$form.Controls.Add($monitorOffBtn)

$taskStatus = New-Object System.Windows.Forms.Label
$taskStatus.Text = "Status: Checking..."
$taskStatus.Location = New-Object System.Drawing.Point(230, $y)
$taskStatus.Size = New-Object System.Drawing.Size(290, 28)
$taskStatus.ForeColor = "White"
$taskStatus.TextAlign = "MiddleLeft"
$form.Controls.Add($taskStatus)

$y += 36

$actionLabel = New-Object System.Windows.Forms.Label
$actionLabel.Text = "Actions"
$actionLabel.Location = New-Object System.Drawing.Point(10, $y)
$actionLabel.Size = New-Object System.Drawing.Size(520, 20)
$actionLabel.ForeColor = "#0078d4"
$actionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($actionLabel)
$y += 22

$healthBtn = New-Object System.Windows.Forms.Button
$healthBtn.Text = "Health Check"
$healthBtn.Location = New-Object System.Drawing.Point(10, $y)
$healthBtn.Size = New-Object System.Drawing.Size(110, 30)
$healthBtn.BackColor = "#0078d4"
$healthBtn.ForeColor = "White"
$healthBtn.FlatStyle = "Flat"
$healthBtn.Add_Click({
    $result = Invoke-Nord "health"
    $msg = $result | Out-String
    [System.Windows.Forms.MessageBox]::Show($msg, "NordVPN Health Check", "OK", "Information")
})
$form.Controls.Add($healthBtn)

$logsBtn = New-Object System.Windows.Forms.Button
$logsBtn.Text = "View Logs"
$logsBtn.Location = New-Object System.Drawing.Point(128, $y)
$logsBtn.Size = New-Object System.Drawing.Size(110, 30)
$logsBtn.BackColor = "#0078d4"
$logsBtn.ForeColor = "White"
$logsBtn.FlatStyle = "Flat"
$logsBtn.Add_Click({
    if (Test-Path $logDir) {
        Start-Process explorer.exe $logDir
    } else {
        [System.Windows.Forms.MessageBox]::Show("Logs directory not found at $logDir", "NordVPN", "OK", "Warning")
    }
})
$form.Controls.Add($logsBtn)

$settingsBtn = New-Object System.Windows.Forms.Button
$settingsBtn.Text = "Settings"
$settingsBtn.Location = New-Object System.Drawing.Point(246, $y)
$settingsBtn.Size = New-Object System.Drawing.Size(110, 30)
$settingsBtn.BackColor = "#0078d4"
$settingsBtn.ForeColor = "White"
$settingsBtn.FlatStyle = "Flat"
$settingsBtn.Add_Click({ Show-SettingsDialog })
$form.Controls.Add($settingsBtn)

$y += 40

$sep = New-Object System.Windows.Forms.Label
$sep.Location = New-Object System.Drawing.Point(10, $y)
$sep.Size = New-Object System.Drawing.Size(520, 1)
$sep.BackColor = "#3d3d3d"
$sep.BorderStyle = "FixedSingle"
$form.Controls.Add($sep)
$y += 8

$statusBar = New-Object System.Windows.Forms.Label
$statusBar.Text = "Last check: just now"
$statusBar.Location = New-Object System.Drawing.Point(10, $y)
$statusBar.Size = New-Object System.Drawing.Size(520, 20)
$statusBar.ForeColor = "#aaaaaa"
$statusBar.TextAlign = "MiddleLeft"
$form.Controls.Add($statusBar)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000
$timer.Add_Tick({ Update-Status; Update-MonitorStatus })
$timer.Start()

Update-Status
Update-MonitorStatus

[System.Windows.Forms.Application]::Run($form)
