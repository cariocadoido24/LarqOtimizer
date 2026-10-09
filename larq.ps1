# LarqOtimizer - Single-file PowerShell edition
# Executa diretamente em memoria via: irm <raw-url> | iex
# Sem instalacao persistente do aplicativo.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Management
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:LarqUrl = 'https://raw.githubusercontent.com/cariocadoido24/LarqOtimizer/main/larq.ps1'
$script:AuthSalt = 'xM6D3Wd5RAqmOP8vhY27Qw=='
$script:AuthHash = 'FWYLY+XQF8UubDidb5/riDMcYaMBuKHr1rXYe+jawbo='
$script:Iterations = 100000
$script:OriginalReg = @{}
$script:PrevProcCpu = @{}
$script:LastProcSample = Get-Date
$script:MainTimer = $null

# ---------- Tema ----------
$C = [ordered]@{
    Bg       = [Drawing.Color]::FromArgb(11,15,25)
    Surface  = [Drawing.Color]::FromArgb(17,24,39)
    Surface2 = [Drawing.Color]::FromArgb(24,33,49)
    Border   = [Drawing.Color]::FromArgb(48,58,76)
    Text     = [Drawing.Color]::FromArgb(243,244,246)
    Muted    = [Drawing.Color]::FromArgb(156,163,175)
    Cyan     = [Drawing.Color]::FromArgb(0,240,255)
    Purple   = [Drawing.Color]::FromArgb(112,0,255)
    Green    = [Drawing.Color]::FromArgb(0,255,102)
    Red      = [Drawing.Color]::FromArgb(255,0,85)
    Yellow   = [Drawing.Color]::FromArgb(255,184,0)
}

function New-Label([string]$Text,[int]$Size=10,[Drawing.Color]$Color=$C.Text,[switch]$Bold){
    $l = New-Object Windows.Forms.Label
    $l.Text = $Text
    $l.ForeColor = $Color
    $l.AutoSize = $true
    $l.Font = New-Object Drawing.Font('Segoe UI',$Size,($(if($Bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular})))
    return $l
}
function New-Button([string]$Text,[scriptblock]$OnClick,[switch]$Primary){
    $b = New-Object Windows.Forms.Button
    $b.Text = $Text
    $b.Height = 40
    $b.AutoSize = $true
    $b.Padding = New-Object Windows.Forms.Padding(12,0,12,0)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = $(if($Primary){$C.Cyan}else{$C.Border})
    $b.BackColor = $(if($Primary){$C.Cyan}else{$C.Surface2})
    $b.ForeColor = $(if($Primary){$C.Bg}else{$C.Text})
    $b.Font = New-Object Drawing.Font('Segoe UI',9.5,($(if($Primary){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular})))
    $b.Cursor = 'Hand'
    # Preserve the original PowerShell session state. GetNewClosure() creates a dynamic module
    # and can hide helper functions such as Test-LarqPassword from WinForms event handlers.
    $b.Add_Click($OnClick)
    return $b
}
function New-Card([string]$Title,[string]$Sub=''){
    $p = New-Object Windows.Forms.Panel
    $p.BackColor = $C.Surface
    $p.Padding = New-Object Windows.Forms.Padding(14)
    $p.Margin = New-Object Windows.Forms.Padding(0,0,12,12)
    $p.BorderStyle = 'FixedSingle'
    if($Title){
        $t = New-Label $Title 11 $C.Text -Bold
        $t.Dock = 'Top'; $t.Height = 26; $t.AutoSize = $false
        $p.Controls.Add($t)
    }
    if($Sub){
        $s = New-Label $Sub 8 $C.Muted
        $s.Dock = 'Top'; $s.Height=22; $s.AutoSize=$false
        $p.Controls.Add($s); $s.BringToFront()
    }
    return $p
}
function New-Page {
    $p = New-Object Windows.Forms.Panel
    $p.Dock='Fill'; $p.BackColor=$C.Bg; $p.AutoScroll=$true; $p.Padding=New-Object Windows.Forms.Padding(22)
    return $p
}
function New-Flow {
    $f=New-Object Windows.Forms.FlowLayoutPanel
    $f.Dock='Top'; $f.AutoSize=$true; $f.AutoSizeMode='GrowAndShrink'; $f.FlowDirection='TopDown'; $f.WrapContents=$false; $f.BackColor=$C.Bg
    return $f
}
function Add-FlowControl($flow,$control,[int]$Width=0){ if($Width -gt 0){$control.Width=$Width}; $flow.Controls.Add($control) }
function Show-Info([string]$m){[Windows.Forms.MessageBox]::Show($m,'LarqOtimizer','OK','Information')|Out-Null}
function Show-Warn([string]$m){[Windows.Forms.MessageBox]::Show($m,'LarqOtimizer','OK','Warning')|Out-Null}
function Confirm([string]$m){ return ([Windows.Forms.MessageBox]::Show($m,'LarqOtimizer','YesNo','Question') -eq 'Yes') }

# ---------- Seguranca/Login ----------
function Test-LarqPassword([string]$Password){
    try {
        $salt=[Convert]::FromBase64String($script:AuthSalt)
        $pbkdf=New-Object Security.Cryptography.Rfc2898DeriveBytes($Password,$salt,$script:Iterations)
        try {$got=$pbkdf.GetBytes(32)} finally {$pbkdf.Dispose()}
        $expected=[Convert]::FromBase64String($script:AuthHash)
        if($got.Length -ne $expected.Length){return $false}
        $diff=0; for($i=0;$i -lt $got.Length;$i++){$diff=$diff -bor ($got[$i] -bxor $expected[$i])}
        return ($diff -eq 0)
    } catch { return $false }
}
function Show-Login {
    $f=New-Object Windows.Forms.Form
    $f.Text='LarqOtimizer · Login'; $f.Size=New-Object Drawing.Size(470,390); $f.StartPosition='CenterScreen'; $f.FormBorderStyle='FixedDialog'; $f.MaximizeBox=$false
    $f.BackColor=$C.Bg; $f.ForeColor=$C.Text
    $title=New-Label 'LARQOTIMIZER  PRO' 19 $C.Cyan -Bold; $title.Location=New-Object Drawing.Point(115,45)
    $sub=New-Label 'Acesse para gerenciar e otimizar o sistema' 9 $C.Muted; $sub.Location=New-Object Drawing.Point(92,82)
    $uLab=New-Label 'Usuario' 9 $C.Muted; $uLab.Location=New-Object Drawing.Point(70,126)
    $user=New-Object Windows.Forms.TextBox; $user.Location=New-Object Drawing.Point(70,150); $user.Size=New-Object Drawing.Size(320,34); $user.Text='larq'; $user.BackColor=$C.Surface2; $user.ForeColor=$C.Text; $user.BorderStyle='FixedSingle'; $user.Font=New-Object Drawing.Font('Segoe UI',11)
    $pLab=New-Label 'Senha' 9 $C.Muted; $pLab.Location=New-Object Drawing.Point(70,198)
    $pass=New-Object Windows.Forms.TextBox; $pass.Location=New-Object Drawing.Point(70,222); $pass.Size=New-Object Drawing.Size(320,34); $pass.UseSystemPasswordChar=$true; $pass.BackColor=$C.Surface2; $pass.ForeColor=$C.Text; $pass.BorderStyle='FixedSingle'; $pass.Font=New-Object Drawing.Font('Segoe UI',11)
    $status=New-Label '' 9 $C.Red; $status.Location=New-Object Drawing.Point(70,263); $status.MaximumSize=New-Object Drawing.Size(320,40)
    $btn=New-Button 'ENTRAR NO PAINEL' ({
        param($s,$e)
        $ctx=$s.Tag
        if(Test-LarqPassword $ctx.Pass.Text){$ctx.Form.DialogResult='OK';$ctx.Form.Close()}else{$ctx.Status.Text='Senha incorreta.';$ctx.Pass.Clear();$ctx.Pass.Focus()}
    }) -Primary
    $btn.Tag=[pscustomobject]@{Form=$f;Pass=$pass;Status=$status}
    $btn.Location=New-Object Drawing.Point(70,300); $btn.Width=320; $btn.Height=44
    $f.Controls.AddRange(@($title,$sub,$uLab,$user,$pLab,$pass,$status,$btn)); $f.AcceptButton=$btn
    $pass.Focus(); return ($f.ShowDialog() -eq 'OK')
}

# ---------- Utilitarios Windows ----------
function Is-Admin { $id=[Security.Principal.WindowsIdentity]::GetCurrent(); $p=New-Object Security.Principal.WindowsPrincipal($id); return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Need-Admin {
    if(Is-Admin){return $true}
    Show-Warn 'Esta acao precisa de Administrador. Abra PowerShell como Administrador e rode o comando do LarqOtimizer novamente.'
    return $false
}
function Format-Bytes([double]$b){
    if($b -ge 1TB){return ('{0:N2} TB' -f ($b/1TB))}
    if($b -ge 1GB){return ('{0:N2} GB' -f ($b/1GB))}
    if($b -ge 1MB){return ('{0:N1} MB' -f ($b/1MB))}
    if($b -ge 1KB){return ('{0:N1} KB' -f ($b/1KB))}
    return ('{0:N0} B' -f $b)
}
function Read-Reg([string]$Path,[string]$Name){try{return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name}catch{return $null}}
function Save-RegOriginal([string]$Path,[string]$Name){
    $k="$Path|$Name"; if(-not $script:OriginalReg.ContainsKey($k)){$script:OriginalReg[$k]=Read-Reg $Path $Name}
}
function Set-RegDword([string]$Path,[string]$Name,[int]$Value){Save-RegOriginal $Path $Name; if(!(Test-Path $Path)){New-Item $Path -Force|Out-Null}; New-ItemProperty $Path $Name -PropertyType DWord -Value $Value -Force|Out-Null}
function Set-RegString([string]$Path,[string]$Name,[string]$Value){Save-RegOriginal $Path $Name; if(!(Test-Path $Path)){New-Item $Path -Force|Out-Null}; New-ItemProperty $Path $Name -PropertyType String -Value $Value -Force|Out-Null}
function Restore-Reg([string]$Path,[string]$Name){
    $k="$Path|$Name"; if($script:OriginalReg.ContainsKey($k)){$v=$script:OriginalReg[$k]; if($null -eq $v){Remove-ItemProperty $Path $Name -EA SilentlyContinue}else{New-ItemProperty $Path $Name -Value $v -Force|Out-Null}}
}

# ---------- Metricas ----------
function Get-Metrics {
    $o=[ordered]@{CPU=0;RAM=0;RAMUsed=0;RAMTotal=0;Disk=0;Read=0;Write=0;NetDown=0;NetUp=0;GPU=$null;Temp=$null}
    try{$cpu=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"; $o.CPU=[math]::Max(0,[math]::Min(100,[double]$cpu.PercentProcessorTime))}catch{}
    try{
        $os=Get-CimInstance Win32_OperatingSystem
        $tot=[double]$os.TotalVisibleMemorySize*1KB; $free=[double]$os.FreePhysicalMemory*1KB; $used=$tot-$free
        $o.RAMTotal=$tot;$o.RAMUsed=$used;$o.RAM=if($tot){100*$used/$tot}else{0}
    }catch{}
    try{
        $d=Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'"
        $o.Disk=[math]::Max(0,[math]::Min(100,[double]$d.PercentDiskTime));$o.Read=[double]$d.DiskReadBytesPersec;$o.Write=[double]$d.DiskWriteBytesPersec
    }catch{}
    try{
        $ns=Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface
        foreach($n in $ns){$o.NetDown += [double]$n.BytesReceivedPersec;$o.NetUp += [double]$n.BytesSentPersec}
    }catch{}
    try{
        $g=Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -EA Stop | Where-Object {$_.Name -match 'engtype_3D'}
        if($g){$sum=($g|Measure-Object UtilizationPercentage -Sum).Sum; $o.GPU=[math]::Min(100,[math]::Max(0,[double]$sum))}
    }catch{}
    try{
        $t=Get-CimInstance -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature -EA Stop | Select-Object -First 1
        if($t){$c=[math]::Round(($t.CurrentTemperature/10)-273.15,1);if($c -gt 0 -and $c -lt 130){$o.Temp=$c}}
    }catch{}
    return [pscustomobject]$o
}
function Get-TopProcesses {
    try {
        $rows=Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | Where-Object {$_.Name -notin @('_Total','Idle')} | Sort-Object PercentProcessorTime -Descending | Select-Object -First 20
        return $rows
    } catch { return @() }
}

# ---------- Limpeza ----------
function Get-CleanupTargets {
    $la=$env:LOCALAPPDATA
    return @(
        [pscustomobject]@{Name='TEMP do usuario';Path=$env:TEMP;Admin=$false},
        [pscustomobject]@{Name='Windows Temp';Path="$env:WINDIR\Temp";Admin=$true},
        [pscustomobject]@{Name='DirectX Shader Cache';Path="$la\D3DSCache";Admin=$false},
        [pscustomobject]@{Name='Crash Dumps';Path="$la\CrashDumps";Admin=$false},
        [pscustomobject]@{Name='Chrome Cache';Path="$la\Google\Chrome\User Data\Default\Cache";Admin=$false},
        [pscustomobject]@{Name='Edge Cache';Path="$la\Microsoft\Edge\User Data\Default\Cache";Admin=$false},
        [pscustomobject]@{Name='NVIDIA DXCache';Path="$la\NVIDIA\DXCache";Admin=$false},
        [pscustomobject]@{Name='NVIDIA GLCache';Path="$la\NVIDIA\GLCache";Admin=$false},
        [pscustomobject]@{Name='AMD DxCache';Path="$la\AMD\DxCache";Admin=$false}
    )
}
function Get-FolderSize([string]$Path){try{return (Get-ChildItem $Path -Force -Recurse -File -EA SilentlyContinue|Measure-Object Length -Sum).Sum}catch{return 0}}
function Clear-FolderSafe([string]$Path){
    $freed=0
    if(!(Test-Path $Path)){return 0}
    Get-ChildItem $Path -Force -EA SilentlyContinue | ForEach-Object {
        try { if($_.PSIsContainer){$s=Get-FolderSize $_.FullName}else{$s=$_.Length}; Remove-Item $_.FullName -Recurse -Force -EA Stop; $freed+=$s } catch {}
    }
    return $freed
}

# ---------- Tweaks ----------
$script:Tweaks = @(
    [pscustomobject]@{Id='gamemode';Name='Game Mode';Desc='Prioriza recursos do Windows para jogos.';Admin=$false;Path='HKCU:\Software\Microsoft\GameBar';Value='AutoGameModeEnabled';On=1;Off=0},
    [pscustomobject]@{Id='gamedvr';Name='Xbox Game DVR / captura';Desc='Desliga gravacao/captura em segundo plano.';Admin=$false;Path='HKCU:\System\GameConfigStore';Value='GameDVR_Enabled';On=0;Off=1},
    [pscustomobject]@{Id='mouseaccel';Name='Aceleracao do mouse';Desc='OFF remove Enhance Pointer Precision para resposta mais direta.';Admin=$false;Path='HKCU:\Control Panel\Mouse';Value='MouseSpeed';On='0';Off='1';String=$true},
    [pscustomobject]@{Id='powerthrottle';Name='Power Throttling';Desc='OFF impede o Windows de limitar tarefas por economia de energia.';Admin=$true;Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling';Value='PowerThrottlingOff';On=1;Off=0},
    [pscustomobject]@{Id='longpaths';Name='Long Paths';Desc='Ativa caminhos Win32 longos.';Admin=$true;Path='HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem';Value='LongPathsEnabled';On=1;Off=0},
    [pscustomobject]@{Id='lockscreen';Name='Lock Screen Disable';Desc='Remove a tela de bloqueio antes do login.';Admin=$true;Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization';Value='NoLockScreen';On=1;Off=0},
    [pscustomobject]@{Id='telemetry';Name='Telemetria minima';Desc='Reduz telemetria permitida pela politica do Windows.';Admin=$true;Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';Value='AllowTelemetry';On=0;Off=3},
    [pscustomobject]@{Id='widgets';Name='Widgets';Desc='Desliga Widgets do Windows para reduzir processos de interface.';Admin=$false;Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Value='TaskbarDa';On=0;Off=1},
    [pscustomobject]@{Id='copilot';Name='Windows Copilot';Desc='Desativa o Windows Copilot por politica.';Admin=$false;Path='HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot';Value='TurnOffWindowsCopilot';On=1;Off=0},
    [pscustomobject]@{Id='notifications';Name='Notificacoes';Desc='Bloqueia notificacoes toast para evitar popups durante jogos.';Admin=$false;Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications';Value='ToastEnabled';On=0;Off=1},
    [pscustomobject]@{Id='consumer';Name='Consumer Features';Desc='Reduz apps/sugestoes promovidas pela Microsoft.';Admin=$true;Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';Value='DisableWindowsConsumerFeatures';On=1;Off=0},
    [pscustomobject]@{Id='delivery';Name='Delivery Optimization P2P';Desc='Desliga compartilhamento P2P de updates.';Admin=$false;Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization';Value='SystemSettingsDownloadMode';On=0;Off=1},
    [pscustomobject]@{Id='startupdelay';Name='Atraso de inicializacao';Desc='Remove o atraso artificial aplicado a alguns apps de inicializacao.';Admin=$false;Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize';Value='StartupDelayInMSec';On=0;Off=1}
)
function Set-Tweak($tw,[bool]$Enable){
    if($tw.Admin -and !(Need-Admin)){return}
    $isString = ($tw.PSObject.Properties.Name -contains 'String') -and [bool]$tw.String
    if($isString){Set-RegString $tw.Path $tw.Value ([string]$(if($Enable){$tw.On}else{$tw.Off}))}else{Set-RegDword $tw.Path $tw.Value ([int]$(if($Enable){$tw.On}else{$tw.Off}))}
}
function Get-TweakEnabled($tw){$v=Read-Reg $tw.Path $tw.Value; if($null -eq $v){return $null}; return ([string]$v -eq [string]$tw.On)}

# ---------- CPU / GPU Max ----------
function Apply-CPU-Max([bool]$Extreme){
    if(!(Need-Admin)){return}
    $scheme=(powercfg /getactivescheme) -join ' '
    $proc='54533251-82be-4824-96c1-47b60b740d00'; $min='893dee8e-2bef-41e0-89c6-b55d0929964c'; $max='bc5038f7-23e0-4960-96da-33abaf5935ec'; $boost='be337238-0d82-4146-a960-4f3749d470c7'; $park='0cc5b647-c1df-4637-891a-dec35c318583'
    powercfg /setacvalueindex SCHEME_CURRENT $proc $max 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT $proc $boost 2 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT $proc $park 100 | Out-Null
    if($Extreme){powercfg /setacvalueindex SCHEME_CURRENT $proc $min 100|Out-Null}else{powercfg /setacvalueindex SCHEME_CURRENT $proc $min 5|Out-Null}
    powercfg /setactive SCHEME_CURRENT|Out-Null
    Set-RegDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
    Set-RegDword 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-RegDword 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Show-Info $(if($Extreme){'CPU EXTREMO aplicado. Maior consumo/temperatura.'}else{'CPU JOGO aplicado.'})
}
function Set-HAGS([bool]$Enable){if(!(Need-Admin)){return}; Set-RegDword 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' $(if($Enable){2}else{1}); Show-Info 'HAGS alterado. Reinicie o Windows para testar.'}
function Set-AppHighGpu {
    $dlg=New-Object Windows.Forms.OpenFileDialog; $dlg.Filter='Executaveis (*.exe)|*.exe'; if($dlg.ShowDialog() -ne 'OK'){return}
    $path='HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'; if(!(Test-Path $path)){New-Item $path -Force|Out-Null}; New-ItemProperty $path -Name $dlg.FileName -Value 'GpuPreference=2;' -PropertyType String -Force|Out-Null; Show-Info 'Preferencia de GPU de alto desempenho definida para esse executavel.'
}


# ---------- Fortnite / Jogos ----------
function Get-FortniteConfigPath {
    $candidates=@(
        "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini",
        "$env:LOCALAPPDATA\FortniteGame\Saved\Config\Windows\GameUserSettings.ini"
    )
    foreach($p in $candidates){if(Test-Path $p){return $p}}
    return $null
}
function Find-FortniteExe {
    $pf86=[Environment]::GetFolderPath('ProgramFilesX86')
    $common=@(
        "$env:ProgramFiles\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe",
        "$pf86\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe"
    )
    foreach($p in $common){if($p -and (Test-Path $p)){return $p}}
    $manifestDir="$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    if(Test-Path $manifestDir){
        foreach($f in Get-ChildItem $manifestDir -Filter '*.item' -File -EA SilentlyContinue){
            try{
                $j=Get-Content $f.FullName -Raw -EA Stop|ConvertFrom-Json
                if(($j.DisplayName -match 'Fortnite') -or ($j.AppName -match 'Fortnite')){
                    $p=Join-Path $j.InstallLocation 'FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'
                    if(Test-Path $p){return $p}
                }
            }catch{}
        }
    }
    return $null
}
function Set-IniValue([string]$Content,[string]$Key,[string]$Value){
    $pattern='(?m)^\s*'+[regex]::Escape($Key)+'\s*=.*
function Hardware-Text {
    $sb=New-Object Text.StringBuilder
    try{$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1; [void]$sb.AppendLine("CPU: $($cpu.Name)");[void]$sb.AppendLine("Cores/Threads: $($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)");[void]$sb.AppendLine("Clock max publicado: $($cpu.MaxClockSpeed) MHz") }catch{}
    try{$bb=Get-CimInstance Win32_BaseBoard|Select-Object -First 1;[void]$sb.AppendLine("Placa-mae: $($bb.Manufacturer) $($bb.Product)")}catch{}
    try{$bios=Get-CimInstance Win32_BIOS|Select-Object -First 1;[void]$sb.AppendLine("BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)")}catch{}
    try{$ram=Get-CimInstance Win32_PhysicalMemory;$sum=($ram|Measure-Object Capacity -Sum).Sum;[void]$sb.AppendLine("RAM: $(Format-Bytes $sum) · modulos: $($ram.Count)"); foreach($r in $ram){[void]$sb.AppendLine("  $([math]::Round($r.Capacity/1GB)) GB · $($r.Speed) MHz · $($r.Manufacturer)")}}catch{}
    try{foreach($g in Get-CimInstance Win32_VideoController){[void]$sb.AppendLine("GPU: $($g.Name) · driver $($g.DriverVersion) · VRAM publicada $(Format-Bytes $g.AdapterRAM)")}}catch{}
    try{foreach($d in Get-CimInstance Win32_DiskDrive){[void]$sb.AppendLine("Disco: $($d.Model) · $(Format-Bytes $d.Size) · $($d.InterfaceType)")}}catch{}
    return $sb.ToString()
}
function Bios-Text {
    $sb=New-Object Text.StringBuilder
    try{$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1; [void]$sb.AppendLine("SMT: " + $(if($cpu.NumberOfLogicalProcessors -gt $cpu.NumberOfCores){'ATIVO/threads publicados'}else{'NAO detectado'})); [void]$sb.AppendLine("Virtualizacao Firmware: $($cpu.VirtualizationFirmwareEnabled)")}catch{}
    try{[void]$sb.AppendLine("Secure Boot: " + $(if(Confirm-SecureBootUEFI -EA Stop){'ATIVO'}else{'DESATIVADO'}))}catch{[void]$sb.AppendLine('Secure Boot: N/D')}
    try{$ci=Get-ComputerInfo -Property BiosFirmwareType;[void]$sb.AppendLine("Firmware: $($ci.BiosFirmwareType)")}catch{}
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Itens que o Windows normalmente NAO consegue confirmar em placa-mae desktop:')
    [void]$sb.AppendLine('• A-XMP/XMP/DOCP: conferir manualmente na BIOS.')
    [void]$sb.AppendLine('• PBO/Curve Optimizer: conferir manualmente; nao aplicar tensao automaticamente.')
    [void]$sb.AppendLine('• UMA Frame Buffer: relevante ao usar iGPU; conferir manualmente.')
    [void]$sb.AppendLine('• Curva das ventoinhas: conferir no Hardware Monitor da BIOS.')
    return $sb.ToString()
}

# ---------- App ----------
if(-not (Show-Login)){return}

$form=New-Object Windows.Forms.Form
$form.Text='LarqOtimizer · PowerShell Edition'; $form.StartPosition='CenterScreen'; $form.Size=New-Object Drawing.Size(1460,900); $form.MinimumSize=New-Object Drawing.Size(1100,700); $form.BackColor=$C.Bg; $form.ForeColor=$C.Text

$side=New-Object Windows.Forms.Panel; $side.Dock='Left';$side.Width=245;$side.BackColor=$C.Surface;$side.Padding=New-Object Windows.Forms.Padding(12)
$logo=New-Label '⚡  LARQOTIMIZER  PRO' 13 $C.Cyan -Bold; $logo.Dock='Top';$logo.Height=70;$logo.AutoSize=$false;$logo.TextAlign='MiddleLeft';$side.Controls.Add($logo)
$nav=New-Object Windows.Forms.FlowLayoutPanel;$nav.Dock='Fill';$nav.FlowDirection='TopDown';$nav.WrapContents=$false;$nav.AutoScroll=$true;$nav.BackColor=$C.Surface;$side.Controls.Add($nav);$nav.BringToFront()
$admin=New-Label ($(if(Is-Admin){'● Administrador'}else{'○ Usuario normal'})) 8 $(if(Is-Admin){$C.Green}else{$C.Yellow});$admin.Dock='Bottom';$admin.Height=32;$admin.AutoSize=$false;$side.Controls.Add($admin)

$host=New-Object Windows.Forms.Panel;$host.Dock='Fill';$host.BackColor=$C.Bg
$header=New-Object Windows.Forms.Panel;$header.Dock='Top';$header.Height=68;$header.BackColor=$C.Surface;$header.Padding=New-Object Windows.Forms.Padding(20,10,20,8)
$headerTitle=New-Label 'Visao Geral' 14 $C.Text -Bold;$headerTitle.Dock='Left';$headerTitle.Width=430;$headerTitle.AutoSize=$false;$headerTitle.TextAlign='MiddleLeft'
$quick=New-Button '⚡ MODO MAXIMO CPU + GPU' ({if(Confirm 'Aplicar perfil maximo de CPU + ajustes de jogos? Pode aumentar temperatura/consumo.'){Apply-CPU-Max $true}}) -Primary;$quick.Dock='Right';$quick.Width=235
$header.Controls.AddRange(@($quick,$headerTitle))
$content=New-Object Windows.Forms.Panel;$content.Dock='Fill';$content.BackColor=$C.Bg
$host.Controls.Add($content);$host.Controls.Add($header)
$form.Controls.Add($host);$form.Controls.Add($side)

$pages=@{};$navButtons=@{}
function Add-Page([string]$Id,[string]$Title,[scriptblock]$Build){
    $p=New-Page;&$Build $p;$p.Visible=$false;$content.Controls.Add($p);$pages[$Id]=$p
    $b=New-Button $Title ({param($s,$e); $ctx=$s.Tag; foreach($k in $pages.Keys){$pages[$k].Visible=$false;$navButtons[$k].BackColor=$C.Surface2;$navButtons[$k].ForeColor=$C.Text};$pages[$ctx.Id].Visible=$true;$pages[$ctx.Id].BringToFront();$s.BackColor=$C.Cyan;$s.ForeColor=$C.Bg;$headerTitle.Text=$ctx.Title})
    $b.Tag=[pscustomobject]@{Id=$Id;Title=$Title}
    $b.Width=205;$b.Height=40;$b.Margin=New-Object Windows.Forms.Padding(2,2,2,2);$nav.Controls.Add($b);$navButtons[$Id]=$b
}

# Dashboard labels globais
$cpuV=$null;$ramV=$null;$diskV=$null;$gpuV=$null;$netV=$null;$tempV=$null;$procGrid=$null
Add-Page 'dash' '▦  Visao Geral' {
    param($p)
    $flow=New-Flow;$p.Controls.Add($flow)
    $hero=New-Card 'Seu PC em tempo real' 'Atualizacao rapida de CPU, RAM, GPU, disco e rede.';$hero.Height=100;$hero.Width=1100
    $heroBtn=New-Button 'OTIMIZAR COM 1-CLIQUE' ({if(Confirm 'Aplicar ajustes recomendados de desempenho para Windows e jogos?'){Apply-WindowsGamingProfile}}) -Primary;$heroBtn.Location=New-Object Drawing.Point(820,25);$heroBtn.Width=245;$hero.Controls.Add($heroBtn);Add-FlowControl $flow $hero 1100
    $metrics=New-Object Windows.Forms.FlowLayoutPanel;$metrics.AutoSize=$true;$metrics.WrapContents=$true;$metrics.BackColor=$C.Bg
    foreach($m in @(@('CPU','cpuV',$C.Cyan),@('RAM','ramV',$C.Purple),@('DISCO','diskV',$C.Green),@('GPU 3D','gpuV',$C.Cyan),@('REDE','netV',$C.Purple),@('TEMPERATURA','tempV',$C.Yellow))){
        $card=New-Card $m[0];$card.Width=175;$card.Height=100;$lab=New-Label '—' 18 $m[2] -Bold;$lab.Location=New-Object Drawing.Point(14,48);$card.Controls.Add($lab);Set-Variable -Scope Script -Name $m[1] -Value $lab;$metrics.Controls.Add($card)
    }
    Add-FlowControl $flow $metrics 1120
    Add-FlowControl $flow (New-Label 'Processos em tempo real' 14 $C.Text -Bold) 1100
    $procGrid=New-Object Windows.Forms.DataGridView;$procGrid.Width=1100;$procGrid.Height=380;$procGrid.BackgroundColor=$C.Surface;$procGrid.ForeColor=$C.Text;$procGrid.GridColor=$C.Border;$procGrid.RowHeadersVisible=$false;$procGrid.AllowUserToAddRows=$false;$procGrid.ReadOnly=$true;$procGrid.SelectionMode='FullRowSelect';$procGrid.AutoSizeColumnsMode='Fill';$procGrid.EnableHeadersVisualStyles=$false;$procGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$procGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$procGrid.DefaultCellStyle.BackColor=$C.Surface;$procGrid.DefaultCellStyle.ForeColor=$C.Text;$procGrid.DefaultCellStyle.SelectionBackColor=[Drawing.Color]::FromArgb(16,45,58);[void]$procGrid.Columns.Add('Name','Processo');[void]$procGrid.Columns.Add('CPU','CPU %');[void]$procGrid.Columns.Add('RAM','RAM');[void]$procGrid.Columns.Add('Read','Leitura/s');[void]$procGrid.Columns.Add('Write','Gravacao/s');Add-FlowControl $flow $procGrid 1100
}

Add-Page 'hardware' 'CPU  Hardware' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Hardware detectado pelo Windows' 17 $C.Text -Bold) 1100
    $script:HardwareBox=New-Object Windows.Forms.TextBox;$script:HardwareBox.Multiline=$true;$script:HardwareBox.ReadOnly=$true;$script:HardwareBox.ScrollBars='Vertical';$script:HardwareBox.BackColor=$C.Surface;$script:HardwareBox.ForeColor=$C.Text;$script:HardwareBox.Font=New-Object Drawing.Font('Consolas',10);$script:HardwareBox.Height=600;$script:HardwareBox.Text=Hardware-Text;Add-FlowControl $f $script:HardwareBox 1100
    $r=New-Button 'Atualizar hardware' ({$script:HardwareBox.Text=Hardware-Text}) -Primary;Add-FlowControl $f $r 1100
}

Add-Page 'bios' 'BIOS  BIOS e estados' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'BIOS / UEFI e estados detectaveis' 17 $C.Text -Bold) 1100
    $tb=New-Object Windows.Forms.TextBox;$tb.Multiline=$true;$tb.ReadOnly=$true;$tb.ScrollBars='Vertical';$tb.BackColor=$C.Surface;$tb.ForeColor=$C.Text;$tb.Font=New-Object Drawing.Font('Consolas',10);$tb.Height=540;$tb.Text=Bios-Text;Add-FlowControl $f $tb 1100
    Add-FlowControl $f (New-Label 'O LarqOtimizer nao inventa estado de BIOS que o firmware nao publica para o Windows.' 9 $C.Yellow) 1100
}

Add-Page 'devices' 'USB  Perifericos / USB' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Perifericos conectados' 17 $C.Text -Bold) 1100
    $script:DevicesGrid=New-Object Windows.Forms.DataGridView;$script:DevicesGrid.Width=1100;$script:DevicesGrid.Height=580;$script:DevicesGrid.BackgroundColor=$C.Surface;$script:DevicesGrid.ForeColor=$C.Text;$script:DevicesGrid.RowHeadersVisible=$false;$script:DevicesGrid.AllowUserToAddRows=$false;$script:DevicesGrid.ReadOnly=$true;$script:DevicesGrid.AutoSizeColumnsMode='Fill';$script:DevicesGrid.EnableHeadersVisualStyles=$false;$script:DevicesGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:DevicesGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:DevicesGrid.DefaultCellStyle.BackColor=$C.Surface;$script:DevicesGrid.DefaultCellStyle.ForeColor=$C.Text;[void]$script:DevicesGrid.Columns.Add('Class','Classe');[void]$script:DevicesGrid.Columns.Add('Name','Dispositivo');[void]$script:DevicesGrid.Columns.Add('Status','Status');[void]$script:DevicesGrid.Columns.Add('Id','Device ID')
    $script:DevicesRefresh={ $script:DevicesGrid.Rows.Clear(); Get-CimInstance Win32_PnPEntity|Where-Object{$_.PNPClass -match 'Mouse|Keyboard|Monitor|USB|HID|Audio|Bluetooth|Net|Media'}|Sort-Object PNPClass,Name|ForEach-Object{[void]$script:DevicesGrid.Rows.Add($_.PNPClass,$_.Name,$_.Status,$_.DeviceID)} }
    &$script:DevicesRefresh;Add-FlowControl $f $script:DevicesGrid 1100;Add-FlowControl $f (New-Button 'Atualizar perifericos' $script:DevicesRefresh -Primary) 1100
}


Add-Page 'gaming' 'GAME  Fortnite / FPS' {
    param($p);$f=New-Flow;$p.Controls.Add($f)
    Add-FlowControl $f (New-Label 'Fortnite + Windows · desempenho real' 17 $C.Text -Bold) 1100
    Add-FlowControl $f (New-Label 'Aplica ajustes seguros de Windows e edita GameUserSettings.ini do Fortnite com backup. FPS e ping nao sao garantidos: dependem do hardware, driver, servidor e gargalo.' 9 $C.Muted) 1100

    $status=New-Card 'Estado atual' 'Detecta Fortnite, Game Mode, captura, Power Throttling, mouse e HAGS.';$status.Width=1100;$status.Height=190
    $script:GamingStatusBox=New-Object Windows.Forms.TextBox;$script:GamingStatusBox.Multiline=$true;$script:GamingStatusBox.ReadOnly=$true;$script:GamingStatusBox.BackColor=$C.Surface2;$script:GamingStatusBox.ForeColor=$C.Text;$script:GamingStatusBox.Font=New-Object Drawing.Font('Consolas',10);$script:GamingStatusBox.Location=New-Object Drawing.Point(14,58);$script:GamingStatusBox.Size=New-Object Drawing.Size(760,115);$script:GamingStatusBox.Text=Get-GamingStatus
    $refresh=New-Button 'ATUALIZAR STATUS' ({$script:GamingStatusBox.Text=Get-GamingStatus});$refresh.Location=New-Object Drawing.Point(820,72);$refresh.Width=220
    $status.Controls.AddRange(@($script:GamingStatusBox,$refresh));Add-FlowControl $f $status 1100

    $card=New-Card '1-clique para jogos' 'Windows: Game Mode, captura OFF, CPU jogo, Power Throttling OFF, mouse direto e menos trafego de fundo.';$card.Width=1100;$card.Height=120
    $b1=New-Button 'OTIMIZAR WINDOWS' ({Apply-WindowsGamingProfile;$script:GamingStatusBox.Text=Get-GamingStatus}) -Primary;$b1.Location=New-Object Drawing.Point(20,68);$b1.Width=220
    $b2=New-Button 'REDE BAIXA LATENCIA' ({Apply-NetworkGaming});$b2.Location=New-Object Drawing.Point(255,68);$b2.Width=220
    $b3=New-Button 'MIRA / MOUSE DIRETO' ({Apply-InputLowLatency});$b3.Location=New-Object Drawing.Point(490,68);$b3.Width=220
    $b4=New-Button 'APPS DE INICIALIZACAO' ({Start-Process 'ms-settings:startupapps'});$b4.Location=New-Object Drawing.Point(725,68);$b4.Width=250
    $card.Controls.AddRange(@($b1,$b2,$b3,$b4));Add-FlowControl $f $card 1100

    $fc=New-Card 'Fortnite · FPS + stretched' 'Fecha o jogo, cria backup e aplica graficos baixos, V-Sync OFF, limite de FPS liberado, fullscreen e resolucao escolhida.';$fc.Width=1100;$fc.Height=165
    $labW=New-Label 'Largura' 9 $C.Muted;$labW.Location=New-Object Drawing.Point(20,65)
    $script:FortWidth=New-Object Windows.Forms.TextBox;$script:FortWidth.Text='1280';$script:FortWidth.Location=New-Object Drawing.Point(20,88);$script:FortWidth.Size=New-Object Drawing.Size(110,28);$script:FortWidth.BackColor=$C.Surface2;$script:FortWidth.ForeColor=$C.Text;$script:FortWidth.BorderStyle='FixedSingle'
    $labH=New-Label 'Altura' 9 $C.Muted;$labH.Location=New-Object Drawing.Point(145,65)
    $script:FortHeight=New-Object Windows.Forms.TextBox;$script:FortHeight.Text='720';$script:FortHeight.Location=New-Object Drawing.Point(145,88);$script:FortHeight.Size=New-Object Drawing.Size(110,28);$script:FortHeight.BackColor=$C.Surface2;$script:FortHeight.ForeColor=$C.Text;$script:FortHeight.BorderStyle='FixedSingle'
    $pres=New-Button '1280x960 STRETCHED' ({$script:FortWidth.Text='1280';$script:FortHeight.Text='960'});$pres.Location=New-Object Drawing.Point(275,84);$pres.Width=190
    $pres2=New-Button '1440x1080 STRETCHED' ({$script:FortWidth.Text='1440';$script:FortHeight.Text='1080'});$pres2.Location=New-Object Drawing.Point(480,84);$pres2.Width=205
    $applyF=New-Button 'APLICAR FORTNITE' ({$w=0;$h=0;if([int]::TryParse($script:FortWidth.Text,[ref]$w) -and [int]::TryParse($script:FortHeight.Text,[ref]$h)){Apply-FortnitePerformance $w $h;$script:GamingStatusBox.Text=Get-GamingStatus}else{Show-Warn 'Digite largura e altura validas.'}}) -Primary;$applyF.Location=New-Object Drawing.Point(700,84);$applyF.Width=180
    $restoreF=New-Button 'RESTAURAR JOGO' ({Restore-FortniteConfig});$restoreF.Location=New-Object Drawing.Point(895,84);$restoreF.Width=165
    $fc.Controls.AddRange(@($labW,$script:FortWidth,$labH,$script:FortHeight,$pres,$pres2,$applyF,$restoreF));Add-FlowControl $f $fc 1100

    $all=New-Card 'Perfil completo' 'Aplica o perfil do Windows e depois o Fortnite com a resolucao acima.';$all.Width=1100;$all.Height=100
    $allBtn=New-Button 'FORTNITE + WINDOWS' ({$w=0;$h=0;if([int]::TryParse($script:FortWidth.Text,[ref]$w) -and [int]::TryParse($script:FortHeight.Text,[ref]$h)){Apply-GameAll $w $h;$script:GamingStatusBox.Text=Get-GamingStatus}else{Show-Warn 'Digite largura e altura validas.'}}) -Primary;$allBtn.Location=New-Object Drawing.Point(20,52);$allBtn.Width=250
    $gpuBtn=New-Button 'GPU ALTO DESEMPENHO' ({if(Set-FortniteHighGpu){Show-Info 'Fortnite definido como Alto desempenho nas preferencias graficas do Windows.'}});$gpuBtn.Location=New-Object Drawing.Point(285,52);$gpuBtn.Width=235
    $hOn=New-Button 'HAGS ON' ({Set-HAGS $true});$hOn.Location=New-Object Drawing.Point(535,52);$hOn.Width=130
    $hOff=New-Button 'HAGS OFF' ({Set-HAGS $false});$hOff.Location=New-Object Drawing.Point(680,52);$hOff.Width=130
    $all.Controls.AddRange(@($allBtn,$gpuBtn,$hOn,$hOff));Add-FlowControl $f $all 1100

    Add-FlowControl $f (New-Label 'RAM limpa: nao uso memory cleaner que esvazia standby/working set e pode aumentar stutter. Para reduzir RAM de verdade, feche apps pesados e remova os desnecessarios da inicializacao.' 9 $C.Yellow) 1100
}

Add-Page 'clean' '⌫  Limpeza' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Limpeza real de cache e temporarios' 17 $C.Text -Bold) 1100;Add-FlowControl $f (New-Label 'Nao apaga senhas, favoritos nem documentos. Arquivos em uso sao ignorados.' 9 $C.Muted) 1100
    $script:CleanGrid=New-Object Windows.Forms.DataGridView;$script:CleanGrid.Width=1100;$script:CleanGrid.Height=470;$script:CleanGrid.BackgroundColor=$C.Surface;$script:CleanGrid.ForeColor=$C.Text;$script:CleanGrid.RowHeadersVisible=$false;$script:CleanGrid.AllowUserToAddRows=$false;$script:CleanGrid.AutoSizeColumnsMode='Fill';$script:CleanGrid.EnableHeadersVisualStyles=$false;$script:CleanGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:CleanGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:CleanGrid.DefaultCellStyle.BackColor=$C.Surface;$script:CleanGrid.DefaultCellStyle.ForeColor=$C.Text;$sel=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$sel.Name='Sel';$sel.HeaderText='Limpar';$sel.FillWeight=15;[void]$script:CleanGrid.Columns.Add($sel);[void]$script:CleanGrid.Columns.Add('Name','Categoria');[void]$script:CleanGrid.Columns.Add('Size','Tamanho');[void]$script:CleanGrid.Columns.Add('Path','Caminho')
    $script:CleanScan={ $script:CleanGrid.Rows.Clear();foreach($t in Get-CleanupTargets){$size=Get-FolderSize $t.Path;$i=$script:CleanGrid.Rows.Add($true,$t.Name,(Format-Bytes $size),$t.Path);$script:CleanGrid.Rows[$i].Tag=$t}}
    &$script:CleanScan;Add-FlowControl $f $script:CleanGrid 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'Analisar novamente' $script:CleanScan))
    $row.Controls.Add((New-Button 'LIMPAR SELECIONADOS' ({if(!(Confirm 'Apagar os caches/temporarios selecionados?')){return};$freed=0;foreach($r in $script:CleanGrid.Rows){if([bool]$r.Cells['Sel'].Value){$t=$r.Tag;if($t.Admin -and !(Is-Admin)){continue};$freed+=Clear-FolderSafe $t.Path}};Show-Info("Limpeza concluida. Liberado aproximadamente: $(Format-Bytes $freed)");&$script:CleanScan}) -Primary))
    Add-FlowControl $f $row 1100
}

Add-Page 'tweaks' '⚙  Tweaks / Regedit' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Tweaks reversiveis de Windows / Regedit' 17 $C.Text -Bold) 1100
    $script:TweaksGrid=New-Object Windows.Forms.DataGridView;$script:TweaksGrid.Width=1100;$script:TweaksGrid.Height=510;$script:TweaksGrid.BackgroundColor=$C.Surface;$script:TweaksGrid.ForeColor=$C.Text;$script:TweaksGrid.RowHeadersVisible=$false;$script:TweaksGrid.AllowUserToAddRows=$false;$script:TweaksGrid.ReadOnly=$true;$script:TweaksGrid.SelectionMode='FullRowSelect';$script:TweaksGrid.AutoSizeColumnsMode='Fill';$script:TweaksGrid.EnableHeadersVisualStyles=$false;$script:TweaksGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:TweaksGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:TweaksGrid.DefaultCellStyle.BackColor=$C.Surface;$script:TweaksGrid.DefaultCellStyle.ForeColor=$C.Text;[void]$script:TweaksGrid.Columns.Add('Name','Ajuste');[void]$script:TweaksGrid.Columns.Add('Desc','Para que serve');[void]$script:TweaksGrid.Columns.Add('State','Estado')
    $script:TweaksRefresh={ $script:TweaksGrid.Rows.Clear();foreach($tw in $script:Tweaks){$st=Get-TweakEnabled $tw;$txt=if($null -eq $st){'Nao configurado'}elseif($st){'ATIVO'}else{'INATIVO'};$i=$script:TweaksGrid.Rows.Add($tw.Name,$tw.Desc,$txt);$script:TweaksGrid.Rows[$i].Tag=$tw}}
    &$script:TweaksRefresh;Add-FlowControl $f $script:TweaksGrid 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true
    $row.Controls.Add((New-Button 'ATIVAR' ({if($script:TweaksGrid.SelectedRows.Count){Set-Tweak $script:TweaksGrid.SelectedRows[0].Tag $true;&$script:TweaksRefresh}}) -Primary));$row.Controls.Add((New-Button 'DESATIVAR' ({if($script:TweaksGrid.SelectedRows.Count){Set-Tweak $script:TweaksGrid.SelectedRows[0].Tag $false;&$script:TweaksRefresh}})));$row.Controls.Add((New-Button 'RESTAURAR desta sessao' ({if($script:TweaksGrid.SelectedRows.Count){$tw=$script:TweaksGrid.SelectedRows[0].Tag;Restore-Reg $tw.Path $tw.Value;&$script:TweaksRefresh}})))
    Add-FlowControl $f $row 1100
}

Add-Page 'max' 'BOOST  CPU / GPU Max' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'CPU / GPU · desempenho maximo controlado' 17 $C.Text -Bold) 1100
    Add-FlowControl $f (New-Label 'Nao faz overclock de tensao. Usa plano de energia, boost, core parking e preferencias graficas do Windows.' 9 $C.Muted) 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'CPU JOGO' ({Apply-CPU-Max $false}) -Primary));$row.Controls.Add((New-Button 'CPU EXTREMO' ({Apply-CPU-Max $true})));$row.Controls.Add((New-Button 'HAGS ON' ({Set-HAGS $true})));$row.Controls.Add((New-Button 'HAGS OFF' ({Set-HAGS $false})));$row.Controls.Add((New-Button 'GPU alto desempenho por jogo' ({Set-AppHighGpu}) -Primary));Add-FlowControl $f $row 1100
    Add-FlowControl $f (New-Label 'CPU EXTREMO mantem minimo em 100% na tomada e pode aumentar muito temperatura/consumo. Compare FPS e frametime.' 9 $C.Yellow) 1100
}

Add-Page 'drivers' '↻  Drivers' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Drivers instalados e atualizacoes disponiveis' 17 $C.Text -Bold) 1100
    $script:DriversGrid=New-Object Windows.Forms.DataGridView;$script:DriversGrid.Width=1100;$script:DriversGrid.Height=450;$script:DriversGrid.BackgroundColor=$C.Surface;$script:DriversGrid.ForeColor=$C.Text;$script:DriversGrid.RowHeadersVisible=$false;$script:DriversGrid.AllowUserToAddRows=$false;$script:DriversGrid.ReadOnly=$true;$script:DriversGrid.AutoSizeColumnsMode='Fill';$script:DriversGrid.EnableHeadersVisualStyles=$false;$script:DriversGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:DriversGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:DriversGrid.DefaultCellStyle.BackColor=$C.Surface;$script:DriversGrid.DefaultCellStyle.ForeColor=$C.Text;[void]$script:DriversGrid.Columns.Add('Name','Dispositivo');[void]$script:DriversGrid.Columns.Add('Provider','Fornecedor');[void]$script:DriversGrid.Columns.Add('Version','Versao');[void]$script:DriversGrid.Columns.Add('Date','Data');[void]$script:DriversGrid.Columns.Add('Inf','INF')
    $script:DriversLoad={ $script:DriversGrid.Rows.Clear();Get-CimInstance Win32_PnPSignedDriver|Where-Object{$_.DeviceName}|Sort-Object DeviceName|ForEach-Object{[void]$script:DriversGrid.Rows.Add($_.DeviceName,$_.DriverProviderName,$_.DriverVersion,$_.DriverDate,$_.InfName)}};&$script:DriversLoad;Add-FlowControl $f $script:DriversGrid 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'Atualizar lista' $script:DriversLoad));
    $row.Controls.Add((New-Button 'Buscar drivers no Windows Update' ({
        try{$sess=New-Object -ComObject Microsoft.Update.Session;$search=$sess.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Driver'");$names=@();for($i=0;$i -lt $search.Updates.Count;$i++){$names+=$search.Updates.Item($i).Title};Show-Info($(if($names.Count){"Drivers encontrados:`r`n`r`n"+($names -join "`r`n")}else{'Nenhum driver pendente encontrado pelo Windows Update.'}))}catch{Show-Warn 'Nao foi possivel consultar drivers pelo Windows Update.'}
    }) -Primary));
    $row.Controls.Add((New-Button 'Abrir AMD' ({Start-Process 'https://www.amd.com/en/support/download/drivers.html'})));$row.Controls.Add((New-Button 'Abrir NVIDIA' ({Start-Process 'https://www.nvidia.com/Download/index.aspx'})));$row.Controls.Add((New-Button 'Abrir Intel' ({Start-Process 'https://www.intel.com/content/www/us/en/support/detect.html'})));$row.Controls.Add((New-Button 'Abrir MSI' ({Start-Process 'https://www.msi.com/support'})));Add-FlowControl $f $row 1100
}

Add-Page 'disk' 'DISK  Disco / Armazenamento' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Armazenamento e desempenho do disco' 17 $C.Text -Bold) 1100
    $script:DiskBox=New-Object Windows.Forms.TextBox;$script:DiskBox.Multiline=$true;$script:DiskBox.ReadOnly=$true;$script:DiskBox.BackColor=$C.Surface;$script:DiskBox.ForeColor=$C.Text;$script:DiskBox.Font=New-Object Drawing.Font('Consolas',10);$script:DiskBox.Height=330
    $script:DiskRead={ $sb=New-Object Text.StringBuilder;foreach($d in Get-CimInstance Win32_DiskDrive){[void]$sb.AppendLine("$($d.Model) · $(Format-Bytes $d.Size) · $($d.MediaType) · $($d.InterfaceType)")};[void]$sb.AppendLine('');try{[void]$sb.AppendLine((fsutil behavior query DisableDeleteNotify|Out-String).Trim())}catch{};$script:DiskBox.Text=$sb.ToString()};&$script:DiskRead;Add-FlowControl $f $script:DiskBox 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'Atualizar' $script:DiskRead));$row.Controls.Add((New-Button 'ReTRIM C:' ({if(Need-Admin){Optimize-Volume -DriveLetter C -ReTrim -Verbose|Out-String|ForEach-Object{Show-Info $_}}}) -Primary));$row.Controls.Add((New-Button 'Otimizar C: /O' ({if(Need-Admin){Start-Process defrag.exe -ArgumentList 'C: /O /U /V' -Verb RunAs}})));$row.Controls.Add((New-Button 'CHKDSK /scan' ({if(Need-Admin){Start-Process chkdsk.exe -ArgumentList 'C: /scan' -Verb RunAs}})));Add-FlowControl $f $row 1100
}

Add-Page 'net' 'NET  Rede / Som' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Rede e audio' 17 $C.Text -Bold) 1100
    $script:NetBox=New-Object Windows.Forms.TextBox;$script:NetBox.Multiline=$true;$script:NetBox.ReadOnly=$true;$script:NetBox.BackColor=$C.Surface;$script:NetBox.ForeColor=$C.Text;$script:NetBox.Font=New-Object Drawing.Font('Consolas',10);$script:NetBox.Height=420
    $script:NetRead={ $sb=New-Object Text.StringBuilder;[void]$sb.AppendLine('REDE:');Get-CimInstance Win32_NetworkAdapter|Where-Object{$_.NetEnabled}|ForEach-Object{[void]$sb.AppendLine("$($_.Name) · $($_.Speed) bps · MAC $($_.MACAddress)")};[void]$sb.AppendLine('');[void]$sb.AppendLine('AUDIO:');Get-CimInstance Win32_SoundDevice|ForEach-Object{[void]$sb.AppendLine("$($_.Name) · $($_.Status)")};$script:NetBox.Text=$sb.ToString()};&$script:NetRead;Add-FlowControl $f $script:NetBox 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.Controls.Add((New-Button 'Abrir Rede' ({Start-Process 'ms-settings:network-status'}) -Primary));$row.Controls.Add((New-Button 'Abrir Som' ({Start-Process 'ms-settings:sound'})));$row.Controls.Add((New-Button 'Testar ping' ({Start-Process powershell.exe -ArgumentList '-NoExit','-Command','ping 1.1.1.1 -t'})));Add-FlowControl $f $row 1100
}

Add-Page 'oosu' 'O&O  Recomendado' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Privacidade / O&O-style recomendado' 17 $C.Text -Bold) 1100;Add-FlowControl $f (New-Label 'Apenas ajustes conservadores equivalentes aos controles recomendados que voce selecionou anteriormente.' 9 $C.Muted) 1100
    $items=$script:Tweaks|Where-Object{$_.Id -in @('telemetry','consumer','delivery','widgets','copilot','notifications','gamedvr')}
    foreach($tw in $items){$card=New-Card $tw.Name $tw.Desc;$card.Width=1060;$card.Height=82;$on=New-Button 'ATIVAR' ({param($s,$e);Set-Tweak $s.Tag $true}) -Primary;$off=New-Button 'DESATIVAR' ({param($s,$e);Set-Tweak $s.Tag $false});$on.Tag=$tw;$off.Tag=$tw;$on.Location=New-Object Drawing.Point(800,20);$off.Location=New-Object Drawing.Point(910,20);$card.Controls.AddRange(@($on,$off));Add-FlowControl $f $card 1080}
}

# Primeira pagina
$pages['dash'].Visible=$true;$pages['dash'].BringToFront();$navButtons['dash'].BackColor=$C.Cyan;$navButtons['dash'].ForeColor=$C.Bg

# Timer realtime
$script:MainTimer=New-Object Windows.Forms.Timer;$script:MainTimer.Interval=750;$tick=0
$script:MainTimer.Add_Tick({
    $tick++
    $m=Get-Metrics
    if($cpuV){$cpuV.Text=('{0:N0}%' -f $m.CPU)};if($ramV){$ramV.Text=('{0:N0}%' -f $m.RAM)};if($diskV){$diskV.Text=('{0:N0}%' -f $m.Disk)};if($gpuV){$gpuV.Text=$(if($null -eq $m.GPU){'N/D'}else{('{0:N0}%' -f $m.GPU)})};if($netV){$netV.Text=((Format-Bytes $m.NetDown)+'/s')};if($tempV){$tempV.Text=$(if($null -eq $m.Temp){'N/D'}else{"$($m.Temp) °C"})}
    if($procGrid -and ($tick % 2 -eq 0)){$procGrid.Rows.Clear();foreach($r in Get-TopProcesses){[void]$procGrid.Rows.Add($r.Name,$r.PercentProcessorTime,(Format-Bytes $r.WorkingSetPrivate),(Format-Bytes $r.IOReadBytesPersec),(Format-Bytes $r.IOWriteBytesPersec))}}
})
$script:MainTimer.Start();$form.Add_FormClosed({$script:MainTimer.Stop();$script:MainTimer.Dispose()})
[void]$form.ShowDialog()
    $line="$Key=$Value"
    if([regex]::IsMatch($Content,$pattern)){return [regex]::Replace($Content,$pattern,$line)}
    return ($Content.TrimEnd()+[Environment]::NewLine+$line+[Environment]::NewLine)
}
function Backup-FortniteConfig {
    $cfg=Get-FortniteConfigPath
    if(!$cfg){Show-Warn 'Fortnite GameUserSettings.ini nao foi encontrado. Abra o Fortnite pelo menos uma vez.';return $null}
    $bak="$cfg.larq-backup"
    try{
        if(!(Test-Path $bak)){Copy-Item $cfg $bak -Force}
        return $bak
    }catch{Show-Warn "Nao foi possivel criar o backup: $($_.Exception.Message)";return $null}
}
function Restore-FortniteConfig {
    $cfg=Get-FortniteConfigPath
    if(!$cfg){Show-Warn 'Configuracao do Fortnite nao encontrada.';return}
    $bak="$cfg.larq-backup"
    if(!(Test-Path $bak)){Show-Warn 'Ainda nao existe backup criado pelo LarqOtimizer.';return}
    if(Get-Process FortniteClient-Win64-Shipping -EA SilentlyContinue){Show-Warn 'Feche o Fortnite antes de restaurar a configuracao.';return}
    Copy-Item $bak $cfg -Force
    Show-Info 'Configuracao original do Fortnite restaurada.'
}
function Set-FortniteHighGpu {
    $exe=Find-FortniteExe
    if(!$exe){Show-Warn 'Fortnite nao foi localizado automaticamente. Use GPU alto desempenho por jogo e selecione o executavel manualmente.';return $false}
    $path='HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if(!(Test-Path $path)){New-Item $path -Force|Out-Null}
    New-ItemProperty $path -Name $exe -Value 'GpuPreference=2;' -PropertyType String -Force|Out-Null
    return $true
}
function Apply-FortnitePerformance([int]$Width,[int]$Height){
    if(Get-Process FortniteClient-Win64-Shipping -EA SilentlyContinue){Show-Warn 'Feche o Fortnite antes de aplicar as configuracoes.';return}
    if($Width -lt 800 -or $Height -lt 600){Show-Warn 'Resolucao invalida.';return}
    $cfg=Get-FortniteConfigPath
    if(!$cfg){Show-Warn 'Fortnite nao foi encontrado. Abra o jogo pelo menos uma vez para criar GameUserSettings.ini.';return}
    if(!(Backup-FortniteConfig)){return}
    try{
        $c=Get-Content $cfg -Raw -EA Stop
        $pairs=[ordered]@{
            'bUseVSync'='False'
            'bUseDynamicResolution'='False'
            'bMotionBlur'='False'
            'bDisableMouseAcceleration'='True'
            'FrameRateLimit'='0.000000'
            'ResolutionSizeX'=[string]$Width
            'ResolutionSizeY'=[string]$Height
            'LastUserConfirmedResolutionSizeX'=[string]$Width
            'LastUserConfirmedResolutionSizeY'=[string]$Height
            'DesiredScreenWidth'=[string]$Width
            'DesiredScreenHeight'=[string]$Height
            'FullscreenMode'='0'
            'LastConfirmedFullscreenMode'='0'
            'PreferredFullscreenMode'='0'
            'sg.ViewDistanceQuality'='0'
            'sg.AntiAliasingQuality'='0'
            'sg.ShadowQuality'='0'
            'sg.GlobalIlluminationQuality'='0'
            'sg.ReflectionQuality'='0'
            'sg.PostProcessQuality'='0'
            'sg.TextureQuality'='0'
            'sg.EffectsQuality'='0'
            'sg.FoliageQuality'='0'
            'sg.ShadingQuality'='0'
        }
        foreach($k in $pairs.Keys){$c=Set-IniValue $c $k $pairs[$k]}
        Set-Content -LiteralPath $cfg -Value $c -Encoding UTF8 -Force
        [void](Set-FortniteHighGpu)
        Show-Info ("Fortnite otimizado para FPS. Resolucao: "+$Width+"x"+$Height+". Use o modo Performance dentro do jogo para comparar. Backup criado antes da alteracao.")
    }catch{Show-Warn "Falha ao alterar Fortnite: $($_.Exception.Message)"}
}
function Apply-InputLowLatency {
    Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0'
    Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0'
    Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0'
    Show-Info 'Aceleracao do ponteiro desativada. Para resposta consistente, deixe a velocidade do ponteiro do Windows em 6/11.'
}
function Apply-NetworkGaming {
    if(!(Need-Admin)){return}
    try{netsh int tcp set global rss=enabled | Out-Null}catch{}
    try{netsh int tcp set global autotuninglevel=normal | Out-Null}catch{}
    $tw=$script:Tweaks|Where-Object{$_.Id -eq 'delivery'}|Select-Object -First 1
    if($tw){Set-Tweak $tw $true}
    Show-Info 'Perfil de rede seguro aplicado: RSS ligado, TCP Auto-Tuning normal e Delivery Optimization P2P desligado. Isso pode reduzir trafego de fundo, mas nao garante ping menor.'
}
function Apply-WindowsGamingProfile {
    if(!(Need-Admin)){return}
    Apply-CPU-Max $false
    foreach($id in @('gamemode','gamedvr','powerthrottle','widgets','notifications','delivery')){
        $tw=$script:Tweaks|Where-Object{$_.Id -eq $id}|Select-Object -First 1
        if($tw){Set-Tweak $tw $true}
    }
    Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0'
    Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0'
    Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0'
    Show-Info 'Perfil Windows para jogos aplicado. HAGS continua separado para voce comparar ON/OFF, pois o melhor resultado depende da GPU e do driver.'
}
function Apply-GameAll([int]$Width,[int]$Height){
    if(!(Confirm ("Aplicar perfil Windows + Fortnite "+$Width+"x"+$Height+"? O Fortnite deve estar fechado."))){return}
    Apply-WindowsGamingProfile
    Apply-FortnitePerformance $Width $Height
}
function Get-GamingStatus {
    $cfg=Get-FortniteConfigPath
    $exe=Find-FortniteExe
    $gm=$script:Tweaks|Where-Object{$_.Id -eq 'gamemode'}|Select-Object -First 1
    $dvr=$script:Tweaks|Where-Object{$_.Id -eq 'gamedvr'}|Select-Object -First 1
    $pt=$script:Tweaks|Where-Object{$_.Id -eq 'powerthrottle'}|Select-Object -First 1
    $ms=Read-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed'
    $hags=Read-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    $lines=@(
        "Fortnite config: " + $(if($cfg){'ENCONTRADO'}else{'NAO ENCONTRADO'}),
        "Fortnite exe: " + $(if($exe){'ENCONTRADO'}else{'NAO ENCONTRADO'}),
        "Game Mode: " + $(if((Get-TweakEnabled $gm)){'ON'}else{'OFF / padrao'}),
        "Game DVR/captura: " + $(if((Get-TweakEnabled $dvr)){'OFF'}else{'ON / padrao'}),
        "Power Throttling: " + $(if((Get-TweakEnabled $pt)){'OFF'}else{'ON / padrao'}),
        "Aceleracao do mouse: " + $(if([string]$ms -eq '0'){'OFF'}else{'ON / padrao'}),
        "HAGS: " + $(if([string]$hags -eq '2'){'ON'}elseif([string]$hags -eq '1'){'OFF'}else{'PADRAO / N-D'})
    )
    return ($lines -join [Environment]::NewLine)
}

# ---------- Hardware ----------
function Hardware-Text {
    $sb=New-Object Text.StringBuilder
    try{$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1; [void]$sb.AppendLine("CPU: $($cpu.Name)");[void]$sb.AppendLine("Cores/Threads: $($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)");[void]$sb.AppendLine("Clock max publicado: $($cpu.MaxClockSpeed) MHz") }catch{}
    try{$bb=Get-CimInstance Win32_BaseBoard|Select-Object -First 1;[void]$sb.AppendLine("Placa-mae: $($bb.Manufacturer) $($bb.Product)")}catch{}
    try{$bios=Get-CimInstance Win32_BIOS|Select-Object -First 1;[void]$sb.AppendLine("BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)")}catch{}
    try{$ram=Get-CimInstance Win32_PhysicalMemory;$sum=($ram|Measure-Object Capacity -Sum).Sum;[void]$sb.AppendLine("RAM: $(Format-Bytes $sum) · modulos: $($ram.Count)"); foreach($r in $ram){[void]$sb.AppendLine("  $([math]::Round($r.Capacity/1GB)) GB · $($r.Speed) MHz · $($r.Manufacturer)")}}catch{}
    try{foreach($g in Get-CimInstance Win32_VideoController){[void]$sb.AppendLine("GPU: $($g.Name) · driver $($g.DriverVersion) · VRAM publicada $(Format-Bytes $g.AdapterRAM)")}}catch{}
    try{foreach($d in Get-CimInstance Win32_DiskDrive){[void]$sb.AppendLine("Disco: $($d.Model) · $(Format-Bytes $d.Size) · $($d.InterfaceType)")}}catch{}
    return $sb.ToString()
}
function Bios-Text {
    $sb=New-Object Text.StringBuilder
    try{$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1; [void]$sb.AppendLine("SMT: " + $(if($cpu.NumberOfLogicalProcessors -gt $cpu.NumberOfCores){'ATIVO/threads publicados'}else{'NAO detectado'})); [void]$sb.AppendLine("Virtualizacao Firmware: $($cpu.VirtualizationFirmwareEnabled)")}catch{}
    try{[void]$sb.AppendLine("Secure Boot: " + $(if(Confirm-SecureBootUEFI -EA Stop){'ATIVO'}else{'DESATIVADO'}))}catch{[void]$sb.AppendLine('Secure Boot: N/D')}
    try{$ci=Get-ComputerInfo -Property BiosFirmwareType;[void]$sb.AppendLine("Firmware: $($ci.BiosFirmwareType)")}catch{}
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Itens que o Windows normalmente NAO consegue confirmar em placa-mae desktop:')
    [void]$sb.AppendLine('• A-XMP/XMP/DOCP: conferir manualmente na BIOS.')
    [void]$sb.AppendLine('• PBO/Curve Optimizer: conferir manualmente; nao aplicar tensao automaticamente.')
    [void]$sb.AppendLine('• UMA Frame Buffer: relevante ao usar iGPU; conferir manualmente.')
    [void]$sb.AppendLine('• Curva das ventoinhas: conferir no Hardware Monitor da BIOS.')
    return $sb.ToString()
}

# ---------- App ----------
if(-not (Show-Login)){return}

$form=New-Object Windows.Forms.Form
$form.Text='LarqOtimizer · PowerShell Edition'; $form.StartPosition='CenterScreen'; $form.Size=New-Object Drawing.Size(1460,900); $form.MinimumSize=New-Object Drawing.Size(1100,700); $form.BackColor=$C.Bg; $form.ForeColor=$C.Text

$side=New-Object Windows.Forms.Panel; $side.Dock='Left';$side.Width=245;$side.BackColor=$C.Surface;$side.Padding=New-Object Windows.Forms.Padding(12)
$logo=New-Label '⚡  LARQOTIMIZER  PRO' 13 $C.Cyan -Bold; $logo.Dock='Top';$logo.Height=70;$logo.AutoSize=$false;$logo.TextAlign='MiddleLeft';$side.Controls.Add($logo)
$nav=New-Object Windows.Forms.FlowLayoutPanel;$nav.Dock='Fill';$nav.FlowDirection='TopDown';$nav.WrapContents=$false;$nav.AutoScroll=$true;$nav.BackColor=$C.Surface;$side.Controls.Add($nav);$nav.BringToFront()
$admin=New-Label ($(if(Is-Admin){'● Administrador'}else{'○ Usuario normal'})) 8 $(if(Is-Admin){$C.Green}else{$C.Yellow});$admin.Dock='Bottom';$admin.Height=32;$admin.AutoSize=$false;$side.Controls.Add($admin)

$host=New-Object Windows.Forms.Panel;$host.Dock='Fill';$host.BackColor=$C.Bg
$header=New-Object Windows.Forms.Panel;$header.Dock='Top';$header.Height=68;$header.BackColor=$C.Surface;$header.Padding=New-Object Windows.Forms.Padding(20,10,20,8)
$headerTitle=New-Label 'Visao Geral' 14 $C.Text -Bold;$headerTitle.Dock='Left';$headerTitle.Width=430;$headerTitle.AutoSize=$false;$headerTitle.TextAlign='MiddleLeft'
$quick=New-Button '⚡ MODO MAXIMO CPU + GPU' ({if(Confirm 'Aplicar perfil maximo de CPU + ajustes de jogos? Pode aumentar temperatura/consumo.'){Apply-CPU-Max $true}}) -Primary;$quick.Dock='Right';$quick.Width=235
$header.Controls.AddRange(@($quick,$headerTitle))
$content=New-Object Windows.Forms.Panel;$content.Dock='Fill';$content.BackColor=$C.Bg
$host.Controls.Add($content);$host.Controls.Add($header)
$form.Controls.Add($host);$form.Controls.Add($side)

$pages=@{};$navButtons=@{}
function Add-Page([string]$Id,[string]$Title,[scriptblock]$Build){
    $p=New-Page;&$Build $p;$p.Visible=$false;$content.Controls.Add($p);$pages[$Id]=$p
    $b=New-Button $Title ({param($s,$e); $ctx=$s.Tag; foreach($k in $pages.Keys){$pages[$k].Visible=$false;$navButtons[$k].BackColor=$C.Surface2;$navButtons[$k].ForeColor=$C.Text};$pages[$ctx.Id].Visible=$true;$pages[$ctx.Id].BringToFront();$s.BackColor=$C.Cyan;$s.ForeColor=$C.Bg;$headerTitle.Text=$ctx.Title})
    $b.Tag=[pscustomobject]@{Id=$Id;Title=$Title}
    $b.Width=205;$b.Height=40;$b.Margin=New-Object Windows.Forms.Padding(2,2,2,2);$nav.Controls.Add($b);$navButtons[$Id]=$b
}

# Dashboard labels globais
$cpuV=$null;$ramV=$null;$diskV=$null;$gpuV=$null;$netV=$null;$tempV=$null;$procGrid=$null
Add-Page 'dash' '▦  Visao Geral' {
    param($p)
    $flow=New-Flow;$p.Controls.Add($flow)
    $hero=New-Card 'Seu PC em tempo real' 'Atualizacao rapida de CPU, RAM, GPU, disco e rede.';$hero.Height=100;$hero.Width=1100
    $heroBtn=New-Button 'OTIMIZAR COM 1-CLIQUE' ({if(Confirm 'Aplicar ajustes recomendados de desempenho?'){Apply-CPU-Max $false; foreach($tw in $script:Tweaks|Where-Object{$_.Id -in @('gamemode','gamedvr','powerthrottle','widgets')}){Set-Tweak $tw $true}}}) -Primary;$heroBtn.Location=New-Object Drawing.Point(820,25);$heroBtn.Width=245;$hero.Controls.Add($heroBtn);Add-FlowControl $flow $hero 1100
    $metrics=New-Object Windows.Forms.FlowLayoutPanel;$metrics.AutoSize=$true;$metrics.WrapContents=$true;$metrics.BackColor=$C.Bg
    foreach($m in @(@('CPU','cpuV',$C.Cyan),@('RAM','ramV',$C.Purple),@('DISCO','diskV',$C.Green),@('GPU 3D','gpuV',$C.Cyan),@('REDE','netV',$C.Purple),@('TEMPERATURA','tempV',$C.Yellow))){
        $card=New-Card $m[0];$card.Width=175;$card.Height=100;$lab=New-Label '—' 18 $m[2] -Bold;$lab.Location=New-Object Drawing.Point(14,48);$card.Controls.Add($lab);Set-Variable -Scope Script -Name $m[1] -Value $lab;$metrics.Controls.Add($card)
    }
    Add-FlowControl $flow $metrics 1120
    Add-FlowControl $flow (New-Label 'Processos em tempo real' 14 $C.Text -Bold) 1100
    $procGrid=New-Object Windows.Forms.DataGridView;$procGrid.Width=1100;$procGrid.Height=380;$procGrid.BackgroundColor=$C.Surface;$procGrid.ForeColor=$C.Text;$procGrid.GridColor=$C.Border;$procGrid.RowHeadersVisible=$false;$procGrid.AllowUserToAddRows=$false;$procGrid.ReadOnly=$true;$procGrid.SelectionMode='FullRowSelect';$procGrid.AutoSizeColumnsMode='Fill';$procGrid.EnableHeadersVisualStyles=$false;$procGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$procGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$procGrid.DefaultCellStyle.BackColor=$C.Surface;$procGrid.DefaultCellStyle.ForeColor=$C.Text;$procGrid.DefaultCellStyle.SelectionBackColor=[Drawing.Color]::FromArgb(16,45,58);[void]$procGrid.Columns.Add('Name','Processo');[void]$procGrid.Columns.Add('CPU','CPU %');[void]$procGrid.Columns.Add('RAM','RAM');[void]$procGrid.Columns.Add('Read','Leitura/s');[void]$procGrid.Columns.Add('Write','Gravacao/s');Add-FlowControl $flow $procGrid 1100
}

Add-Page 'hardware' 'CPU  Hardware' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Hardware detectado pelo Windows' 17 $C.Text -Bold) 1100
    $script:HardwareBox=New-Object Windows.Forms.TextBox;$script:HardwareBox.Multiline=$true;$script:HardwareBox.ReadOnly=$true;$script:HardwareBox.ScrollBars='Vertical';$script:HardwareBox.BackColor=$C.Surface;$script:HardwareBox.ForeColor=$C.Text;$script:HardwareBox.Font=New-Object Drawing.Font('Consolas',10);$script:HardwareBox.Height=600;$script:HardwareBox.Text=Hardware-Text;Add-FlowControl $f $script:HardwareBox 1100
    $r=New-Button 'Atualizar hardware' ({$script:HardwareBox.Text=Hardware-Text}) -Primary;Add-FlowControl $f $r 1100
}

Add-Page 'bios' 'BIOS  BIOS e estados' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'BIOS / UEFI e estados detectaveis' 17 $C.Text -Bold) 1100
    $tb=New-Object Windows.Forms.TextBox;$tb.Multiline=$true;$tb.ReadOnly=$true;$tb.ScrollBars='Vertical';$tb.BackColor=$C.Surface;$tb.ForeColor=$C.Text;$tb.Font=New-Object Drawing.Font('Consolas',10);$tb.Height=540;$tb.Text=Bios-Text;Add-FlowControl $f $tb 1100
    Add-FlowControl $f (New-Label 'O LarqOtimizer nao inventa estado de BIOS que o firmware nao publica para o Windows.' 9 $C.Yellow) 1100
}

Add-Page 'devices' 'USB  Perifericos / USB' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Perifericos conectados' 17 $C.Text -Bold) 1100
    $script:DevicesGrid=New-Object Windows.Forms.DataGridView;$script:DevicesGrid.Width=1100;$script:DevicesGrid.Height=580;$script:DevicesGrid.BackgroundColor=$C.Surface;$script:DevicesGrid.ForeColor=$C.Text;$script:DevicesGrid.RowHeadersVisible=$false;$script:DevicesGrid.AllowUserToAddRows=$false;$script:DevicesGrid.ReadOnly=$true;$script:DevicesGrid.AutoSizeColumnsMode='Fill';$script:DevicesGrid.EnableHeadersVisualStyles=$false;$script:DevicesGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:DevicesGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:DevicesGrid.DefaultCellStyle.BackColor=$C.Surface;$script:DevicesGrid.DefaultCellStyle.ForeColor=$C.Text;[void]$script:DevicesGrid.Columns.Add('Class','Classe');[void]$script:DevicesGrid.Columns.Add('Name','Dispositivo');[void]$script:DevicesGrid.Columns.Add('Status','Status');[void]$script:DevicesGrid.Columns.Add('Id','Device ID')
    $script:DevicesRefresh={ $script:DevicesGrid.Rows.Clear(); Get-CimInstance Win32_PnPEntity|Where-Object{$_.PNPClass -match 'Mouse|Keyboard|Monitor|USB|HID|Audio|Bluetooth|Net|Media'}|Sort-Object PNPClass,Name|ForEach-Object{[void]$script:DevicesGrid.Rows.Add($_.PNPClass,$_.Name,$_.Status,$_.DeviceID)} }
    &$script:DevicesRefresh;Add-FlowControl $f $script:DevicesGrid 1100;Add-FlowControl $f (New-Button 'Atualizar perifericos' $script:DevicesRefresh -Primary) 1100
}

Add-Page 'clean' '⌫  Limpeza' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Limpeza real de cache e temporarios' 17 $C.Text -Bold) 1100;Add-FlowControl $f (New-Label 'Nao apaga senhas, favoritos nem documentos. Arquivos em uso sao ignorados.' 9 $C.Muted) 1100
    $script:CleanGrid=New-Object Windows.Forms.DataGridView;$script:CleanGrid.Width=1100;$script:CleanGrid.Height=470;$script:CleanGrid.BackgroundColor=$C.Surface;$script:CleanGrid.ForeColor=$C.Text;$script:CleanGrid.RowHeadersVisible=$false;$script:CleanGrid.AllowUserToAddRows=$false;$script:CleanGrid.AutoSizeColumnsMode='Fill';$script:CleanGrid.EnableHeadersVisualStyles=$false;$script:CleanGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:CleanGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:CleanGrid.DefaultCellStyle.BackColor=$C.Surface;$script:CleanGrid.DefaultCellStyle.ForeColor=$C.Text;$sel=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$sel.Name='Sel';$sel.HeaderText='Limpar';$sel.FillWeight=15;[void]$script:CleanGrid.Columns.Add($sel);[void]$script:CleanGrid.Columns.Add('Name','Categoria');[void]$script:CleanGrid.Columns.Add('Size','Tamanho');[void]$script:CleanGrid.Columns.Add('Path','Caminho')
    $script:CleanScan={ $script:CleanGrid.Rows.Clear();foreach($t in Get-CleanupTargets){$size=Get-FolderSize $t.Path;$i=$script:CleanGrid.Rows.Add($true,$t.Name,(Format-Bytes $size),$t.Path);$script:CleanGrid.Rows[$i].Tag=$t}}
    &$script:CleanScan;Add-FlowControl $f $script:CleanGrid 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'Analisar novamente' $script:CleanScan))
    $row.Controls.Add((New-Button 'LIMPAR SELECIONADOS' ({if(!(Confirm 'Apagar os caches/temporarios selecionados?')){return};$freed=0;foreach($r in $script:CleanGrid.Rows){if([bool]$r.Cells['Sel'].Value){$t=$r.Tag;if($t.Admin -and !(Is-Admin)){continue};$freed+=Clear-FolderSafe $t.Path}};Show-Info("Limpeza concluida. Liberado aproximadamente: $(Format-Bytes $freed)");&$script:CleanScan}) -Primary))
    Add-FlowControl $f $row 1100
}

Add-Page 'tweaks' '⚙  Tweaks / Regedit' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Tweaks reversiveis de Windows / Regedit' 17 $C.Text -Bold) 1100
    $script:TweaksGrid=New-Object Windows.Forms.DataGridView;$script:TweaksGrid.Width=1100;$script:TweaksGrid.Height=510;$script:TweaksGrid.BackgroundColor=$C.Surface;$script:TweaksGrid.ForeColor=$C.Text;$script:TweaksGrid.RowHeadersVisible=$false;$script:TweaksGrid.AllowUserToAddRows=$false;$script:TweaksGrid.ReadOnly=$true;$script:TweaksGrid.SelectionMode='FullRowSelect';$script:TweaksGrid.AutoSizeColumnsMode='Fill';$script:TweaksGrid.EnableHeadersVisualStyles=$false;$script:TweaksGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:TweaksGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:TweaksGrid.DefaultCellStyle.BackColor=$C.Surface;$script:TweaksGrid.DefaultCellStyle.ForeColor=$C.Text;[void]$script:TweaksGrid.Columns.Add('Name','Ajuste');[void]$script:TweaksGrid.Columns.Add('Desc','Para que serve');[void]$script:TweaksGrid.Columns.Add('State','Estado')
    $script:TweaksRefresh={ $script:TweaksGrid.Rows.Clear();foreach($tw in $script:Tweaks){$st=Get-TweakEnabled $tw;$txt=if($null -eq $st){'Nao configurado'}elseif($st){'ATIVO'}else{'INATIVO'};$i=$script:TweaksGrid.Rows.Add($tw.Name,$tw.Desc,$txt);$script:TweaksGrid.Rows[$i].Tag=$tw}}
    &$script:TweaksRefresh;Add-FlowControl $f $script:TweaksGrid 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true
    $row.Controls.Add((New-Button 'ATIVAR' ({if($script:TweaksGrid.SelectedRows.Count){Set-Tweak $script:TweaksGrid.SelectedRows[0].Tag $true;&$script:TweaksRefresh}}) -Primary));$row.Controls.Add((New-Button 'DESATIVAR' ({if($script:TweaksGrid.SelectedRows.Count){Set-Tweak $script:TweaksGrid.SelectedRows[0].Tag $false;&$script:TweaksRefresh}})));$row.Controls.Add((New-Button 'RESTAURAR desta sessao' ({if($script:TweaksGrid.SelectedRows.Count){$tw=$script:TweaksGrid.SelectedRows[0].Tag;Restore-Reg $tw.Path $tw.Value;&$script:TweaksRefresh}})))
    Add-FlowControl $f $row 1100
}

Add-Page 'max' 'BOOST  CPU / GPU Max' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'CPU / GPU · desempenho maximo controlado' 17 $C.Text -Bold) 1100
    Add-FlowControl $f (New-Label 'Nao faz overclock de tensao. Usa plano de energia, boost, core parking e preferencias graficas do Windows.' 9 $C.Muted) 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'CPU JOGO' ({Apply-CPU-Max $false}) -Primary));$row.Controls.Add((New-Button 'CPU EXTREMO' ({Apply-CPU-Max $true})));$row.Controls.Add((New-Button 'HAGS ON' ({Set-HAGS $true})));$row.Controls.Add((New-Button 'HAGS OFF' ({Set-HAGS $false})));$row.Controls.Add((New-Button 'GPU alto desempenho por jogo' ({Set-AppHighGpu}) -Primary));Add-FlowControl $f $row 1100
    Add-FlowControl $f (New-Label 'CPU EXTREMO mantem minimo em 100% na tomada e pode aumentar muito temperatura/consumo. Compare FPS e frametime.' 9 $C.Yellow) 1100
}

Add-Page 'drivers' '↻  Drivers' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Drivers instalados e atualizacoes disponiveis' 17 $C.Text -Bold) 1100
    $script:DriversGrid=New-Object Windows.Forms.DataGridView;$script:DriversGrid.Width=1100;$script:DriversGrid.Height=450;$script:DriversGrid.BackgroundColor=$C.Surface;$script:DriversGrid.ForeColor=$C.Text;$script:DriversGrid.RowHeadersVisible=$false;$script:DriversGrid.AllowUserToAddRows=$false;$script:DriversGrid.ReadOnly=$true;$script:DriversGrid.AutoSizeColumnsMode='Fill';$script:DriversGrid.EnableHeadersVisualStyles=$false;$script:DriversGrid.ColumnHeadersDefaultCellStyle.BackColor=$C.Surface2;$script:DriversGrid.ColumnHeadersDefaultCellStyle.ForeColor=$C.Muted;$script:DriversGrid.DefaultCellStyle.BackColor=$C.Surface;$script:DriversGrid.DefaultCellStyle.ForeColor=$C.Text;[void]$script:DriversGrid.Columns.Add('Name','Dispositivo');[void]$script:DriversGrid.Columns.Add('Provider','Fornecedor');[void]$script:DriversGrid.Columns.Add('Version','Versao');[void]$script:DriversGrid.Columns.Add('Date','Data');[void]$script:DriversGrid.Columns.Add('Inf','INF')
    $script:DriversLoad={ $script:DriversGrid.Rows.Clear();Get-CimInstance Win32_PnPSignedDriver|Where-Object{$_.DeviceName}|Sort-Object DeviceName|ForEach-Object{[void]$script:DriversGrid.Rows.Add($_.DeviceName,$_.DriverProviderName,$_.DriverVersion,$_.DriverDate,$_.InfName)}};&$script:DriversLoad;Add-FlowControl $f $script:DriversGrid 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'Atualizar lista' $script:DriversLoad));
    $row.Controls.Add((New-Button 'Buscar drivers no Windows Update' ({
        try{$sess=New-Object -ComObject Microsoft.Update.Session;$search=$sess.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Driver'");$names=@();for($i=0;$i -lt $search.Updates.Count;$i++){$names+=$search.Updates.Item($i).Title};Show-Info($(if($names.Count){"Drivers encontrados:`r`n`r`n"+($names -join "`r`n")}else{'Nenhum driver pendente encontrado pelo Windows Update.'}))}catch{Show-Warn 'Nao foi possivel consultar drivers pelo Windows Update.'}
    }) -Primary));
    $row.Controls.Add((New-Button 'Abrir AMD' ({Start-Process 'https://www.amd.com/en/support/download/drivers.html'})));$row.Controls.Add((New-Button 'Abrir NVIDIA' ({Start-Process 'https://www.nvidia.com/Download/index.aspx'})));$row.Controls.Add((New-Button 'Abrir Intel' ({Start-Process 'https://www.intel.com/content/www/us/en/support/detect.html'})));$row.Controls.Add((New-Button 'Abrir MSI' ({Start-Process 'https://www.msi.com/support'})));Add-FlowControl $f $row 1100
}

Add-Page 'disk' 'DISK  Disco / Armazenamento' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Armazenamento e desempenho do disco' 17 $C.Text -Bold) 1100
    $script:DiskBox=New-Object Windows.Forms.TextBox;$script:DiskBox.Multiline=$true;$script:DiskBox.ReadOnly=$true;$script:DiskBox.BackColor=$C.Surface;$script:DiskBox.ForeColor=$C.Text;$script:DiskBox.Font=New-Object Drawing.Font('Consolas',10);$script:DiskBox.Height=330
    $script:DiskRead={ $sb=New-Object Text.StringBuilder;foreach($d in Get-CimInstance Win32_DiskDrive){[void]$sb.AppendLine("$($d.Model) · $(Format-Bytes $d.Size) · $($d.MediaType) · $($d.InterfaceType)")};[void]$sb.AppendLine('');try{[void]$sb.AppendLine((fsutil behavior query DisableDeleteNotify|Out-String).Trim())}catch{};$script:DiskBox.Text=$sb.ToString()};&$script:DiskRead;Add-FlowControl $f $script:DiskBox 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.WrapContents=$true
    $row.Controls.Add((New-Button 'Atualizar' $script:DiskRead));$row.Controls.Add((New-Button 'ReTRIM C:' ({if(Need-Admin){Optimize-Volume -DriveLetter C -ReTrim -Verbose|Out-String|ForEach-Object{Show-Info $_}}}) -Primary));$row.Controls.Add((New-Button 'Otimizar C: /O' ({if(Need-Admin){Start-Process defrag.exe -ArgumentList 'C: /O /U /V' -Verb RunAs}})));$row.Controls.Add((New-Button 'CHKDSK /scan' ({if(Need-Admin){Start-Process chkdsk.exe -ArgumentList 'C: /scan' -Verb RunAs}})));Add-FlowControl $f $row 1100
}

Add-Page 'net' 'NET  Rede / Som' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Rede e audio' 17 $C.Text -Bold) 1100
    $script:NetBox=New-Object Windows.Forms.TextBox;$script:NetBox.Multiline=$true;$script:NetBox.ReadOnly=$true;$script:NetBox.BackColor=$C.Surface;$script:NetBox.ForeColor=$C.Text;$script:NetBox.Font=New-Object Drawing.Font('Consolas',10);$script:NetBox.Height=420
    $script:NetRead={ $sb=New-Object Text.StringBuilder;[void]$sb.AppendLine('REDE:');Get-CimInstance Win32_NetworkAdapter|Where-Object{$_.NetEnabled}|ForEach-Object{[void]$sb.AppendLine("$($_.Name) · $($_.Speed) bps · MAC $($_.MACAddress)")};[void]$sb.AppendLine('');[void]$sb.AppendLine('AUDIO:');Get-CimInstance Win32_SoundDevice|ForEach-Object{[void]$sb.AppendLine("$($_.Name) · $($_.Status)")};$script:NetBox.Text=$sb.ToString()};&$script:NetRead;Add-FlowControl $f $script:NetBox 1100
    $row=New-Object Windows.Forms.FlowLayoutPanel;$row.AutoSize=$true;$row.Controls.Add((New-Button 'Abrir Rede' ({Start-Process 'ms-settings:network-status'}) -Primary));$row.Controls.Add((New-Button 'Abrir Som' ({Start-Process 'ms-settings:sound'})));$row.Controls.Add((New-Button 'Testar ping' ({Start-Process powershell.exe -ArgumentList '-NoExit','-Command','ping 1.1.1.1 -t'})));Add-FlowControl $f $row 1100
}

Add-Page 'oosu' 'O&O  Recomendado' {
    param($p);$f=New-Flow;$p.Controls.Add($f);Add-FlowControl $f (New-Label 'Privacidade / O&O-style recomendado' 17 $C.Text -Bold) 1100;Add-FlowControl $f (New-Label 'Apenas ajustes conservadores equivalentes aos controles recomendados que voce selecionou anteriormente.' 9 $C.Muted) 1100
    $items=$script:Tweaks|Where-Object{$_.Id -in @('telemetry','consumer','delivery','widgets','copilot','notifications','gamedvr')}
    foreach($tw in $items){$card=New-Card $tw.Name $tw.Desc;$card.Width=1060;$card.Height=82;$on=New-Button 'ATIVAR' ({param($s,$e);Set-Tweak $s.Tag $true}) -Primary;$off=New-Button 'DESATIVAR' ({param($s,$e);Set-Tweak $s.Tag $false});$on.Tag=$tw;$off.Tag=$tw;$on.Location=New-Object Drawing.Point(800,20);$off.Location=New-Object Drawing.Point(910,20);$card.Controls.AddRange(@($on,$off));Add-FlowControl $f $card 1080}
}

# Primeira pagina
$pages['dash'].Visible=$true;$pages['dash'].BringToFront();$navButtons['dash'].BackColor=$C.Cyan;$navButtons['dash'].ForeColor=$C.Bg

# Timer realtime
$script:MainTimer=New-Object Windows.Forms.Timer;$script:MainTimer.Interval=750;$tick=0
$script:MainTimer.Add_Tick({
    $tick++
    $m=Get-Metrics
    if($cpuV){$cpuV.Text=('{0:N0}%' -f $m.CPU)};if($ramV){$ramV.Text=('{0:N0}%' -f $m.RAM)};if($diskV){$diskV.Text=('{0:N0}%' -f $m.Disk)};if($gpuV){$gpuV.Text=$(if($null -eq $m.GPU){'N/D'}else{('{0:N0}%' -f $m.GPU)})};if($netV){$netV.Text=((Format-Bytes $m.NetDown)+'/s')};if($tempV){$tempV.Text=$(if($null -eq $m.Temp){'N/D'}else{"$($m.Temp) °C"})}
    if($procGrid -and ($tick % 2 -eq 0)){$procGrid.Rows.Clear();foreach($r in Get-TopProcesses){[void]$procGrid.Rows.Add($r.Name,$r.PercentProcessorTime,(Format-Bytes $r.WorkingSetPrivate),(Format-Bytes $r.IOReadBytesPersec),(Format-Bytes $r.IOWriteBytesPersec))}}
})
$script:MainTimer.Start();$form.Add_FormClosed({$script:MainTimer.Stop();$script:MainTimer.Dispose()})
[void]$form.ShowDialog()