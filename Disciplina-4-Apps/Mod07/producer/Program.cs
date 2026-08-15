using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        // Telemetria: App Insights no worker isolado (traces, dependencias, eventos custom)
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        // ServiceBusClient autenticado via Managed Identity (sem connection string)
        var fqns = Environment.GetEnvironmentVariable("ServiceBusConnection__fullyQualifiedNamespace")
            ?? throw new InvalidOperationException("ServiceBusConnection__fullyQualifiedNamespace nao configurado.");

        services.AddSingleton(_ => new ServiceBusClient(fqns, new DefaultAzureCredential()));
    })
    .Build();

host.Run();
