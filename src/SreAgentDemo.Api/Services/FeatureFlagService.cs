namespace SreAgentDemo.Api.Services;

/// <summary>
/// Holds the runtime state of the two feature flags.
/// Initialized from environment variables; toggleable at runtime via /admin endpoints.
/// </summary>
public class FeatureFlagService
{
    private volatile bool _failureMode;
    private volatile bool _dbTimeout;

    public FeatureFlagService(IConfiguration config)
    {
        _failureMode = IsTrue(config["ENABLE_FAILURE_MODE"]);
        _dbTimeout = IsTrue(config["ENABLE_DB_TIMEOUT"]);
    }

    public bool FailureMode
    {
        get => _failureMode;
        set => _failureMode = value;
    }

    public bool DbTimeout
    {
        get => _dbTimeout;
        set => _dbTimeout = value;
    }

    private static bool IsTrue(string? value) =>
        string.Equals(value, "true", StringComparison.OrdinalIgnoreCase);
}
