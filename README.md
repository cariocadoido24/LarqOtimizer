# LarqOtimizer

Central nativa de otimização e diagnóstico para Windows.

Este repositório é privado. A instalação usa o GitHub CLI para autenticar a conta no próprio fluxo do PowerShell e baixar o pacote privado.

## PC novo

Cole o comando de bootstrap fornecido pelo projeto no PowerShell. Na primeira vez, se necessário, ele instala o GitHub CLI e inicia `gh auth login` automaticamente. Depois da autorização, a instalação continua sozinha.

Depois da instalação:

```powershell
larq
```

Para atualizar:

```powershell
larq update
```

A autenticação do LarqOtimizer fica em `%LOCALAPPDATA%\LarqOtimizer\Auth` e não é apagada durante atualizações. A senha não fica armazenada em texto puro no repositório.
