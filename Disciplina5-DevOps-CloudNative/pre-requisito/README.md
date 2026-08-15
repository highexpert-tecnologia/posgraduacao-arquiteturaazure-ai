# Preparação do ambiente

Esta pasta contém o script que prepara uma estação Windows para desenvolver, testar e provisionar este projeto.

## Requisitos

- Windows 10 ou 11
- [WinGet](https://learn.microsoft.com/windows/package-manager/winget/)
- Conexão com a internet
- Uma conta GitHub
- Uma conta Azure com acesso à assinatura utilizada no projeto
- Terminal executado como administrador caso a instalação de algum componente solicite elevação

## O que o script configura

O [`terraform-pos-env.ps1`](terraform-pos-env.ps1) instala ou atualiza:

- Git, GitHub CLI e Visual Studio Code
- .NET SDK 10 e ferramentas globais do .NET
- PowerShell Core e Oh My Posh
- Terraform e Azure CLI
- extensões `gh-aw` e GitHub Models para o GitHub CLI
- módulo `Terminal-Icons` e fonte Meslo

O script também:

- solicita nome e e-mail para configurar o Git globalmente
- define `main` como branch inicial padrão do Git
- cria ou substitui o perfil do PowerShell com Oh My Posh e Terminal Icons
- oferece a instalação opcional do WSL2 com Ubuntu
- inicia a autenticação interativa no GitHub e no Azure

> [!IMPORTANT]
> Revise o script antes de executá-lo. Ele modifica configurações globais do usuário e substitui o conteúdo atual de `$PROFILE` no PowerShell.


## Execução

Passo 1: verifique se possui o cURL instalado no Windows. Caso não tenha, instale-o com o WinGet:

```powershell
winget install cURL --id cURL.cURL --source winget
```

Passo 2: vamos instalar o PowerShell Core, caso ele não esteja presente. Abra o PowerShell como administrador e execute:

```powershell
$scriptPath = Join-Path $env:TEMP "PowerShell-7.6.4-win-x64.msi"; curl.exe -L -o $scriptPath "https://github.com/PowerShell/PowerShell/releases/download/v7.6.4/PowerShell-7.6.4-win-x64.msi"; if ($LASTEXITCODE -eq 0) { Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$scriptPath`" /qn" -Wait }
```

Passo 3: Abra o PowerShell Core e execute o seguinte comando para baixar e executar o script de preparação do ambiente:

```powershell
winget search Git.Git; $scriptPath = Join-Path $env:TEMP "terraform-pos-env.ps1"; curl.exe -L -o $scriptPath "https://raw.githubusercontent.com/highexpert-tecnologia/posgraduacao-arquiteturaazure-ai/refs/heads/main/pre-requisito/terraform-pos-env.ps1"; if ($LASTEXITCODE -eq 0) { pwsh -ExecutionPolicy Bypass -File $scriptPath }
```

## Validação

Abra um novo terminal após a instalação e confirme as principais ferramentas:

```powershell
git --version
gh --version
gh aw --version
dotnet --list-sdks
pwsh --version
terraform version
az version
```

Confirme também as autenticações:

```powershell
gh auth status
az account show --output table
```

## Personalização do terminal

O tema padrão configurado pelo script é o `clean-detailed`. Outros temas estão disponíveis na [documentação do Oh My Posh](https://ohmyposh.dev/docs/themes).

## Próximo passo

Com o ambiente validado, retorne ao [README principal](../README.md#Verficações) para configurar as credenciais e executar o Terraform.
