# LarqOtimizer - bootstrap privado GitHub
[CmdletBinding()]
param([switch]$Update)

$ErrorActionPreference = 'Stop'
$Repo = 'cariocadoido24/LarqOtimizer'
$PartCount = 10

function Resolve-Gh {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    Write-Host 'GitHub CLI nao encontrado. Instalando pelo winget...' -ForegroundColor Yellow
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget nao foi encontrado neste Windows.'
    }

    winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar GitHub CLI.' }

    $candidates = @(
        "$env:ProgramFiles\GitHub CLI\gh.exe",
        "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'GitHub CLI foi instalado, mas gh.exe nao foi localizado.'
}

function Ensure-GhAuth([string]$Gh) {
    & $Gh auth status -h github.com *> $null
    if ($LASTEXITCODE -eq 0) { return }

    Write-Host ''
    Write-Host 'Login do GitHub necessario para acessar o LarqOtimizer privado.' -ForegroundColor Cyan
    Write-Host 'A autorizacao sera iniciada pelo PowerShell/GitHub CLI.' -ForegroundColor DarkGray
    & $Gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'Login do GitHub nao concluido.' }

    & $Gh auth status -h github.com *> $null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI ainda nao esta autenticado.' }
}

function Read-PrivateRaw([string]$Gh, [string]$Path) {
    $result = & $Gh api -H 'Accept: application/vnd.github.raw+json' "repos/$Repo/contents/$Path"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao baixar $Path do GitHub." }
    return ($result -join [Environment]::NewLine).Trim()
}

$gh = Resolve-Gh
Ensure-GhAuth $gh

$tempRoot = Join-Path $env:TEMP ('LarqOtimizer-private-' + [Guid]::NewGuid().ToString('N'))
$zip = $tempRoot + '.zip'

try {
    Write-Host 'Baixando LarqOtimizer do repositorio privado...' -ForegroundColor Cyan
    $builder = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $PartCount; $i++) {
        $name = 'payload/part{0:D2}.b64' -f $i
        [void]$builder.Append((Read-PrivateRaw $gh $name))
        Write-Progress -Activity 'LarqOtimizer' -Status ('Baixando pacote {0}/{1}' -f ($i + 1), $PartCount) -PercentComplete ((($i + 1) / $PartCount) * 100)
    }
    Write-Progress -Activity 'LarqOtimizer' -Completed

    $bytes = [Convert]::FromBase64String($builder.ToString())
    [IO.File]::WriteAllBytes($zip, $bytes)

    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $tempRoot -Force
    $installer = Get-ChildItem -Path $tempRoot -Filter 'INSTALAR.ps1' -Recurse | Select-Object -First 1
    if (-not $installer) { throw 'Pacote invalido: INSTALAR.ps1 nao encontrado.' }

    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$installer.FullName)
    if ($Update) { $args += '-NoLaunch' }
    & powershell.exe @args
    if ($LASTEXITCODE -ne 0) { throw 'O instalador do LarqOtimizer retornou erro.' }

    # Substitui o atualizador instalado por um wrapper que volta ao bootstrap privado.
    $app = Join-Path $env:LOCALAPPDATA 'LarqOtimizer\App'
    $updaterPath = Join-Path $app 'ATUALIZAR.ps1'
    if (Test-Path $app) {
        $updater = @"
`$ErrorActionPreference = 'Stop'
`$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not `$gh) {
    `$c = @("`$env:ProgramFiles\GitHub CLI\gh.exe", "`$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe") | Where-Object { Test-Path `$_ } | Select-Object -First 1
    if (-not `$c) { throw 'GitHub CLI nao encontrado. Rode novamente o comando de instalacao do LarqOtimizer.' }
    `$gh = `$c
}
& `$gh auth status -h github.com *> `$null
if (`$LASTEXITCODE -ne 0) {
    & `$gh auth login --hostname github.com --git-protocol https --web
    if (`$LASTEXITCODE -ne 0) { throw 'Login do GitHub nao concluido.' }
}
`$code = & `$gh api -H 'Accept: application/vnd.github.raw+json' 'repos/cariocadoido24/LarqOtimizer/contents/larq.ps1'
if (`$LASTEXITCODE -ne 0) { throw 'Falha ao baixar o atualizador privado.' }
& ([scriptblock]::Create((`$code -join [Environment]::NewLine))) -Update
"@
        Set-Content -LiteralPath $updaterPath -Value $updater -Encoding UTF8
    }

    if ($Update) {
        Write-Host 'LarqOtimizer atualizado.' -ForegroundColor Green
    } else {
        Write-Host ''
        Write-Host 'LarqOtimizer instalado. Depois, use apenas: larq' -ForegroundColor Green
        Write-Host 'Para atualizar: larq update' -ForegroundColor Cyan
    }
}
finally {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
