using System.Net;
using System.Text.Json;
using Azure.Messaging.ServiceBus;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace Mod07.Producer;

/// <summary>
/// Function A (Producer): exposta via APIM. Recebe um PEDIDO DE COMPRA via HTTP POST
/// e publica na fila do Service Bus. Emite telemetria correlacionada por:
///   - messageId    -> ID tecnico de CADA mensagem
///   - correlationId -> ID de NEGOCIO do pedido (orderId), que amarra a jornada inteira
/// para que o pedido possa ser seguido ponta-a-ponta no Application Insights.
/// </summary>
public class SendMessageFunction
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly ServiceBusClient _sbClient;
    private readonly TelemetryClient _telemetry;
    private readonly ILogger<SendMessageFunction> _logger;
    private readonly string _queueName;

    public SendMessageFunction(ServiceBusClient sbClient, TelemetryClient telemetry, ILogger<SendMessageFunction> logger)
    {
        _sbClient = sbClient;
        _telemetry = telemetry;
        _logger = logger;
        _queueName = Environment.GetEnvironmentVariable("QUEUE_NAME") ?? "mod07-msgjourney";
    }

    [Function("SendMessage")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "send")] HttpRequestData req)
    {
        var messageId = Guid.NewGuid().ToString("N");

        // ---- Le e valida o pedido de compra ----------------------------------
        string requestBody;
        using (var reader = new StreamReader(req.Body))
        {
            requestBody = await reader.ReadToEndAsync();
        }

        PurchaseOrder order;
        try
        {
            order = string.IsNullOrWhiteSpace(requestBody)
                ? BuildSampleOrder()
                : JsonSerializer.Deserialize<PurchaseOrder>(requestBody, JsonOpts) ?? BuildSampleOrder();
        }
        catch (JsonException)
        {
            var bad = req.CreateResponse(HttpStatusCode.BadRequest);
            await bad.WriteAsJsonAsync(new { status = "invalid", error = "JSON do pedido de compra invalido." });
            return bad;
        }

        if (order.Items.Count == 0)
        {
            order = order with { Items = BuildSampleOrder().Items };
        }

        // correlationId de negocio = orderId (gera um se nao vier no payload)
        var correlationId = string.IsNullOrWhiteSpace(order.OrderId)
            ? $"PO-{DateTimeOffset.UtcNow:yyyyMMdd}-{messageId[..8]}"
            : order.OrderId!.Trim();
        order = order with { OrderId = correlationId };

        var totalAmount = order.Items.Sum(i => i.LineTotal);
        var itemCount = order.Items.Sum(i => i.Quantity);

        // Operacao do App Insights carimbada com os dois eixos de correlacao
        using var op = _telemetry.StartOperation<RequestTelemetry>("SendMessage");
        op.Telemetry.Properties["messageId"] = messageId;
        op.Telemetry.Properties["correlationId"] = correlationId;

        var envelope = JsonSerializer.Serialize(new
        {
            messageId,
            correlationId,
            createdUtc = DateTimeOffset.UtcNow,
            source = "func-mod07-producer",
            kind = "purchase-order",
            totalAmount,
            currency = order.Currency,
            itemCount,
            order
        }, JsonOpts);

        var message = new ServiceBusMessage(envelope)
        {
            MessageId = messageId,
            CorrelationId = correlationId,   // campo nativo do Service Bus -> aparece na dependencia
            ContentType = "application/json",
            Subject = "purchase-order"
        };
        // App properties para correlacao simples em KQL (alem do traceparent W3C,
        // injetado automaticamente para o trace distribuido).
        message.ApplicationProperties["messageId"] = messageId;
        message.ApplicationProperties["correlationId"] = correlationId;
        message.ApplicationProperties["source"] = "func-mod07-producer";

        var sender = _sbClient.CreateSender(_queueName);
        try
        {
            await sender.SendMessageAsync(message);

            _telemetry.TrackEvent("MessageSent", new Dictionary<string, string>
            {
                ["messageId"] = messageId,
                ["correlationId"] = correlationId,
                ["queue"] = _queueName,
                ["stage"] = "producer",
                ["itemCount"] = itemCount.ToString(),
                ["totalAmount"] = totalAmount.ToString("F2")
            });
            _logger.LogInformation(
                "Pedido {CorrelationId} (msg {MessageId}) enviado para {Queue}: {Items} itens, total {Total} {Currency}.",
                correlationId, messageId, _queueName, itemCount, totalAmount, order.Currency);

            var ok = req.CreateResponse(HttpStatusCode.Accepted);
            await ok.WriteAsJsonAsync(new
            {
                status = "accepted",
                messageId,
                correlationId,
                orderId = correlationId,
                itemCount,
                totalAmount,
                currency = order.Currency,
                queue = _queueName
            });
            return ok;
        }
        catch (Exception ex)
        {
            op.Telemetry.Success = false;
            _telemetry.TrackException(ex, new Dictionary<string, string>
            {
                ["messageId"] = messageId,
                ["correlationId"] = correlationId,
                ["stage"] = "producer"
            });
            _logger.LogError(ex, "Falha ao enviar pedido {CorrelationId} (msg {MessageId}).", correlationId, messageId);

            var fail = req.CreateResponse(HttpStatusCode.InternalServerError);
            await fail.WriteAsJsonAsync(new { status = "error", messageId, correlationId, error = ex.Message });
            return fail;
        }
        finally
        {
            await sender.DisposeAsync();
        }
    }

    /// <summary>Pedido de exemplo (caneta, papel sulfite, teclado, mouse, caneca).</summary>
    private static PurchaseOrder BuildSampleOrder() => new()
    {
        Requester = "Compras - TI",
        CostCenter = "TI-Infra",
        Currency = "BRL",
        Items = new()
        {
            new PurchaseOrderItem { Sku = "CAN-AZ-001", Name = "Caneta esferografica azul", Quantity = 50, UnitPrice = 1.50m },
            new PurchaseOrderItem { Sku = "PAP-A4-500", Name = "Papel sulfite A4 (resma 500fl)", Quantity = 20, UnitPrice = 24.90m },
            new PurchaseOrderItem { Sku = "TEC-ABNT2", Name = "Teclado USB ABNT2", Quantity = 5, UnitPrice = 89.90m },
            new PurchaseOrderItem { Sku = "MOU-OPT-USB", Name = "Mouse optico USB", Quantity = 5, UnitPrice = 39.90m },
            new PurchaseOrderItem { Sku = "CCA-CER-350", Name = "Caneca ceramica 350ml", Quantity = 10, UnitPrice = 19.90m }
        }
    };
}
