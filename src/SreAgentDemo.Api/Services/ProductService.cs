using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace SreAgentDemo.Api.Services;

public class ProductService
{
    private static readonly ActivitySource _activitySource = new("SreAgentDemo.Api");
    private static readonly Meter _meter = new("SreAgentDemo.Api");
    private static readonly Histogram<double> _dbDuration = _meter.CreateHistogram<double>("db.query.duration", "ms", "Simulated DB query duration");

    private static readonly Random _rng = new();

    private static readonly IReadOnlyList<object> _products =
    [
        new { Id = 1, Name = "Azure SRE T-Shirt", Price = 29.99, Category = "Apparel" },
        new { Id = 2, Name = "Cloud Architect Mug", Price = 14.99, Category = "Accessories" },
        new { Id = 3, Name = "Observability Handbook", Price = 49.99, Category = "Books" },
        new { Id = 4, Name = "On-Call Survival Kit", Price = 79.99, Category = "Bundles" },
        new { Id = 5, Name = "SRE Agent Poster", Price = 9.99, Category = "Prints" }
    ];

    public async Task<IReadOnlyList<object>> GetProductsAsync(CancellationToken ct = default)
    {
        using var activity = _activitySource.StartActivity("ProductService.GetProducts", ActivityKind.Internal);
        activity?.SetTag("db.operation", "SELECT");
        activity?.SetTag("db.table", "products");

        var sw = Stopwatch.StartNew();
        // Simulate DB read latency
        await Task.Delay(_rng.Next(40, 70), ct);
        _dbDuration.Record(sw.ElapsedMilliseconds, new TagList { { "operation", "GetProducts" } });

        activity?.SetTag("result.count", _products.Count);
        return _products;
    }
}
