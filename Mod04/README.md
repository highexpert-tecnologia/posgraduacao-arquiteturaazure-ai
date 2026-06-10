# Azure Service Bus — Pub/Sub com 2 Consumers

Exemplo demonstrando o padrão **publish/subscribe** no Azure Service Bus usando **Topic + Subscriptions**, onde cada subscription representa um consumer lógico independente que recebe sua própria cópia da mensagem.

## Arquitetura

```
publisher.py ─► Topic "pedidos" ─┬─► Subscription "faturamento"  ─► consumer_faturamento.py  (sync)
                                 └─► Subscription "logistica"    ─► consumer_logistica.py    (async)
```

## Pré-requisitos

1. Um namespace Service Bus na Azure (tier **Standard** ou **Premium** — Basic não suporta tópicos).
2. Python 3.10+.
3. Connection string com permissão de Send/Listen (ou Managed Identity).

## Setup

```bash
pip install -r requirements.txt
cp .env.example .env
# edite .env com a connection string

python setup_topic.py        # cria tópico e subscriptions
```

## Execução

Em três terminais separados:

```bash
# Terminal 1
python consumer_faturamento.py

# Terminal 2
python consumer_logistica.py

# Terminal 3 (publica 3 pedidos)
python publisher.py
```

Você verá **as duas subscriptions recebendo as 3 mensagens cada** — total de 6 entregas.

## Pontos-chave

| Conceito | Onde aparece |
|---|---|
| Envio em batch | `publisher.py` — `create_message_batch()` |
| Application properties (filtros) | `publisher.py` — usável em SQL rules nas subs |
| ACK explícito | `complete_message()` |
| Reentrega em erro | `abandon_message()` (após N tentativas → DLQ) |
| Sync vs Async SDK | `azure.servicebus` vs `azure.servicebus.aio` |
| Lock renewal | tratado via `MessageLockLostError` |

## Produção

- Substitua a connection string por **Managed Identity** (`DefaultAzureCredential`) — o construtor é `ServiceBusClient(fully_qualified_namespace=..., credential=...)`.
- Configure **Dead Letter Queue** monitoring (a DLQ é criada automaticamente por subscription).
- Defina `max_delivery_count`, `lock_duration` e TTL conforme a criticidade.
- Para alta vazão, use **sessions** se precisar de ordem por chave (ex.: pedido_id).
- Provisione via **Bicep/Terraform**, não pelo `setup_topic.py`.
