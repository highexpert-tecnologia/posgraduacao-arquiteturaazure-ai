namespace Mod07.Consumer;

/// <summary>Item do pedido de compra (espelha o modelo do Producer).</summary>
public record PurchaseOrderItem
{
    public string Sku { get; init; } = "";
    public string Name { get; init; } = "";
    public int Quantity { get; init; }
    public decimal UnitPrice { get; init; }
}

/// <summary>Pedido de compra carregado do envelope da mensagem.</summary>
public record PurchaseOrder
{
    public string? OrderId { get; init; }
    public string? Requester { get; init; }
    public string? CostCenter { get; init; }
    public string Currency { get; init; } = "BRL";
    public List<PurchaseOrderItem> Items { get; init; } = new();
}

/// <summary>Envelope publicado pelo Producer no Service Bus.</summary>
public record OrderEnvelope
{
    public string? MessageId { get; init; }
    public string? CorrelationId { get; init; }
    public DateTimeOffset CreatedUtc { get; init; }
    public string? Source { get; init; }
    public string? Kind { get; init; }
    public decimal TotalAmount { get; init; }
    public string Currency { get; init; } = "BRL";
    public int ItemCount { get; init; }
    public PurchaseOrder? Order { get; init; }
}
