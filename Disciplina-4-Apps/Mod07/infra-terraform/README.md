# Mod07 – Infra do Lab de Observabilidade (Terraform)

Versão **Terraform** (provider `azurerm`) da mesma infra do `../infra` (Bicep). Provisiona, **self-contained**, toda a infra do lab:

```
APIM → Function Producer → Service Bus → Function Consumer → Blob + Cosmos
                         (tudo correlacionado em 1 Application Insights)
```

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `providers.tf` | versões + backend `azurerm` (state remoto, config parcial) |
| `variables.tf` | variáveis de entrada |
| `main.tf` | todos os recursos + RBAC |
| `outputs.tf` | nomes gerados + endpoint de teste |
| `terraform.tfvars` | valores padrão do lab |
| `azure-pipelines.yml` | pipeline DevOps (init → plan → apply) |

## O que é criado

Mesmo conjunto do Bicep: Log Analytics + App Insights (workspace-based), Service Bus Standard + fila `mod07-msgjourney`, Storage + container `messages`, Cosmos serverless (`mod07`/`pedidos`, PK `/correlationId`, em `eastus2`), App Service Plan Y1 Linux + 2 Function Apps .NET 8 isolated (System MI), APIM (`Consumption_0`) com API `mod07-producer` + operação `send` + policy + subscription `mod07-sub`. O **resource group** também é criado pelo Terraform.

### RBAC (data plane via Managed Identity)
- Producer MI → **Azure Service Bus Data Sender** (namespace)
- Consumer MI → **Azure Service Bus Data Receiver** (namespace)
- Consumer MI → **Storage Blob Data Contributor** (storage)
- Consumer MI → **Cosmos DB Built-in Data Contributor** (data plane)

> Diferença vs Bicep: o Terraform gerencia `WEBSITE_CONTENTSHARE` / `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` automaticamente (a partir de `storage_account_name`/`storage_account_access_key`), então esses settings não aparecem no `app_settings`.

## Deploy via Azure DevOps

1. Crie uma **Service Connection** ARM (ex.: `sc-azure-aiexpert`).
2. Em `azure-pipelines.yml`, ajuste `azureServiceConnection` e o bloco de **backend** (`backendStorageAccount` precisa ser globalmente único).
3. Crie um **Environment** `mod07-lab` e configure **aprovação manual** nele (gate do `apply`).
4. Crie o pipeline apontando para `POSGraducao/Mod07/terraform/azure-pipelines.yml`.

O pipeline tem 2 stages: **Plan** (cria o storage de state se preciso, `init`/`validate`/`plan`, publica o `tfplan` como artefato) e **Apply** (`apply tfplan` após aprovação). Suporta Service Connection com **secret** ou **Workload Identity Federation (OIDC)** — detecta automaticamente. `terraform` já vem nos agents `ubuntu-latest`.

## Deploy manual (alternativa)

```powershell
# state local (sem backend remoto)
terraform init -backend=false
terraform plan
terraform apply
```

Ou com backend remoto:

```powershell
terraform init `
  -backend-config="resource_group_name=rg-tfstate" `
  -backend-config="storage_account_name=sttfstatemod07" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=mod07-lab.tfstate"
terraform apply
```

## Depois do deploy: publicar o código das Functions

A infra não inclui o código. Os nomes saem em `terraform output`:

```powershell
func azure functionapp publish $(terraform output -raw producer_function_app) --dotnet-isolated
func azure functionapp publish $(terraform output -raw consumer_function_app) --dotnet-isolated
```

## Testar a jornada

```powershell
terraform output -raw test_endpoint        # https://apim-mod07-<sufixo>.azure-api.net/mod07/send
$key = az apim subscription show -g rg-mod07-lab --service-name $(terraform output -raw apim_name) --sid mod07-sub --query primaryKey -o tsv

curl -X POST "$(terraform output -raw test_endpoint)" `
  -H "Ocp-Apim-Subscription-Key: $key" `
  -H "Content-Type: application/json" `
  -d '@../payloads/pedido-01.json'
```

Depois, no Application Insights, siga a jornada por `correlationId` (= `orderId`) com as queries em `../kql/`.

## Notas / pegadinhas

- **Chave da Function no APIM:** o named value `func-mod07-producer-key` usa o data source `azurerm_function_app_host_keys.producer.default_function_key`. A host key `default` já existe na criação do app; se o primeiro teste der **401**, rode `terraform apply` de novo após o primeiro `func publish` (a key é re-materializada) ou atualize o named value.
- **Cosmos serverless** via capability `EnableServerless` (sem RU/s provisionado).
- **APIM `Consumption_0`** sobe em minutos; para recursos completos use `Developer_1`/`Standard_1` (deploy ~45min).
- **Backend de state:** o pipeline cria `rg-tfstate`/storage/container automaticamente. Ajuste os nomes antes de rodar.
- Equivalência de SKU APIM: Bicep `Consumption` ↔ Terraform `Consumption_0`.
