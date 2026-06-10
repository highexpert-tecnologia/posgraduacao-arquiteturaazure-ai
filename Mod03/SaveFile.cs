using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace POSGraducao;

public class SaveFile
{
    private readonly ILogger<SaveFile> _logger;

    public SaveFile(ILogger<SaveFile> logger)
    {
        _logger = logger;
    }

    [Function("SaveFile")]
    public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "get", "post")] 
    HttpRequest req)
    {
        using var reader = new StreamReader(req.Body);
        var json = await reader.ReadToEndAsync();
        _logger.LogInformation("C# HTTP trigger function processed a request.");
        _logger.LogInformation("Payload: {Payload}", json);
        return new OkObjectResult(new { message = "Welcome to Azure Functions!", payload = json });
    }
}
