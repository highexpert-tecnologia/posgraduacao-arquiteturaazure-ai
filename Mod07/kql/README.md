# Queries KQL — Observabilidade da jornada da mensagem (Mod07)

Estas queries foram pensadas para serem executadas no **Application Insights
`appi-mod07-aiexpert`** → blade **Logs**. Elas usam o schema clássico do
Application Insights (`requests`, `dependencies`, `customEvents`, `traces`,
`exceptions`).

> Se preferir rodar diretamente no **Log Analytics workspace
> `log-mod07-aiexpert`**, troque os nomes das tabelas pelo equivalente
> workspace-based:
>
> | App Insights (clássico) | Log Analytics (workspace) |
> |-------------------------|---------------------------|
> | `requests`              | `AppRequests`             |
> | `dependencies`          | `AppDependencies`         |
> | `customEvents`          | `AppEvents`               |
> | `traces`                | `AppTraces`               |
> | `exceptions`            | `AppExceptions`           |
>
> Nas tabelas `App*`, `cloud_RoleName` vira `AppRoleName`, `operation_Id` vira
> `OperationId` e `customDimensions` vira `Properties`.

## Arquitetura observada

```
Cliente → APIM (apim-ai-expert) → Function Producer → Service Bus (fila mod07-msgjourney)
        → Function Consumer ─┬→ Storage Blob (stamod03lab03dev001 / container messages)
                             └→ Cosmos DB SQL serverless (cosmos-mod07-aiexpert / mod07 / pedidos)
```

O payload é um **pedido de compra** (itens: caneta, papel, teclado, mouse, caneca).
Todos os componentes enviam telemetria para o **mesmo** Application Insights, então:

- **Trace distribuído (W3C `traceparent`)**: propaga automaticamente do Producer,
  pela mensagem do Service Bus, até o Consumer — conectando tudo no mesmo
  `operation_Id` (veja a query 02).
- **Correlação técnica (`messageId`)**: ID único de cada mensagem, emitido nos
  eventos custom (`MessageSent`, `MessageReceived`, `BlobWritten`, `CosmosDocWritten`),
  permitindo seguir a mensagem mesmo em consultas simples (query 01).
- **Correlação de negócio (`correlationId` = `orderId`)**: amarra o pedido inteiro
  (e todas as suas mensagens) em todos os estágios — vai no campo nativo
  `CorrelationId` do Service Bus e nos eventos custom (query 09).

## Índice

| Arquivo | Para quê serve |
|---------|----------------|
| `01-jornada-por-messageId.kql`         | Linha do tempo de UMA mensagem (correlação por `messageId`). |
| `02-transacao-distribuida.kql`         | Trace distribuído completo por `operation_Id` (inclui APIM e dependências). |
| `03-latencia-produtor-consumidor.kql`  | Tempo entre envio e recebimento (fila + processamento). |
| `04-falhas-e-exceptions.kql`           | Exceptions e requests falhos para diagnóstico. |
| `05-volume-e-throughput.kql`           | Throughput por estágio ao longo do tempo (timechart). |
| `06-dependencias-servicebus-storage.kql` | Latência/erros das chamadas a Service Bus e Storage. |
| `07-saude-das-functions.kql`           | Volume, p50/p95 e taxa de falha por Function. |
| `08-funil-da-jornada.kql`              | Quantas mensagens chegam em cada estágio (detecta perdas). |
| `09-jornada-por-pedido.kql`            | Linha do tempo de UM pedido inteiro (correlação por `correlationId`/`orderId`). |

## Como gerar tráfego de teste

```bash
# Via APIM (precisa da subscription key 'Mod07 Lab Subscription')
# Pedidos prontos estao em ../payloads
curl -X POST "https://apim-ai-expert.azure-api.net/mod07/send" \
  -H "Ocp-Apim-Subscription-Key: <SUA_SUBSCRIPTION_KEY>" \
  -H "Content-Type: application/json" \
  --data-binary @../payloads/pedido-004-kit-completo.json
```

A resposta traz `messageId` (técnico) e `correlationId`/`orderId` (negócio):
cole o `messageId` nas queries 01 e 02; o `correlationId` na query 09.

> A ingestão do Application Insights tem latência típica de 1–3 minutos.
