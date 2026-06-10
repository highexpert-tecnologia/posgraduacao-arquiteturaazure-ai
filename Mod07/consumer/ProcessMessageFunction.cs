using System.Text.Json;
using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.ApplicationInsights;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Mod07.Consumer;

/// <summary>
/// Function B (Consumer): disparada pela fila do Service Bus. Persiste o pedido de
/// compra em DOIS destinos:
///   1) Blob (Storage Account) -> arquivo/auditoria do envelope completo;
///   2) Cosmos DB SQL serverless -> documento consultavel do pedido (upsert).
/// Emite telemetria correlacionada por messageId (tecnico) e correlationId (negocio).
/// O trace distribuido (W3C traceparent) propaga do Producer ate aqui, fechando a
/// jornada no Application Insights (APIM -> Producer -> Service Bus -> Consumer -> Blob + Cosmos).
/// </summary>
public class ProcessMessageFunction
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly BlobServiceClient _blobService;
    private readonly CosmosClient _cosmos;
    private readonly TelemetryClient _telemetry;
    private readonly ILogger<ProcessMessageFunction> _logger;
    private readonly string _containerName;
    private readonly string _cosmosDb;
    private readonly string _cosmosContainer;

    public ProcessMessageFunction(
        BlobServiceClient blobService,
        CosmosClient cosmos,
        TelemetryClient telemetry,
        ILogger<ProcessMessageFunction> logger)
    {
        _blobService = blobService;
        _cosmos = cosmos;
        _telemetry = telemetry;
        _logger = logger;
        _containerName = Environment.GetEnvironmentVariable("BLOB_CONTAINER") ?? "messages";
        _cosmosDb = Environment.GetEnvironmentVariable("COSMOS_DATABASE") ?? "mod07";
        _cosmosContainer = Environment.GetEnvironmentVariable("COSMOS_CONTAINER") ?? "pedidos";
    }

    [Function("ProcessMessage")]
    public async Task Run(
        [ServiceBusTrigger("%QUEUE_NAME%", Connection = "ServiceBusConnection")] ServiceBusReceivedMessage message)
    {
        var messageId = message.ApplicationProperties.TryGetValue("messageId", out var mid) && mid is not null
            ? mid.ToString()!
            : message.MessageId;

        // correlationId de negocio: app property -> campo nativo -> fallback messageId
        var correlationId =
            (message.ApplicationProperties.TryGetValue("correlationId", out var cid) && cid is not null ? cid.ToString() : null)
            ?? (string.IsNullOrWhiteSpace(message.CorrelationId) ? null : message.CorrelationId)
            ?? messageId;

        var body = message.Body.ToString();
        OrderEnvelope? envelope = null;
        try { envelope = JsonSerializer.Deserialize<OrderEnvelope>(body, JsonOpts); }
        catch (JsonException ex) { _logger.LogWarning(ex, "Envelope nao-JSON para msg {MessageId}; segue como texto.", messageId); }

        var itemCount = envelope?.ItemCount ?? envelope?.Order?.Items.Sum(i => i.Quantity) ?? 0;
        var totalAmount = envelope?.TotalAmount ?? 0m;

        var props = new Dictionary<string, string>
        {
            ["messageId"] = messageId,
            ["correlationId"] = correlationId,
            ["stage"] = "consumer",
            ["enqueuedUtc"] = message.EnqueuedTime.ToString("o"),
            ["deliveryCount"] = message.DeliveryCount.ToString(),
            ["itemCount"] = itemCount.ToString(),
            ["totalAmount"] = totalAmount.ToString("F2")
        };
        _telemetry.TrackEvent("MessageReceived", props);
        _logger.LogInformation(
            "Pedido {CorrelationId} (msg {MessageId}) recebido da fila (delivery #{Count}).",
            correlationId, messageId, message.DeliveryCount);

        try
        {
            var processedUtc = DateTimeOffset.UtcNow;

            // ---- Destino 1: Blob (envelope completo) ---------------------------
            var container = _blobService.GetBlobContainerClient(_containerName);
            await container.CreateIfNotExistsAsync();

            var blobName = $"{processedUtc:yyyy/MM/dd}/{correlationId}/{messageId}.json";
            var blob = container.GetBlobClient(blobName);
            var record = JsonSerializer.Serialize(new
            {
                messageId,
                correlationId,
                processedUtc,
                enqueuedUtc = message.EnqueuedTime,
                deliveryCount = message.DeliveryCount,
                envelope
            }, JsonOpts);
            await blob.UploadAsync(BinaryData.FromString(record), overwrite: true);

            _telemetry.TrackEvent("BlobWritten", new Dictionary<string, string>
            {
                ["messageId"] = messageId,
                ["correlationId"] = correlationId,
                ["stage"] = "consumer",
                ["container"] = _containerName,
                ["blob"] = blobName
            });
            _logger.LogInformation("Pedido {CorrelationId} persistido em blob {Container}/{Blob}.", correlationId, _containerName, blobName);

            // ---- Destino 2: Cosmos DB SQL serverless (upsert do pedido) --------
            var cosmosContainer = _cosmos.GetContainer(_cosmosDb, _cosmosContainer);
            var doc = new
            {
                id = messageId,                 // chave do documento (Cosmos exige "id")
                correlationId,                  // partition key (/correlationId) = orderId
                orderId = correlationId,
                kind = envelope?.Kind ?? "purchase-order",
                status = "Received",
                requester = envelope?.Order?.Requester,
                costCenter = envelope?.Order?.CostCenter,
                currency = envelope?.Currency ?? "BRL",
                itemCount,
                totalAmount,
                items = envelope?.Order?.Items?
                    .Select(i => new { sku = i.Sku, name = i.Name, quantity = i.Quantity, unitPrice = i.UnitPrice })
                    .ToList(),
                source = envelope?.Source ?? "func-mod07-consumer",
                messageId,
                createdUtc = envelope?.CreatedUtc,
                enqueuedUtc = message.EnqueuedTime,
                processedUtc,
                deliveryCount = message.DeliveryCount
            };

            var resp = await cosmosContainer.UpsertItemAsync(doc, new PartitionKey(correlationId));

            _telemetry.TrackEvent("CosmosDocWritten", new Dictionary<string, string>
            {
                ["messageId"] = messageId,
                ["correlationId"] = correlationId,
                ["stage"] = "consumer",
                ["database"] = _cosmosDb,
                ["container"] = _cosmosContainer,
                ["requestCharge"] = resp.RequestCharge.ToString("F2")
            });
            _logger.LogInformation(
                "Pedido {CorrelationId} gravado no Cosmos {Db}/{Container} (id={MessageId}, RU={RU}).",
                correlationId, _cosmosDb, _cosmosContainer, messageId, resp.RequestCharge);
        }
        catch (Exception ex)
        {
            _telemetry.TrackException(ex, new Dictionary<string, string>
            {
                ["messageId"] = messageId,
                ["correlationId"] = correlationId,
                ["stage"] = "consumer"
            });
            _logger.LogError(ex, "Falha ao persistir pedido {CorrelationId} (msg {MessageId}).", correlationId, messageId);
            throw; // re-lanca para abandonar a mensagem e exercitar retry/dead-letter
        }
    }
}
