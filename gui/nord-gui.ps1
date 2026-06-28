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
$form.Size = "550,500"
$form.StartPosition = "CenterScreen"; $form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false; $form.BackColor = "#1e1e1e"; $form.ForeColor = "White"
$form.Font = "Segoe UI,9"

function B($p,$t,$s,$l,$c,$h) { $b=New-Object System.Windows.Forms.Button; $b.Text=$t; $b.Location=$l; $b.Size=$s; $b.BackColor=$c; $b.ForeColor="White"; $b.FlatStyle="Flat"; if($h){$b.Add_Click($h)}; if($p){$p.Controls.Add($b)}else{$form.Controls.Add($b)}; $b }
function L($p,$t,$l,$s,$c,$f) { $b=New-Object System.Windows.Forms.Label; $b.Text=$t; $b.Location=$l; $b.Size=$s; $b.ForeColor=if($c){$c}else{"White"}; if($f){$b.Font=$f}; if($p){$p.Controls.Add($b)}else{$form.Controls.Add($b)}; $b }
function T { param($p,$l,$s,$m) $b=New-Object System.Windows.Forms.TextBox; $b.Location=$l; $b.Size=$s; $b.BackColor="#2d2d2d"; $b.ForeColor="White"; $b.BorderStyle="FixedSingle"; if($m){$b.UseSystemPasswordChar=$true}; $p.Controls.Add($b); $b }

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
        $r = Invoke-Nord "status"; $ip = ""; $c = $false
        foreach ($l in $r) {
            if ($l -match "Status:\s*Connected") { $c = $true }
            if ($l -match "IP:\s*(\d+\.\d+\.\d+\.\d+)") { $ip = $matches[1] }
        }
        if ($c -and $ip) { $statusLabel.Text = "Connected ($ip)"; $statusLabel.ForeColor = "#4caf50"; $indicator.BackColor = "#4caf50" }
        elseif ($c) { $statusLabel.Text = "Connected"; $statusLabel.ForeColor = "#4caf50"; $indicator.BackColor = "#4caf50" }
        else { $statusLabel.Text = "Disconnected"; $statusLabel.ForeColor = "#f44336"; $indicator.BackColor = "#f44336" }
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
    $sf.Text = "NordVPN Settings"; $sf.Size = "350,240"; $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "FixedDialog"; $sf.MaximizeBox = $false; $sf.MinimizeBox = $false
    $sf.BackColor = "#1e1e1e"; $sf.ForeColor = "White"
    L $sf "NordVPN Username:" (12,15) (120,20)
    $ub = T $sf (140,12) (190,22) $false
    L $sf "NordVPN Password:" (12,45) (120,20)
    $pb = T $sf (140,42) (190,22) $true
    L $sf "Target WiFi SSID:" (12,75) (120,20)
    $wb = T $sf (140,72) (190,22) $false; $wb.Text = "AMPLIFIER_EXT"
    if (Test-Path $authFile) { $ln = Get-Content $authFile -ErrorAction SilentlyContinue; if ($ln.Count -ge 1) { $ub.Text = $ln[0] }; if ($ln.Count -ge 2) { $pb.Text = $ln[1] } }
    $sb = B $sf "Save" (90,28) (140,110) "#0078d4" {
        try {
            "$($ub.Text)`n$($pb.Text)" | Out-File $authFile -Encoding ascii
            "@echo off`r`nif `"%SSID%`"==`"$($wb.Text)`" (`r`npowershell -NoProfile -WindowStyle Hidden -File `"$nordPs1`" $srv -$proto`r`n)" | Out-File $wifiScript -Encoding ascii
            [System.Windows.Forms.MessageBox]::Show("Settings saved successfully.", "NordVPN","OK","Information"); $sf.Close()
        } catch { [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error","OK","Error") }
    }
    $sf.ShowDialog()
}

function Update-MonitorStatus {
    try {
        $r = Invoke-Nord "monitor status"; $on = $false; $rem = ""
        foreach ($l in $r) { if ($l -match "running") { $on = $true }; if ($l -match "all tasks ready" -or $l -match "remaining") { $rem = $l.Trim() } }
        if ($on) { $monOn.BackColor="#0078d4"; $monOff.BackColor="#2d2d2d"; $taskSt.Text="Status: $rem"; $taskSt.ForeColor="White" }
        else { $monOn.BackColor="#2d2d2d"; $monOff.BackColor="#d32f2f"; $taskSt.Text="Status: Not Running"; $taskSt.ForeColor="#ffab00" }
    }
    catch { $taskSt.Text = "Error: $_" }
}

$y = 8
L $null "NordVPN Auto-Connect Manager" (10,$y) (520,26) "#0078d4" "Segoe UI,12,Bold"
$y = 38

$sp = New-Object System.Windows.Forms.Panel; $sp.Location=(10,$y); $sp.Size=(520,40); $sp.BackColor="#2d2d2d"; $form.Controls.Add($sp)
$indicator = L $sp "" (12,10) (20,20) "#f44336"
$statusLabel = L $sp "Checking..." (40,8) (350,24) "White" "Segoe UI,10,Bold"
$refreshBtn = B $sp "Refresh" (75,26) (430,7) "#0078d4" { try { Update-Status } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$y += 50

L $null "Connection" (10,$y) (520,20) "#0078d4" "Segoe UI,9,Bold"; $y += 22
$connectBtn = B $null "Connect" (90,32) (10,$y) "#107c10" { try { Invoke-Connect } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$disconnectBtn = B $null "Disconnect" (90,32) (108,$y) "#d32f2f" { try { Invoke-Disconnect } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$reconnectBtn = B $null "Reconnect" (90,32) (206,$y) "#ff8c00" { try { Invoke-Reconnect } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$y += 40

L $null "Server:" (10,$y) (50,24)
$sc = New-Object System.Windows.Forms.ComboBox; $sc.Location=(60,$y); $sc.Size=(100,24)
$sc.BackColor="#2d2d2d"; $sc.ForeColor="White"; $sc.DropDownStyle="DropDownList"
@("us","de","nl","gb","ch","se","no","fr","jp","ca","au","in","kr","sg","br","za","it","es","hk","nz")|%{$sc.Items.Add($_)}
$sc.SelectedIndex=0; $sc.Add_SelectedIndexChanged({$srv=$sc.Text}); $form.Controls.Add($sc)

$tcpBtn = B $null "TCP" (50,24) (175,$y) "#0078d4" { try { $proto="tcp"; $tcpBtn.BackColor="#0078d4"; $udpBtn.BackColor="#2d2d2d" } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$udpBtn = B $null "UDP" (50,24) (230,$y) "#2d2d2d" { try { $proto="udp"; $udpBtn.BackColor="#0078d4"; $tcpBtn.BackColor="#2d2d2d" } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$y += 32

L $null "Auto-Connect" (10,$y) (520,20) "#0078d4" "Segoe UI,9,Bold"; $y += 22
$monOn = B $null "Monitor: ON" (100,28) (10,$y) "#2d2d2d" { try { Invoke-Nord "monitor enable"; $monOn.BackColor="#0078d4"; $monOff.BackColor="#2d2d2d"; $taskSt.Text="Tasks: All Ready"; $taskSt.ForeColor="White" } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$monOff = B $null "Monitor: OFF" (100,28) (118,$y) "#d32f2f" { try { Invoke-Nord "monitor disable"; $monOff.BackColor="#d32f2f"; $monOn.BackColor="#2d2d2d"; $taskSt.Text="Monitor: Disabled"; $taskSt.ForeColor="#ffab00" } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$taskSt = L $null "Status: Checking..." (230,$y) (290,28)
$y += 36

L $null "Actions" (10,$y) (520,20) "#0078d4" "Segoe UI,9,Bold"; $y += 22
B $null "Health Check" (110,30) (10,$y) "#0078d4" { try { [System.Windows.Forms.MessageBox]::Show((Invoke-Nord "health"|Out-String), "NordVPN Health Check","OK","Information") } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
B $null "View Logs" (110,30) (128,$y) "#0078d4" { try { if(Test-Path $logDir){Start-Process explorer.exe $logDir}else{[System.Windows.Forms.MessageBox]::Show("Logs directory not found","NordVPN","OK","Warning")} } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
B $null "Settings" (110,30) (246,$y) "#0078d4" { try { Show-SettingsDialog } catch { [System.Windows.Forms.MessageBox]::Show("$_","Error","OK","Error") } }
$y += 40

$s = L $null "" (10,$y) (520,1) "#3d3d3d"; $s.BorderStyle="FixedSingle"; $y += 8
$statusBar = L $null "Last check: just now" (10,$y) (520,20) "#aaaaaa"

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
