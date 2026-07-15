using Polly;
using Polly.Retry;
using SreAgentDemo.Api.Services;

namespace SreAgentDemo.Api.Middleware;

/// <summary>
/// When ENABLE_DB_TIMEOUT=true, wraps all DB-touching requests in a Polly retry policy
/// that simulates TaskCanceledException. Retries are logged as observable dependency telemetry.
/// </summary>
public class DbTimeoutMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<DbTimeoutMiddleware> _logger;

    private static readonly string[] _affectedPaths = ["/products", "/orders", "/checkout"];

    public DbTimeoutMiddleware(RequestDelegate next, ILogger<DbTimeoutMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, FeatureFlagService flags)
    {
        if (!flags.DbTimeout)
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
        var attempt = 0;

        var policy = Policy
            .Handle<TaskCanceledException>()
            .Or<TimeoutException>()
            .WaitAndRetryAsync(
                retryCount: 3,
                sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
                onRetry: (ex, delay, retryAttempt, _) =>
                {
                    attempt = retryAttempt;
                    _logger.LogWarning(
                        "DB retry {RetryAttempt} after {Delay}ms. CorrelationId={CorrelationId} Error={Error}",
                        retryAttempt, delay.TotalMilliseconds, correlationId, ex.Message);
                });

        await policy.ExecuteAsync(async () =>
        {
            // Simulate a DB timeout on first 2 attempts
            if (attempt < 2)
            {
                await Task.Delay(500); // simulate partial work
                throw new TaskCanceledException($"Simulated DB timeout on attempt {attempt + 1}");
            }

            await _next(context);
        });
    }
}
