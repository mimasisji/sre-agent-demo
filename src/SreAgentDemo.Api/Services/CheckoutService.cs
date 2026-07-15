using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace SreAgentDemo.Api.Services;

public class CheckoutService
{
    private static readonly ActivitySource _activitySource = new("SreAgentDemo.Api");
    private static readonly Meter _meter = new("SreAgentDemo.Api");
    private static readonly Histogram<double> _checkoutDuration = _meter.CreateHistogram<double>("checkout.duration", "ms", "End-to-end checkout duration");

    private readonly ProductService _products;
    private readonly OrderService _orders;

    public CheckoutService(ProductService products, OrderService orders)
    {
        _products = products;
        _orders = orders;
    }

    public async Task<object> ProcessCheckoutAsync(int productId, int quantity, string sessionId, CancellationToken ct = default)
    {
        using var activity = _activitySource.StartActivity("CheckoutService.ProcessCheckout", ActivityKind.Internal);
        activity?.SetTag("checkout.product_id", productId);
        activity?.SetTag("checkout.quantity", quantity);
        activity?.SetTag("checkout.session_id", sessionId);

        var sw = Stopwatch.StartNew();

        // Step 1: Validate product exists
        var catalog = await _products.GetProductsAsync(ct);
        var product = catalog.FirstOrDefault(p =>
            (int)(((dynamic)p).Id) == productId);

        if (product is null)
        {
            activity?.SetStatus(ActivityStatusCode.Error, "Product not found");
            throw new ArgumentException($"Product {productId} not found");
        }

        // Step 2: Create order
        var order = await _orders.CreateOrderAsync(productId, quantity, sessionId, ct);

        _checkoutDuration.Record(sw.ElapsedMilliseconds, new("status", "success"));
        activity?.SetStatus(ActivityStatusCode.Ok);

        return new
        {
            Success = true,
            Order = order,
            Product = product,
            TotalMs = sw.ElapsedMilliseconds
        };
    }
}
