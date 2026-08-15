using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;
using Usuarios.Adapters.Persistence;
using Usuarios.Adapters.Repositories;
using Usuarios.Api.Endpoints;
using Usuarios.Application.Services;
using Usuarios.Domain.Ports;
using System.Reflection;

var builder = WebApplication.CreateBuilder(args);

var applicationInsightsConnectionString =
    builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];

if (!string.IsNullOrWhiteSpace(applicationInsightsConnectionString))
{
    builder.Services.AddOpenTelemetry().UseAzureMonitor(options =>
    {
        options.ConnectionString = applicationInsightsConnectionString;
        options.EnableLiveMetrics = true;
    });
}

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer((document, _, _) =>
    {
        document.Info.Description = "API para cadastro, consulta, atualização e remoção de usuários.";
        document.Info.Contact = new()
        {
            Name = "Equipe Usuarios API",
            Url = new Uri("https://github.com/highexpert-tecnologia/posgraduacao-arquiteturaazure-ai")
        };

        return Task.CompletedTask;
    });
});

var connectionString = builder.Configuration.GetConnectionString("UsersDatabase");
if (string.IsNullOrWhiteSpace(connectionString))
{
    builder.Services.AddSingleton<IUserRepository, InMemoryUserRepository>();
    builder.Services.AddSingleton<UserService>();
}
else
{
    builder.Services.AddDbContext<UsersDbContext>(options =>
        options.UseSqlServer(connectionString, sqlOptions => sqlOptions.EnableRetryOnFailure()));
    builder.Services.AddScoped<IUserRepository, SqlUserRepository>();
    builder.Services.AddScoped<UserService>();
}

var app = builder.Build();

var isOpenApiGeneration =
    Assembly.GetEntryAssembly()?.GetName().Name == "GetDocument.Insider";

if (!isOpenApiGeneration)
{
    if (builder.Configuration.GetValue<bool>("Database:ApplyMigrations") &&
        !string.IsNullOrWhiteSpace(connectionString))
    {
        using var scope = app.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();
        await dbContext.Database.MigrateAsync();
    }
}

app.MapOpenApi();
app.UseSwagger();
app.UseSwaggerUI();
app.MapScalarApiReference();

app.MapRootEndpoint();
app.MapHealthEndpoints();
app.MapUserEndpoints();

await app.RunAsync();

public partial class Program
{
    protected Program()
    {
    }
}
