Add-Type -AssemblyName System.Windows.Forms, System.Drawing

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $ps = [PowerShell]::Create()
    $ps.AddScript("& '$PSCommandPath'")
    $ps.BeginInvoke()
    return
}

$nordPs1 = "$env:USERPROFILE\.nordvpn\nord.ps1"
$authFile = "$env:USERPROFILE\.nordvpn\auth.txt"
$wifiScript = "$env:USERPROFILE\.nordvpn\on-wifi-connect.cmd"
$logDir = "$env:USERPROFILE\.nordvpn\scripts"
$srv = "us"; $proto = "tcp"; $lastCheck = Get-Date; $exiting = $false

$form = New-Object System.Windows.Forms.Form
$form.Text = "NordVPN Auto-Connect Manager"
$form.Size = New-Object System.Drawing.Size -ArgumentList 560,520
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font -ArgumentList "Segoe UI",9

function B($p,$t,$loc,$sz,$col,$fn) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $t
    $b.Location = New-Object System.Drawing.Point -ArgumentList $loc
    $b.Size = New-Object System.Drawing.Size -ArgumentList $sz
    $c = $col -split ','; $b.BackColor = [System.Drawing.Color]::FromArgb([int]$c[0],[int]$c[1],[int]$c[2])
    $b.ForeColor = [System.Drawing.Color]::White; $b.FlatStyle = "Flat"
    if ($fn) { $b.Add_Click($fn) }
    if ($p) { $p.Controls.Add($b) } else { $form.Controls.Add($b) }
    return $b
}

function L($p,$t,$loc,$sz,$col) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $t
    $l.Location = New-Object System.Drawing.Point -ArgumentList $loc
    $l.Size = New-Object System.Drawing.Size -ArgumentList $sz
    if ($col -and $col -ne "") { $c = $col -split ','; $l.ForeColor = [System.Drawing.Color]::FromArgb([int]$c[0],[int]$c[1],[int]$c[2]) }
    if ($p) { $p.Controls.Add($l) } else { $form.Controls.Add($l) }
    return $l
}

function Invoke-Nord {
    param([string[]]$Arguments)
    try {
        if (Test-Path $nordPs1) { return & $nordPs1 $Arguments 2>&1 }
        return "nord.ps1 not found"
    }
    catch { return "Error: $_" }
}

function Update-Status {
    try {
        $r = Invoke-Nord "status"
        $statusText = ""
        foreach ($l in $r) { $statusText += "$l " }
        $statusText = $statusText.Trim()
        if ($statusText -match "Connected") {
            $ip = ""
            if ($statusText -match "\((\d+\.\d+\.\d+\.\d+)\)") { $ip = $matches[1] }
            if ($ip) { $statusLabel.Text = "Connected ($ip)" } else { $statusLabel.Text = "Connected" }
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(76,175,80)
            $indicator.BackColor = [System.Drawing.Color]::FromArgb(76,175,80)
        }
        else {
            $statusLabel.Text = "Disconnected"
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(244,67,54)
            $indicator.BackColor = [System.Drawing.Color]::FromArgb(244,67,54)
        }
        $d = (Get-Date) - $lastCheck
        if($d.TotalMinutes -lt 1){$statusBar.Text="Last check: just now"}else{$statusBar.Text="Last check: $([math]::Floor($d.TotalMinutes)) min ago"}
        $lastCheck = Get-Date
    }
    catch { $statusBar.Text = "Error: $_" }
}

function Invoke-Connect { Invoke-Nord @($srv, "-$proto"); Update-Status }
function Invoke-Disconnect { Invoke-Nord "disconnect"; Update-Status }
function Invoke-Reconnect { Invoke-Nord "reconnect"; Update-Status }

function Show-SettingsDialog {
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "NordVPN Settings"
    $sf.Size = New-Object System.Drawing.Size -ArgumentList 360,260
    $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "FixedDialog"; $sf.MaximizeBox = $false; $sf.MinimizeBox = $false
    $sf.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
    L $sf "NordVPN Username:" (12,15) (120,20) "255,255,255"
    $ub = New-Object System.Windows.Forms.TextBox; $ub.Location=New-Object System.Drawing.Point -ArgumentList 140,12; $ub.Size=New-Object System.Drawing.Size -ArgumentList 190,22
    $ub.BackColor=[System.Drawing.Color]::FromArgb(45,45,45); $ub.ForeColor=[System.Drawing.Color]::White; $ub.BorderStyle="FixedSingle"; $sf.Controls.Add($ub)
    L $sf "NordVPN Password:" (12,45) (120,20) "255,255,255"
    $pb = New-Object System.Windows.Forms.TextBox; $pb.Location=New-Object System.Drawing.Point -ArgumentList 140,42; $pb.Size=New-Object System.Drawing.Size -ArgumentList 190,22
    $pb.BackColor=[System.Drawing.Color]::FromArgb(45,45,45); $pb.ForeColor=[System.Drawing.Color]::White; $pb.BorderStyle="FixedSingle"; $pb.UseSystemPasswordChar=$true; $sf.Controls.Add($pb)
    L $sf "Target WiFi SSID:" (12,75) (120,20) "255,255,255"
    $wb = New-Object System.Windows.Forms.TextBox; $wb.Location=New-Object System.Drawing.Point -ArgumentList 140,72; $wb.Size=New-Object System.Drawing.Size -ArgumentList 190,22
    $wb.BackColor=[System.Drawing.Color]::FromArgb(45,45,45); $wb.ForeColor=[System.Drawing.Color]::White; $wb.BorderStyle="FixedSingle"; $wb.Text="SSN"; $sf.Controls.Add($wb)
    if (Test-Path $authFile) { $ln = Get-Content $authFile -ErrorAction SilentlyContinue; if ($ln.Count -ge 1) { $ub.Text = $ln[0] }; if ($ln.Count -ge 2) { $pb.Text = $ln[1] } }
    B $sf "Save" (90,110) (140,30) "0,120,212" {
        try {
            "$($ub.Text)`n$($pb.Text)" | Out-File $authFile -Encoding ascii
            [System.Windows.Forms.MessageBox]::Show("Settings saved.", "NordVPN","OK","Information"); $sf.Close()
        } catch { [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error","OK","Error") }
    }
    $sf.ShowDialog()
}

function Update-MonitorStatus {
    try {
        $r = Invoke-Nord "monitor status"; $on = $false; $rem = ""
        foreach ($l in $r) { if ($l -match "running") { $on = $true }; if ($l -match "all tasks ready" -or $l -match "remaining") { $rem = $l.Trim() } }
        if ($on) { $monOn.BackColor=[System.Drawing.Color]::FromArgb(0,120,212); $monOff.BackColor=[System.Drawing.Color]::FromArgb(45,45,45); $taskSt.Text="Status: $rem"; $taskSt.ForeColor=[System.Drawing.Color]::White }
        else { $monOn.BackColor=[System.Drawing.Color]::FromArgb(45,45,45); $monOff.BackColor=[System.Drawing.Color]::FromArgb(211,47,47); $taskSt.Text="Status: Not Running"; $taskSt.ForeColor=[System.Drawing.Color]::FromArgb(255,171,0) }
    }
    catch { $taskSt.Text = "Error: $_" }
}

L $null "NordVPN Auto-Connect Manager" (10,10) (520,30) "0,120,212"

L $null "" (10,45) (520,1) "80,80,80"

L $null "Status:" (10,55) (60,20) "255,255,255"
$indicator = L $null "" (75,55) (16,16) "244,67,54"
$statusLabel = L $null "Checking..." (95,55) (340,20) "255,255,255"
B $null "Refresh" (440,50) (80,28) "0,120,212" { try { Update-Status } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }

L $null "Connection" (10,85) (520,20) "0,120,212"
B $null "Connect" (10,110) (90,30) "16,124,16" { try { Invoke-Connect } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
B $null "Disconnect" (110,110) (100,30) "211,47,47" { try { Invoke-Disconnect } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
B $null "Reconnect" (220,110) (100,30) "255,140,0" { try { Invoke-Reconnect } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }

L $null "Server:" (10,155) (50,20) "255,255,255"
$sc = New-Object System.Windows.Forms.ComboBox; $sc.Location=New-Object System.Drawing.Point -ArgumentList 65,152; $sc.Size=New-Object System.Drawing.Size -ArgumentList 100,24
$sc.BackColor=[System.Drawing.Color]::FromArgb(45,45,45); $sc.ForeColor=[System.Drawing.Color]::White; $sc.DropDownStyle="DropDownList"
@("us","de","nl","gb","ch","se","no","fr","jp","ca","au","in","kr","sg","br","za","it","es","hk","nz")|%{$sc.Items.Add($_)}
$sc.SelectedIndex=0; $sc.Add_SelectedIndexChanged({$srv=$sc.Text}); $form.Controls.Add($sc)

$tcpBtn = B $null "TCP" (175,152) (50,24) "0,120,212" { $proto="tcp"; $tcpBtn.BackColor=[System.Drawing.Color]::FromArgb(0,120,212); $udpBtn.BackColor=[System.Drawing.Color]::FromArgb(45,45,45) }
$udpBtn = B $null "UDP" (235,152) (50,24) "45,45,45" { $proto="udp"; $udpBtn.BackColor=[System.Drawing.Color]::FromArgb(0,120,212); $tcpBtn.BackColor=[System.Drawing.Color]::FromArgb(45,45,45) }

L $null "Auto-Connect" (10,190) (520,20) "0,120,212"
$monOn = B $null "Monitor: ON" (10,215) (110,28) "45,45,45" {
    try {
        $tasks = @("NordVPN-Ethernet-Connect","NordVPN-WiFi-Connect","NordVPN-Ethernet-Disconnect","NordVPN-WiFi-Disconnect","NordVPN-Watchdog")
        foreach ($t in $tasks) { schtasks /change /tn $t /enable 2>$null }
        $monOn.BackColor=[System.Drawing.Color]::FromArgb(0,120,212)
        $monOff.BackColor=[System.Drawing.Color]::FromArgb(45,45,45)
        $taskSt.Text="Tasks: All Ready"
        $taskSt.ForeColor=[System.Drawing.Color]::White
    } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") }
}
$monOff = B $null "Monitor: OFF" (130,215) (110,28) "211,47,47" {
    try {
        $tasks = @("NordVPN-Ethernet-Connect","NordVPN-WiFi-Connect","NordVPN-Ethernet-Disconnect","NordVPN-WiFi-Disconnect","NordVPN-Watchdog")
        foreach ($t in $tasks) { schtasks /change /tn $t /disable 2>$null }
        $monOff.BackColor=[System.Drawing.Color]::FromArgb(211,47,47)
        $monOn.BackColor=[System.Drawing.Color]::FromArgb(45,45,45)
        $taskSt.Text="Monitor: Disabled"
        $taskSt.ForeColor=[System.Drawing.Color]::FromArgb(255,171,0)
    } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") }
}
$taskSt = L $null "Status: Checking..." (250,215) (270,28) "255,255,255"

L $null "Actions" (10,255) (520,20) "0,120,212"
B $null "Health Check" (10,280) (110,30) "0,120,212" {
    $taskSt.Text = "Running health check..."
    $taskSt.ForeColor = [System.Drawing.Color]::FromArgb(255,171,0)
    $form.Refresh()
    $result = Start-Job -ScriptBlock { & "$env:USERPROFILE\.nordvpn\nord.ps1" health 2>&1 | Out-String } | Wait-Job -Timeout 60 | Receive-Job
    Remove-Job -Name * -Force -ErrorAction SilentlyContinue
    $taskSt.Text = "Last check: just now"
    $taskSt.ForeColor = [System.Drawing.Color]::White
    [System.Windows.Forms.MessageBox]::Show($result, "NordVPN Health Check","OK","Information")
}
B $null "View Logs" (130,280) (110,30) "0,120,212" { try { if(Test-Path $logDir){Start-Process explorer.exe $logDir}else{[System.Windows.Forms.MessageBox]::Show("Logs not found","NordVPN","OK","Warning")} } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
B $null "Settings" (250,280) (110,30) "0,120,212" { try { Show-SettingsDialog } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }

L $null "" (10,320) (520,1) "80,80,80"
$statusBar = L $null "Last check: just now" (10,328) (520,20) "170,170,170"

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $pid | Select-Object -ExpandProperty Path))
$notifyIcon.Text = "NordVPN"
$notifyIcon.Visible = $true
$notifyIcon.Add_DoubleClick({ $form.Show(); $form.WindowState = "Normal"; $form.BringToFront() })

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = New-Object System.Windows.Forms.ToolStripMenuItem("Show")
$showItem.Add_Click({ $form.Show(); $form.WindowState = "Normal"; $form.BringToFront() })
$hideItem = New-Object System.Windows.Forms.ToolStripMenuItem("Hide")
$hideItem.Add_Click({ $form.Hide() })
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
$exitItem.Add_Click({
    $exiting = $true
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$trayMenu.Items.AddRange(@($showItem, $hideItem, (New-Object System.Windows.Forms.ToolStripSeparator), $exitItem))
$notifyIcon.ContextMenuStrip = $trayMenu

$form.Add_Resize({
    if ($form.WindowState -eq "Minimized") { $form.Hide() }
})
$form.Add_FormClosing({
    param($sender, $e)
    if (-not $exiting) { $e.Cancel = $true; $form.Hide() }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000
$timer.Add_Tick({
    if ($form.InvokeRequired) { $form.BeginInvoke([Action]{ Update-Status; Update-MonitorStatus }) }
    else { Update-Status; Update-MonitorStatus }
})
$timer.Start()

Update-Status; Update-MonitorStatus
[System.Windows.Forms.Application]::Run($form)
