using Microsoft.AspNetCore.Mvc;

using PizzaOrderProcessor1.models;
using PizzaOrderProcessor1.Services;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace PizzaOrderProcessor1.Controllers
{
    [ApiController]
    public class PizzaOrderController : ControllerBase
    {
        private string DAPR_HOST = Environment.GetEnvironmentVariable("DAPR_HOST") ?? "http://localhost";
        private string DAPR_HTTP_PORT = Environment.GetEnvironmentVariable("DAPR_HTTP_PORT") ?? "3600";
        private string STATESTORENAME = Environment.GetEnvironmentVariable("STATESTORENAME") ?? "statestore";
        private string PUBSUBNAME = Environment.GetEnvironmentVariable("PUBSUBNAME") ?? "pubsub";
        private string TOPICNAME = Environment.GetEnvironmentVariable("TOPICNAME") ?? "order";

        Dictionary<string, Order> pizzamemcache = new Dictionary<string, Order>();
        object cacheWriteLock = new object();
        object cacheReadLock = new object();

        private readonly ILogger<PizzaOrderController> _logger;
        private readonly AzureStorageService _azureStorageService;

        public PizzaOrderController(AzureStorageService azureStorageService, ILogger<PizzaOrderController> logger)
        {
            _logger = logger;
            _azureStorageService = azureStorageService;
        }

        // Register Dapr pub/sub subscriptions
        [HttpGet("/dapr/subscribe")]
        public IEnumerable<DaprSubscription> SubscribeDapr()
        {
            var sub = new DaprSubscription($"{PUBSUBNAME}", $"{TOPICNAME}", "order");
            _logger.LogDebug("Dapr pub/sub is subscribed to: " + sub);

            return new DaprSubscription[] { sub };
        }

        // Get order by orderId
        [HttpGet("/order")]
        public Order GetOrderByOrderId(string orderId)
        {
            var order = new Order();

            if (!pizzamemcache.TryGetValue(orderId, out order))
            {
                // fetch order from storage state store by orderId
                var resp = _azureStorageService.GetOrderById(orderId).Result;
                _logger.LogDebug("Println resp");
                _logger.LogDebug(resp);
                order = JsonSerializer.Deserialize<Order>(resp)!;
                lock (cacheWriteLock)
                {
                    lock (cacheReadLock)
                    {
                        var ordertmp = new Order();

                        if (!pizzamemcache.TryGetValue(orderId, out ordertmp))
                        {
                            pizzamemcache.Add(orderId, order);
                            var timeStamp = DateTime.Now.ToString();
                            pizzamemcache.Add(orderId + timeStamp, order);
                        }
                    }

                }
            }

            return order;
        }

        // Update order status by orderId
        [HttpPost("/order/status")]
        public Order UpdateOrderStatusByOrderId(DaprData<OrderStatus> requestData)
        {
            var orderStatus = requestData.Data;
            var order = new Order();

            lock (cacheReadLock)
            {
                if (!pizzamemcache.TryGetValue(orderStatus.OrderId.ToString(), out order))
                {
                    // fetch order from storage state store by orderId
                    var resp = _azureStorageService.GetOrderById(orderStatus.OrderId.ToString());
                    order = JsonSerializer.Deserialize<Order>(resp.Result)!;
                    lock (cacheWriteLock)
                    {
                        pizzamemcache.Remove(orderStatus.OrderId.ToString());
                        pizzamemcache.Add(orderStatus.OrderId.ToString(), order);
                    }
                }
                // update order status
                order.Status = orderStatus.Status;
                lock (cacheWriteLock)
                {
                    pizzamemcache.Remove(orderStatus.OrderId.ToString());
                    pizzamemcache.Add(orderStatus.OrderId.ToString(), order);
                }
            }

            // post the updated order to storage state store
            var orderInfoJson = JsonSerializer.Serialize(
                new[] {
                    new { key = order.OrderId.ToString(),value = order }
                    }
            );

            var state = new StringContent(orderInfoJson, Encoding.UTF8, "application/json");
            bool result = _azureStorageService.UpdateStatusByOrderId(state).Result;

            return order;
        }

        // Post order
        [HttpPost("/order")]
        public IResult PostOrder(DaprData<Order> requestData)
        {
            var order = requestData.Data;
            order.Status ??= "Created";
            // write the order information into state store
            var orderInfoJson = JsonSerializer.Serialize(
                new[] {
            new {
                key = order.OrderId.ToString(),
                value = order
            }
                }
            );
            // write into cosmosdb
            var state = new StringContent(orderInfoJson, Encoding.UTF8, "application/json");
            bool result = _azureStorageService.UpdateStatusByOrderId(state).Result;


            _logger.LogDebug("Saving Order: " + order);
            _logger.LogDebug("order-processor-http app read and processed queue message: orderId=" + order.OrderId.ToString());
            lock (cacheWriteLock)
            {
                var orderTmp = new Order();
                if (pizzamemcache.TryGetValue(order.OrderId.ToString(), out orderTmp))
                {
                    pizzamemcache.Remove(order.OrderId.ToString());
                }
                pizzamemcache.Add(order.OrderId.ToString(), order);
            }

            return Results.Ok();
        }

    }

    public record DaprData<T>([property: JsonPropertyName("data")] T Data);
}