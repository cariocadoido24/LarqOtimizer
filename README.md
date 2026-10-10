# LarqOtimizer — Performance Center

Aplicativo Windows com interface **WinForms nativa**, executado em memória pelo PowerShell.

## Abrir (sem instalação, sem login do GitHub)

Abra o Windows PowerShell **como administrador** se quiser aplicar ajustes do sistema:

```powershell
irm "https://raw.githubusercontent.com/cariocadoido24/LarqOtimizer/main/larq.ps1" | iex
```

O script é transferido pela internet para a memória em toda abertura, mas não instala um executável nem mantém pasta do aplicativo. Alguns ajustes escolhidos no aplicativo modificam o Windows e **persistem após fechar**.

## Destaques

- Dashboard moderno com CPU, RAM, disco, GPU 3D, rede, sensor ACPI (quando disponível), gráfico e processos
- Abas carregadas sob demanda, para iniciar mais rápido
- Monitoramento menos frequente para evitar excesso de consultas WMI
- Perfil de Windows para jogos, configuração de Fortnite com backup e restauração
- Ajustes do registro com checagem de leitura após gravação
- Gerenciamento de energia e ajustes básicos de rede com relatório de erro
- Hardware, BIOS detectável, dispositivos USB, drivers, disco e limpeza

Nem todos os sensores estão disponíveis no Windows. O aplicativo mostra N/D quando não pode obter leitura confiável. Não há garantia de ganho de FPS ou redução de ping: isso depende do hardware, do jogo e da rede.

## Testes

A validação do código para Windows PowerShell 5.1 roda em [GitHub Actions](https://github.com/cariocadoido24/LarqOtimizer/actions). Ela verifica sintaxe, a função de senha com **senha fictícia de teste**, edição de INI e gravação em chave temporária do registro do runner. O teste **não substitui** a execução e inspeção visual no seu Windows.

A senha e o nome de usuário são definidos no próprio script. Por estar em repositório público, o login do aplicativo **não deve ser considerado uma proteção forte contra engenharia reversa**.
