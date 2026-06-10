
sequenceDiagram
    participant AG as Order Aggregate
    participant DB as order_db
    participant WK as Outbox Worker
    participant SB as Service Bus / Event Grid
    participant RC as Recommendations (...)

    activate AG
    AG->>AG: process 'new_order' command

    rect rgb(225, 240, 252)
    Note over AG,DB: transacao unica (atomica)
    AG->>DB: begin transaction
    activate DB
    AG->>DB: 1. INSERT pedido
    AG->>DB: 1. INSERT outbox_event (published = false)
    AG->>DB: 2. commit
    deactivate DB
    end
    deactivate AG

    Note over WK: worker assincrono, roda separado da requisicao
    loop a cada intervalo de polling
        WK->>DB: 3. SELECT outbox_event WHERE published = false
        activate DB
        DB-->>WK: linhas pendentes
        deactivate DB
        WK->>SB: 4. envia 'order_created'
        activate SB
        SB->>RC: deliver 'order_created'
        deactivate SB
        WK->>DB: 5. UPDATE outbox_event SET published = true
    end

    Note over AG,SB: resolve dual-write, banco e broker nunca divergem
