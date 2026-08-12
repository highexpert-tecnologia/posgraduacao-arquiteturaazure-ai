using System.Text.Json.Serialization;

namespace Mod07.Producer;

/// <summary>
/// Item de um pedido de compra (ex.: caneta, papel sulfite, teclado, mouse, caneca).
/// </summary>
public record PurchaseOrderItem
{
    public string Sku { get; init; } = "";
    public string Name { get; init; } = "";
    public int Quantity { get; init; }
    public decimal UnitPrice { get; init; }

    [JsonIgnore]
    public decimal LineTotal => Quantity * UnitPrice;
}

/// <summary>
/// Pedido de compra recebido via HTTP. O <see cref="OrderId"/> vira o
/// correlationId de negocio que amarra toda a jornada (Producer -> Service Bus
/// -> Consumer -> Blob + Cosmos) no Application Insights.
/// </summary>
public record PurchaseOrder
{
    public string? OrderId { get; init; }
    public string? Requester { get; init; }
    public string? CostCenter { get; init; }
    public string Currency { get; init; } = "BRL";
    public List<PurchaseOrderItem> Items { get; init; } = new();
}
