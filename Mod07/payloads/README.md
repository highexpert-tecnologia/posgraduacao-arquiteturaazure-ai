# Payloads de exemplo — Jornada do Pedido de Compra (Mod07)

Cada arquivo é um **pedido de compra** pronto para disparar a jornada
fim-a-fim com observabilidade e rastreabilidade (traceability).

| Arquivo | Pedido (`orderId` = `correlationId`) | Conteúdo |
|---------|--------------------------------------|----------|
| `pedido-001-canetas.json`     | `PO-2026-0001` | Canetas (azul + preta) |
| `pedido-002-papel.json`       | `PO-2026-0002` | Papel sulfite A4 + A3 |
| `pedido-003-perifericos.json` | `PO-2026-0003` | Teclado + mouse |
| `pedido-004-kit-completo.json`| `PO-2026-0004` | Kit completo: caneta, papel, teclado, mouse, caneca |
| `pedido-005-canecas.json`     | `PO-2026-0005` | Canecas (brinde onboarding RH) |
| `pedido-006-erro.json`        | `PO-ERRO-POISON-999…` | **Poison message** — quebra a jornada de propósito (ver [`ERRO-PROPOSITAL.md`](ERRO-PROPOSITAL.md)) |

## Dois eixos de correlação

A jornada carrega **dois** identificadores complementares:

- **`messageId`** — ID técnico, único por *mensagem* (um GUID por POST).
- **`correlationId`** — ID de *negócio*, igual ao `orderId` do pedido
  (ex.: `PO-2026-0004`). Amarra TODOS os componentes/eventos do mesmo pedido,
  mesmo que ele seja reenviado. No Service Bus vai no campo nativo
  `CorrelationId` **e** em `ApplicationProperties`.

> Se o payload não trouxer `orderId`, o Producer gera um
> (`PO-yyyyMMdd-xxxxxxxx`). Se não trouxer `items`, usa um pedido de exemplo.

## A jornada fim-a-fim

```
Cliente
  │  POST pedido de compra (JSON)
  ▼
APIM (apim-ai-expert)  ── injeta x-functions-key ──▶
  ▼
Function Producer  ── envia mensagem (messageId + correlationId) ──▶
  ▼
Service Bus  (fila mod07-msgjourney)
  ▼
Function Consumer  ── grava em DOIS destinos ──▶
        ├─▶ Blob Storage   (stamod03lab03dev001 / messages)  → arquivo/auditoria
        └─▶ Cosmos DB SQL  (cosmos-mod07-aiexpert / mod07 / pedidos)  → documento consultável
```

Eventos custom emitidos (todos com `messageId` + `correlationId`):
`MessageSent` → `MessageReceived` → `BlobWritten` → `CosmosDocWritten`.

## Como disparar

### Via APIM (recomendado — passa pela jornada inteira)

```powershell
$key = "<SUA_SUBSCRIPTION_KEY>"   # subscription 'Mod07 Lab Subscription'
$resp = Invoke-RestMethod `
  -Method Post `
  -Uri "https://apim-ai-expert.azure-api.net/mod07/send" `
  -Headers @{ "Ocp-Apim-Subscription-Key" = $key } `
  -ContentType "application/json" `
  -InFile ".\pedido-004-kit-completo.json"
$resp   # traz messageId, correlationId/orderId, itemCount, totalAmount
```

### Disparar todos os pedidos de uma vez

```powershell
$key = "<SUA_SUBSCRIPTION_KEY>"
Get-ChildItem .\pedido-*.json | ForEach-Object {
  $r = Invoke-RestMethod -Method Post `
    -Uri "https://apim-ai-expert.azure-api.net/mod07/send" `
    -Headers @{ "Ocp-Apim-Subscription-Key" = $key } `
    -ContentType "application/json" -InFile $_.FullName
  "{0,-14} -> msg {1} | total R$ {2}" -f $r.correlationId, $r.messageId, $r.totalAmount
  Start-Sleep -Milliseconds 400
}
```

### curl (Git Bash)

```bash
curl -X POST "https://apim-ai-expert.azure-api.net/mod07/send" \
  -H "Ocp-Apim-Subscription-Key: <SUA_SUBSCRIPTION_KEY>" \
  -H "Content-Type: application/json" \
  --data-binary @pedido-004-kit-completo.json
```

A resposta traz `correlationId` (= `orderId`) — use-o nas queries KQL
`09-jornada-por-pedido.kql` e `01-jornada-por-messageId.kql` para seguir o
pedido em cada estágio.

## Onde ver o resultado

- **Application Insights `appi-mod07-aiexpert`** → blade *Logs* → queries da pasta `../kql`.
- **Cosmos DB** → Data Explorer → `mod07 / pedidos` → documento com `id = messageId`,
  partição `/correlationId`.
- **Storage** `stamod03lab03dev001` → container `messages` →
  `yyyy/MM/dd/<correlationId>/<messageId>.json`.

> A ingestão do Application Insights tem latência típica de 1–3 minutos.
