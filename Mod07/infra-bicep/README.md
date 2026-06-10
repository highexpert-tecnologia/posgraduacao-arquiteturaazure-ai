# Mod07 – Infra do Lab de Observabilidade (Bicep)

Provisiona, **self-contained** (tudo do zero), a infra do lab de observabilidade:

```
APIM → Function Producer → Service Bus → Function Consumer → Blob + Cosmos
                         (tudo correlacionado em 1 Application Insights)
```

## O que é criado

| Recurso | Nome (gerado) | Observação |
|---|---|---|
| Log Analytics | `log-mod07-<sufixo>` | retenção 30 dias |
| Application Insights | `appi-mod07-<sufixo>` | workspace-based |
| Service Bus (Standard) + fila | `sb-mod07-<sufixo>` / `mod07-msgjourney` | dead-letter on expiration |
| Storage + container | `stmod07<sufixo>` / `messages` | também é o AzureWebJobsStorage |
| Cosmos DB SQL serverless | `cosmos-mod07-<sufixo>` | db `mod07`, container `pedidos` (PK `/correlationId`), região **eastus2** |
| App Service Plan (Y1 Linux) | `plan-mod07-<sufixo>` | Consumption |
| Function App Producer | `func-mod07-producer-<sufixo>` | .NET 8 isolated, System MI |
| Function App Consumer | `func-mod07-consumer-<sufixo>` | .NET 8 isolated, System MI |
| APIM | `apim-mod07-<sufixo>` | SKU **Consumption** (default), API `mod07-producer`, sub `mod07-sub` |

`<sufixo>` = `take(uniqueString(resourceGroup().id), 6)` — determinístico por RG.

### RBAC (data plane via Managed Identity, sem connection string p/ dados)
- Producer MI → **Azure Service Bus Data Sender** (namespace)
- Consumer MI → **Azure Service Bus Data Receiver** (namespace)
- Consumer MI → **Storage Blob Data Contributor** (storage)
- Consumer MI → **Cosmos DB Built-in Data Contributor** (data plane / SQL role assignment)

## Deploy via Azure DevOps

1. Crie uma **Service Connection** ARM no projeto (ex.: `sc-azure-aiexpert`).
2. Ajuste em `azure-pipelines.yml` as variáveis `azureServiceConnection`, `resourceGroupName` e `location`.
3. Crie um **Environment** chamado `mod07-lab` (Pipelines → Environments) ou troque o nome no YAML.
4. Crie o pipeline apontando para `POSGraducao/Mod07/infra/azure-pipelines.yml`.

O pipeline tem 2 stages: **Validate** (`az group create` + `validate` + `what-if`) e **Deploy** (`az deployment group create`). Faz **apenas a infra** — o código das Functions é publicado à parte.

## Deploy manual (alternativa, sem pipeline)

```powershell
az group create -n rg-mod07-lab -l eastus
az deployment group create `
  -g rg-mod07-lab `
  -f main.bicep `
  -p main.parameters.json
```

## Depois do deploy: publicar o código das Functions

A infra não inclui o código. Publique cada app (a partir das pastas `producer/` e `consumer/`):

```powershell
# nomes saem nos outputs do deployment
func azure functionapp publish func-mod07-producer-<sufixo> --dotnet-isolated
func azure functionapp publish func-mod07-consumer-<sufixo> --dotnet-isolated
```

## Testar a jornada

```powershell
# pega a chave da subscription do APIM
$key = az apim subscription show -g rg-mod07-lab --service-name apim-mod07-<sufixo> --sid mod07-sub --query primaryKey -o tsv

# endpoint sai no output testEndpoint
curl -X POST "https://apim-mod07-<sufixo>.azure-api.net/mod07/send" `
  -H "Ocp-Apim-Subscription-Key: $key" `
  -H "Content-Type: application/json" `
  -d '@../payloads/pedido-01.json'
```

Depois, no Application Insights, siga a jornada por `correlationId` (= `orderId`) com as queries em `../kql/`.

## Parâmetros principais

| Parâmetro | Default | Para quê |
|---|---|---|
| `location` | `eastus` | região geral |
| `cosmosLocation` | `eastus2` | região do Cosmos (East US deu falta de capacidade no lab) |
| `namePrefix` | `mod07` | prefixo dos nomes (3–10, minúsculas) |
| `apimSku` | `Consumption` | use `Developer` p/ recursos completos (deploy ~45min) |
| `publisherEmail` / `publisherName` | (lab) | obrigatórios do APIM |

## Notas / pegadinhas

- **Chave da Function no APIM:** o named value `func-mod07-producer-key` é preenchido via `listKeys(... functionKeys.default)`. A host key `default` já existe na criação do app; se o primeiro teste der **401**, atualize o named value após o primeiro `func publish` (a key é re-materializada).
- **Cosmos serverless** usa a capability `EnableServerless` (sem provisionar RU/s).
- **APIM Consumption** sobe em minutos; Developer/Standard levam ~45min. Trocar é só mudar `apimSku`.
- O **AzureWebJobsStorage** do host usa connection string (key) da mesma storage — só os **dados** (Blob/Service Bus/Cosmos) usam Managed Identity.
