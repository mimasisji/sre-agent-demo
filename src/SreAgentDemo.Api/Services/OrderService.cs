using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace SreAgentDemo.Api.Services;

public class OrderService
{
    private static readonly ActivitySource _activitySource = new("SreAgentDemo.Api");
    private static readonly Meter _meter = new("SreAgentDemo.Api");
    private static readonly Histogram<double> _dbDuration = _meter.CreateHistogram<double>("db.query.duration", "ms", "Simulated DB query duration");
    private static readonly Counter<long> _failureCounter = _meter.CreateCounter<long>("order.failure.count", "orders", "Number of failed order operations");

    private static readonly Random _rng = new();
    private static int _orderSequence = 1000;

    public async Task<object> CreateOrderAsync(int productId, int quantity, string sessionId, CancellationToken ct = default)
    {
        using var activity = _activitySource.StartActivity("OrderService.CreateOrder", ActivityKind.Internal);
        activity?.SetTag("db.operation", "INSERT");
        activity?.SetTag("db.table", "orders");
        activity?.SetTag("order.product_id", productId);
        activity?.SetTag("order.quantity", quantity);

        var sw = Stopwatch.StartNew();
        // Simulate DB write latency
        await Task.Delay(_rng.Next(70, 100), ct);
        _dbDuration.Record(sw.ElapsedMilliseconds, new TagList { { "operation", "CreateOrder" } });

        var orderId = Interlocked.Increment(ref _orderSequence);
        activity?.SetTag("order.id", orderId);

        return new
        {
            OrderId = orderId,
            ProductId = productId,
            Quantity = quantity,
            SessionId = sessionId,
            Status = "Created",
            CreatedAt = DateTime.UtcNow
        };
    }
}
