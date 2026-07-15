using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using SreAgentDemo.Api.Middleware;
using SreAgentDemo.Api.Services;
using Xunit;

namespace SreAgentDemo.Tests;

public class FailureModeMiddlewareTests
{
    private static DefaultHttpContext MakeContext(string path)
    {
        var ctx = new DefaultHttpContext();
        ctx.Request.Path = path;
        return ctx;
    }

    private static IConfiguration MakeConfig(string? deploymentVersion = "test-sha") =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["DEPLOYMENT_VERSION"] = deploymentVersion
            })
            .Build();

    [Fact]
    public async Task HealthEndpoint_SkipsFailureMode_Always()
    {
        var flags = new FeatureFlagService(new ConfigurationBuilder().Build()) { FailureMode = true };
        var delegateCalled = false;
        RequestDelegate next = _ => { delegateCalled = true; return Task.CompletedTask; };
        var mw = new FailureModeMiddleware(next, NullLogger<FailureModeMiddleware>.Instance, MakeConfig());
        var ctx = MakeContext("/health");

        await mw.InvokeAsync(ctx, flags);

        Assert.True(delegateCalled);
    }

    [Fact]
    public async Task WhenFailureModeOff_NextAlwaysCalled()
    {
        var flags = new FeatureFlagService(new ConfigurationBuilder().Build()) { FailureMode = false };
        var calls = 0;
        RequestDelegate next = _ => { calls++; return Task.CompletedTask; };
        var mw = new FailureModeMiddleware(next, NullLogger<FailureModeMiddleware>.Instance, MakeConfig());

        for (var i = 0; i < 20; i++)
        {
            await mw.InvokeAsync(MakeContext("/products"), flags);
        }

        Assert.Equal(20, calls);
    }

    [Fact]
    public async Task WhenFailureModeOn_SomeRequestsFail()
    {
        var flags = new FeatureFlagService(new ConfigurationBuilder().Build()) { FailureMode = true };
        var successes = 0;
        var failures = 0;
        RequestDelegate next = _ => { successes++; return Task.CompletedTask; };
        var mw = new FailureModeMiddleware(next, NullLogger<FailureModeMiddleware>.Instance, MakeConfig());

        for (var i = 0; i < 100; i++)
        {
            try
            {
                await mw.InvokeAsync(MakeContext("/products"), flags);
            }
            catch (SimulatedFailureException)
            {
                failures++;
            }
        }

        // With 30% failure rate over 100 requests, expect between 10–50 failures
        Assert.InRange(failures, 5, 60);
        Assert.True(successes > 0);
    }

    [Fact]
    public async Task SimulatedFailureException_HasExpectedProperties()
    {
        var flags = new FeatureFlagService(new ConfigurationBuilder().Build()) { FailureMode = true };
        SimulatedFailureException? caught = null;
        RequestDelegate next = _ => Task.CompletedTask;
        var mw = new FailureModeMiddleware(next, NullLogger<FailureModeMiddleware>.Instance, MakeConfig("abc123"));

        // Run enough times to hit a failure
        for (var i = 0; i < 50 && caught is null; i++)
        {
            try { await mw.InvokeAsync(MakeContext("/checkout"), flags); }
            catch (SimulatedFailureException ex) { caught = ex; }
        }

        Assert.NotNull(caught);
        Assert.Equal("SIM_FAILURE_001", caught.ErrorCode);
        Assert.NotEmpty(caught.CorrelationId);
        Assert.Equal("abc123", caught.DeploymentVersion);
    }
}

public class AdminTokenMiddlewareTests
{
    private static IConfiguration MakeConfig(string token) =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["ADMIN_TOKEN"] = token })
            .Build();

    [Fact]
    public async Task ValidToken_CallsNext()
    {
        var called = false;
        RequestDelegate next = _ => { called = true; return Task.CompletedTask; };
        var mw = new AdminTokenMiddleware(next, NullLogger<AdminTokenMiddleware>.Instance, MakeConfig("secret-guid"));

        var ctx = new DefaultHttpContext();
        ctx.Request.Path = "/admin/failure-mode";
        ctx.Request.Headers["X-Admin-Token"] = "secret-guid";
        ctx.Response.Body = new MemoryStream();

        await mw.InvokeAsync(ctx);

        Assert.True(called);
        Assert.NotEqual(401, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task MissingToken_Returns401()
    {
        RequestDelegate next = _ => Task.CompletedTask;
        var mw = new AdminTokenMiddleware(next, NullLogger<AdminTokenMiddleware>.Instance, MakeConfig("secret-guid"));

        var ctx = new DefaultHttpContext();
        ctx.Request.Path = "/admin/db-timeout";
        ctx.Response.Body = new MemoryStream();

        await mw.InvokeAsync(ctx);

        Assert.Equal(401, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task WrongToken_Returns401()
    {
        RequestDelegate next = _ => Task.CompletedTask;
        var mw = new AdminTokenMiddleware(next, NullLogger<AdminTokenMiddleware>.Instance, MakeConfig("secret-guid"));

        var ctx = new DefaultHttpContext();
        ctx.Request.Path = "/admin/failure-mode";
        ctx.Request.Headers["X-Admin-Token"] = "wrong-token";
        ctx.Response.Body = new MemoryStream();

        await mw.InvokeAsync(ctx);

        Assert.Equal(401, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task NonAdminPath_SkipsCheck()
    {
        var called = false;
        RequestDelegate next = _ => { called = true; return Task.CompletedTask; };
        var mw = new AdminTokenMiddleware(next, NullLogger<AdminTokenMiddleware>.Instance, MakeConfig("secret-guid"));

        var ctx = new DefaultHttpContext();
        ctx.Request.Path = "/health";
        ctx.Response.Body = new MemoryStream();

        await mw.InvokeAsync(ctx);

        Assert.True(called);
    }
}
