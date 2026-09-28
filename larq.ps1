# LarqOtimizer - bootstrap para repositorio GitHub PRIVADO
# Este script e executado depois que o GitHub CLI autenticou o usuario.
[CmdletBinding()]
param([switch]$Update)

$ErrorActionPreference = 'Stop'
$Repo = 'cariocadoido24/LarqOtimizer'
$ZipPathInRepo = 'LarqOtimizer-latest.zip'

function Ensure-GitHubCli {
    if (Get-Command gh -ErrorAction SilentlyContinue) { return }
    Write-Host 'GitHub CLI nao encontrado. Instalando...' -ForegroundColor Yellow
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'O GitHub CLI nao esta instalado e o winget nao foi encontrado. Instale o GitHub CLI e execute novamente.'
    }
    winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
    $possible = @(
        "$env:ProgramFiles\GitHub CLI\gh.exe",
        "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($possible) { Set-Alias gh $possible -Scope Script }
    elseif (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI foi instalado, mas ainda nao esta disponivel. Feche e abra o PowerShell e rode o comando novamente.' }
}

function Ensure-GitHubAuth {
    Ensure-GitHubCli
    & gh auth status -h github.com *> $null
    if ($LASTEXITCODE -eq 0) { return }
    Write-Host ''
    Write-Host 'LOGIN DO GITHUB NECESSARIO' -ForegroundColor Cyan
    Write-Host 'O LarqOtimizer esta em um repositorio privado.' -ForegroundColor DarkGray
    Write-Host 'O login sera iniciado agora pelo GitHub CLI. Autorize sua conta quando solicitado.' -ForegroundColor DarkGray
    Write-Host ''
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'Login do GitHub nao concluido.' }
}

Ensure-GitHubAuth

$tempRoot = Join-Path $env:TEMP ('LarqOtimizer-private-' + [Guid]::NewGuid().ToString('N'))
$zip = $tempRoot + '.zip'
try {
    Write-Host 'Baixando LarqOtimizer do repositorio privado...' -ForegroundColor Cyan
    & gh api -H 'Accept: application/vnd.github.raw+json' "repos/$Repo/contents/$ZipPathInRepo" > $zip
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $zip) -or ((Get-Item $zip).Length -lt 1024)) {
        throw 'Nao foi possivel baixar o pacote privado do GitHub.'
    }
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $tempRoot -Force
    $installer = Get-ChildItem -Path $tempRoot -Filter 'INSTALAR.ps1' -Recurse | Select-Object -First 1
    if (-not $installer) { throw 'Pacote invalido: INSTALAR.ps1 nao encontrado.' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$installer.FullName)
    if ($Update) { $args += '-NoLaunch' }
    & powershell.exe @args
    if ($LASTEXITCODE -ne 0) { throw 'O instalador do LarqOtimizer retornou erro.' }
} finally {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}