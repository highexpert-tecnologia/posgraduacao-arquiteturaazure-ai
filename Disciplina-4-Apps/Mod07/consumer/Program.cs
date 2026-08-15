using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        // Telemetria: App Insights no worker isolado
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        var credential = new DefaultAzureCredential();

        // BlobServiceClient autenticado via Managed Identity (sem connection string)
        var blobUri = Environment.GetEnvironmentVariable("STORAGE_BLOB_URI")
            ?? throw new InvalidOperationException("STORAGE_BLOB_URI nao configurado.");
        services.AddSingleton(_ => new BlobServiceClient(new Uri(blobUri), credential));

        // CosmosClient autenticado via Managed Identity + RBAC de dados do Cosmos
        var cosmosEndpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT nao configurado.");
        services.AddSingleton(_ => new CosmosClient(cosmosEndpoint, credential, new CosmosClientOptions
        {
            ApplicationName = "func-mod07-consumer",
            // SDK ja instrumenta dependencias no App Insights quando a telemetria esta ligada
        }));
    })
    .Build();

host.Run();
