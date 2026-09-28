# LarqOtimizer

Central nativa de otimização e diagnóstico para Windows.

O repositório é **privado**. A primeira instalação é iniciada inteiramente pelo PowerShell. Se o PC ainda não tiver o GitHub CLI, o comando instala o `gh`; se ainda não houver login, o próprio fluxo inicia a autorização do GitHub. Depois disso, o pacote privado é baixado e instalado.

## PC novo — cole no PowerShell

```powershell
$g=(Get-Command gh -EA SilentlyContinue).Source;if(!$g){winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements;$g="$env:ProgramFiles\GitHub CLI\gh.exe";if(!(Test-Path $g)){$g="$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"}};& $g auth status -h github.com *> $null;if($LASTEXITCODE -ne 0){& $g auth login -h github.com -p https --web};$c=& $g api -H "Accept: application/vnd.github.raw+json" repos/cariocadoido24/LarqOtimizer/contents/larq.ps1;& ([scriptblock]::Create(($c -join "`n")))
```

A autorização segura do GitHub pode abrir a página oficial de login/autorização uma vez. Ela é iniciada pelo PowerShell; não é necessário navegar manualmente até o repositório.

## Depois de instalado

Abrir:

```powershell
larq
```

Atualizar:

```powershell
larq update
```

A configuração de autenticação do LarqOtimizer fica em `%LOCALAPPDATA%\LarqOtimizer\Auth` e não é apagada nas atualizações. A credencial do aplicativo não é armazenada em texto puro no GitHub.
