using Azure.Monitor.OpenTelemetry.AspNetCore;
using Serilog;
using Serilog.Events;
using SreAgentDemo.Api.Middleware;
using SreAgentDemo.Api.Models;
using SreAgentDemo.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// ─── Serilog ────────────────────────────────────────────────────────────────
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("deployment.version", builder.Configuration["DEPLOYMENT_VERSION"] ?? "local")
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj} {Properties:j}{NewLine}{Exception}")
    .WriteTo.ApplicationInsights(
        builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"] ?? string.Empty,
        TelemetryConverter.Traces)
    .CreateLogger();

builder.Host.UseSerilog();

// ─── OpenTelemetry / Application Insights ───────────────────────────────────
var appInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
if (!string.IsNullOrEmpty(appInsightsConnectionString))
{
    builder.Services.AddOpenTelemetry().UseAzureMonitor(o =>
    {
        o.ConnectionString = appInsightsConnectionString;
    });
}

// ─── Services ────────────────────────────────────────────────────────────────
builder.Services.AddSingleton<FeatureFlagService>();
builder.Services.AddSingleton<ProductService>();
builder.Services.AddSingleton<OrderService>();
builder.Services.AddSingleton<CheckoutService>();

var app = builder.Build();

// ─── Middleware pipeline ──────────────────────────────────────────────────────
app.UseDefaultFiles();
app.UseStaticFiles();
app.UseMiddleware<AdminTokenMiddleware>();
app.UseMiddleware<FailureModeMiddleware>();
app.UseMiddleware<DbTimeoutMiddleware>();

// ─── Exception handler (converts SimulatedFailureException → HTTP 500) ───────
app.UseExceptionHandler(errApp => errApp.Run(async ctx =>
{
    var ex = ctx.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>()?.Error;
    if (ex is SimulatedFailureException sfe)
    {
        ctx.Response.StatusCode = 500;
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsJsonAsync(new
        {
            error = "InternalServerError",
            errorCode = sfe.ErrorCode,
            correlationId = sfe.CorrelationId,
            deploymentVersion = sfe.DeploymentVersion,
            message = "A simulated failure occurred."
        });
    }
    else
    {
        ctx.Response.StatusCode = 500;
        await ctx.Response.WriteAsJsonAsync(new { error = "InternalServerError" });
    }
}));

// ─── Health endpoint ──────────────────────────────────────────────────────────
app.MapGet("/health", (FeatureFlagService flags, IConfiguration config) =>
{
    var deploymentVersion = config["DEPLOYMENT_VERSION"] ?? "local";
    return Results.Ok(new
    {
        status = "healthy",
        version = deploymentVersion,
        timestamp = DateTime.UtcNow,
        flags = new FeatureFlagState
        {
            FailureMode = flags.FailureMode,
            DbTimeout = flags.DbTimeout
        }
    });
});

// ─── Products endpoint ────────────────────────────────────────────────────────
app.MapGet("/products", async (ProductService svc, CancellationToken ct) =>
{
    var products = await svc.GetProductsAsync(ct);
    return Results.Ok(new { count = products.Count, products });
});

// ─── Orders endpoint ──────────────────────────────────────────────────────────
app.MapPost("/orders", async (HttpContext ctx, OrderService svc, CancellationToken ct) =>
{
    var body = await ctx.Request.ReadFromJsonAsync<OrderRequest>(ct);
    var order = await svc.CreateOrderAsync(
        body?.ProductId ?? 1,
        body?.Quantity ?? 1,
        ctx.TraceIdentifier,   // was ctx.Session.Id — session middleware not registered
        ct);
    return Results.Ok(order);
});

// ─── Checkout endpoint ────────────────────────────────────────────────────────
app.MapPost("/checkout", async (HttpContext ctx, CheckoutService svc, CancellationToken ct) =>
{
    var body = await ctx.Request.ReadFromJsonAsync<CheckoutRequest>(ct);
    var result = await svc.ProcessCheckoutAsync(
        body?.ProductId ?? 1,
        body?.Quantity ?? 1,
        ctx.TraceIdentifier,
        ct);
    return Results.Ok(result);
});

// ─── Admin endpoints (protected by AdminTokenMiddleware) ──────────────────────
app.MapPost("/admin/failure-mode", (ToggleFlagRequest req, FeatureFlagService flags, ILogger<Program> logger) =>
{
    flags.FailureMode = req.Enabled;
    logger.LogInformation("ENABLE_FAILURE_MODE set to {Value}", req.Enabled);
    return Results.Ok(new { failureMode = flags.FailureMode, dbTimeout = flags.DbTimeout });
});

app.MapPost("/admin/db-timeout", (ToggleFlagRequest req, FeatureFlagService flags, ILogger<Program> logger) =>
{
    flags.DbTimeout = req.Enabled;
    logger.LogInformation("ENABLE_DB_TIMEOUT set to {Value}", req.Enabled);
    return Results.Ok(new { failureMode = flags.FailureMode, dbTimeout = flags.DbTimeout });
});

app.MapGet("/admin/config", (FeatureFlagService flags, IConfiguration config) =>
{
    return Results.Ok(new
    {
        adminToken = config["ADMIN_TOKEN"] ?? string.Empty,
        flags = new FeatureFlagState
        {
            FailureMode = flags.FailureMode,
            DbTimeout = flags.DbTimeout
        }
    });
});

app.Run();

// ─── Request record types ─────────────────────────────────────────────────────
record OrderRequest(int ProductId, int Quantity);
record CheckoutRequest(int ProductId, int Quantity);
record ToggleFlagRequest(bool Enabled);
