using SreAgentDemo.Api.Services;

namespace SreAgentDemo.Api.Middleware;

/// <summary>
/// When ENABLE_FAILURE_MODE=true:
///   - 30% of requests to /products, /orders, /checkout throw a SimulatedFailureException
///   - Adds a random 3–8 second delay
///   - Enriches all log entries with ErrorCode, CorrelationId, DeploymentVersion
/// </summary>
public class FailureModeMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<FailureModeMiddleware> _logger;
    private readonly IConfiguration _config;
    private static readonly Random _rng = new();

    private static readonly string[] _affectedPaths = ["/products", "/orders", "/checkout"];

    public FailureModeMiddleware(RequestDelegate next, ILogger<FailureModeMiddleware> logger, IConfiguration config)
    {
        _next = next;
        _logger = logger;
        _config = config;
    }

    public async Task InvokeAsync(HttpContext context, FeatureFlagService flags)
    {
        if (!flags.FailureMode)
        {
            await _next(context);
            return;
        }

        var path = context.Request.Path.Value ?? string.Empty;
        var isAffected = _affectedPaths.Any(p => path.StartsWith(p, StringComparison.OrdinalIgnoreCase));

        if (!isAffected)
        {
            await _next(context);
            return;
        }

        var correlationId = context.TraceIdentifier;
        var deploymentVersion = _config["DEPLOYMENT_VERSION"] ?? "unknown";

        using var _ = _logger.BeginScope(new Dictionary<string, object>
        {
            ["correlation.id"] = correlationId,
            ["deployment.version"] = deploymentVersion,
            ["active.flags"] = "FAILURE_MODE"
        });

        // 30% failure rate
        if (_rng.NextDouble() < 0.30)
        {
            var delayMs = _rng.Next(3000, 8001);
            await Task.Delay(delayMs);

            var errorCode = "SIM_FAILURE_001";
            _logger.LogError(
                "Simulated failure on {Path}. ErrorCode={ErrorCode} CorrelationId={CorrelationId} DeploymentVersion={DeploymentVersion} DelayMs={DelayMs}",
                path, errorCode, correlationId, deploymentVersion, delayMs);

            throw new SimulatedFailureException(errorCode, correlationId, deploymentVersion);
        }

        // Remaining 70% — add smaller jitter to make latency distribution realistic
        var jitterMs = _rng.Next(50, 300);
        await Task.Delay(jitterMs);

        await _next(context);
    }
}

public class SimulatedFailureException : Exception
{
    public string ErrorCode { get; }
    public string CorrelationId { get; }
    public string DeploymentVersion { get; }

    public SimulatedFailureException(string errorCode, string correlationId, string deploymentVersion)
        : base($"Simulated failure [{errorCode}]")
    {
        ErrorCode = errorCode;
        CorrelationId = correlationId;
        DeploymentVersion = deploymentVersion;
    }
}
