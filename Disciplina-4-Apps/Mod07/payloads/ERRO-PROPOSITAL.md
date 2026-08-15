# Cenário de erro proposital — Poison Message (Mod07)

Objetivo: **quebrar a jornada de propósito** para exercitar a observabilidade —
ver a exceção, o funil interrompido no meio, os *retries* do Service Bus e a
mensagem indo parar na **dead-letter queue (DLQ)**, tudo correlacionado pelo
mesmo `correlationId` no Application Insights.

## O payload envenenado

`pedido-006-erro.json` é um pedido válido em tudo, **exceto** pelo `orderId`:
ele tem ~1.115 caracteres (`PO-ERRO-POISON-999…`).

Como `correlationId = orderId` e o Consumer monta o nome do blob como
`yyyy/MM/dd/<correlationId>/<messageId>.json`, o nome final passa de **1.164
caracteres** — acima do limite de **1.024** para nomes de blob no Azure Storage.

Resultado: o `UploadAsync` lança exceção **dentro do `try` do Consumer**.

> Por que aqui e não no Producer? O Producer só faz `Trim()` no `orderId` e
> envia uma mensagem minúscula — passa pelo APIM e pelo Service Bus sem
> problema. A falha é **determinística** e acontece sempre no mesmo ponto: a
> primeira gravação (Blob) do Consumer.

## O que acontece, estágio a estágio

```
APIM            ✓  202/200 (encaminha)
Producer        ✓  MessageSent      (correlationId = PO-ERRO-POISON-999…)
Service Bus     ✓  mensagem enfileirada
Consumer        ✓  MessageReceived  (DeliveryCount = 1)
   └─ Blob      ✗  UploadAsync -> RequestFailedException (nome de blob > 1024)
                ✗  TrackException(stage = "consumer")
                ↻  throw -> mensagem abandonada -> retry
Consumer        ✓  MessageReceived  (DeliveryCount = 2, 3, … até MaxDeliveryCount=10)
Service Bus     ☠  dead-letter (DeadLetterReason = MaxDeliveryCountExceeded)
```

No funil (`08-funil-da-jornada.kql`) você verá `MessageSent` e `MessageReceived`,
mas **sem** `BlobWritten` nem `CosmosDocWritten` — o pedido "some" no meio do caminho.

## Como disparar

```powershell
$key = "<SUA_SUBSCRIPTION_KEY>"   # subscription 'Mod07 Lab Subscription'
try {
  Invoke-RestMethod -Method Post `
    -Uri "https://apim-ai-expert.azure-api.net/mod07/send" `
    -Headers @{ "Ocp-Apim-Subscription-Key" = $key } `
    -ContentType "application/json" `
    -InFile "F:\AI-Expert\POSGraducao\Mod07\payloads\pedido-006-erro.json"
} catch {
  $_.Exception.Response.StatusCode   # Producer responde 202: ele ACEITA; quem falha é o Consumer
}
```

O `correlationId` retornado começa com `PO-ERRO-POISON-` — use-o nas queries.

## O que observar no Application Insights `appi-mod07-aiexpert`

Aguarde 1–3 min de ingestão e rode no blade **Logs**:

```kusto
// Exceções do pedido envenenado, com o estágio onde quebrou
let poison = "PO-ERRO-POISON";
exceptions
| where timestamp > ago(1h)
| where customDimensions.correlationId startswith poison
| project timestamp, problemId, outerMessage,
          stage = tostring(customDimensions.stage),
          correlationId = tostring(customDimensions.correlationId)
| order by timestamp asc
```

```kusto
// Funil quebrado: conta cada evento da jornada do pedido envenenado
let poison = "PO-ERRO-POISON";
customEvents
| where timestamp > ago(1h)
| where customDimensions.correlationId startswith poison
| summarize count() by name
// esperado: MessageSent e MessageReceived (varios, por retry); SEM BlobWritten/CosmosDocWritten
```

```kusto
// Os retries: DeliveryCount subindo a cada reentrega ate o dead-letter
let poison = "PO-ERRO-POISON";
customEvents
| where timestamp > ago(1h)
| where name == "MessageReceived"
| where customDimensions.correlationId startswith poison
| project timestamp, deliveryCount = toint(customDimensions.deliveryCount)
| order by timestamp asc
```

## Onde mais confirmar a falha

- **Service Bus** `sbaiexpert` → fila `mod07-msgjourney` → aba **Dead-letter** →
  a mensagem aparece com `DeadLetterReason = MaxDeliveryCountExceeded`.
- **Storage** `stamod03lab03dev001` / `messages` → **não existe** blob para esse
  pedido (a gravação nunca completou).
- **Cosmos** `mod07 / pedidos` → **não existe** documento para esse `orderId`.

## Limpeza

A mensagem fica na DLQ até ser purgada manualmente (Portal → fila →
Dead-letter → *Receive* / *Purge*). Os eventos no App Insights expiram pela
retenção do workspace.

## Variações do erro (para explorar)

| Como envenenar | Onde quebra | Erro |
|----------------|-------------|------|
| `orderId` > 1.024 chars (este) | Consumer / Blob | nome de blob > 1024 |
| JSON malformado no corpo | Producer | `400 Bad Request` (sem exceção rastreada) |
| `unitPrice` ~7.9e28 × `quantity` | Producer | `OverflowException` no cálculo do total |
