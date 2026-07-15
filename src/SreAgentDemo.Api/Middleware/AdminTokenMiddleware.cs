using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;

namespace SreAgentDemo.Api.Middleware;

/// <summary>
/// Protects /admin/* endpoints with a shared token read from the ADMIN_TOKEN env var.
/// Returns HTTP 401 (no body) if the X-Admin-Token header is missing or mismatched.
/// </summary>
public class AdminTokenMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<AdminTokenMiddleware> _logger;
    private readonly byte[] _expectedTokenBytes;

    public AdminTokenMiddleware(RequestDelegate next, ILogger<AdminTokenMiddleware> logger, IConfiguration config)
    {
        _next = next;
        _logger = logger;

        var token = config["ADMIN_TOKEN"] ?? string.Empty;
        _expectedTokenBytes = Encoding.UTF8.GetBytes(token);
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (!context.Request.Path.StartsWithSegments("/admin"))
        {
            await _next(context);
            return;
        }

        var provided = context.Request.Headers["X-Admin-Token"].FirstOrDefault() ?? string.Empty;
        var providedBytes = Encoding.UTF8.GetBytes(provided);

        if (!CryptographicOperations.FixedTimeEquals(providedBytes, _expectedTokenBytes))
        {
            _logger.LogWarning("Unauthorized /admin access attempt from {IP}", context.Connection.RemoteIpAddress);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        await _next(context);
    }
}
