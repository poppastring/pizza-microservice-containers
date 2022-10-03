using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Core;
using PizzaOrderProcessor.models;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddApplicationInsightsTelemetry();
builder.Services.AddServiceProfiler();

var app = builder.Build();

string DAPR_HOST = Environment.GetEnvironmentVariable("DAPR_HOST") ?? "http://localhost";
string DAPR_HTTP_PORT = Environment.GetEnvironmentVariable("DAPR_HTTP_PORT") ?? "3600";
string STATESTORENAME = Environment.GetEnvironmentVariable("STATESTORENAME") ?? "statestore";
string PUBSUBNAME = Environment.GetEnvironmentVariable("PUBSUBNAME") ?? "pubsub";
string TOPICNAME = Environment.GetEnvironmentVariable("TOPICNAME") ?? "order";
string stateStoreBaseUrl = $"{DAPR_HOST}:{DAPR_HTTP_PORT}/v1.0/state/{STATESTORENAME}";
var httpClient = new HttpClient();
httpClient.DefaultRequestHeaders.Accept.Add(new System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/json"));

if (app.Environment.IsDevelopment()) {app.UseDeveloperExceptionPage();}

// Register Dapr pub/sub subscriptions
app.MapGet("/dapr/subscribe", () => {
    var sub = new DaprSubscription($"{PUBSUBNAME}", $"{TOPICNAME}", "order");
    Console.WriteLine("Dapr pub/sub is subscribed to: " + sub);
    return Results.Json(new DaprSubscription[]{sub});
});

// Get order by orderId
app.MapGet("/order", (string orderId) => {
    // fetch order from storage state store by orderId
    Console.WriteLine("Web URL in /order/{orderId}: "+ $"{stateStoreBaseUrl}/{orderId}");
    var resp = httpClient.GetStringAsync($"{stateStoreBaseUrl}/{orderId}");
    Console.WriteLine("Println resp");
    Console.WriteLine(resp.Result);
    var order = JsonSerializer.Deserialize<Order>(resp.Result)!;
    return Results.Ok(order);
});

// Update order status by orderId
app.MapPost("/order/status", async (DaprData<OrderStatus> requestData) => {
    var orderStatus = requestData.Data;
    // fetch order from storage state store by orderId
    var orderLock = new object();
    var order = new Order();


        var respStr = httpClient.GetStringAsync($"{stateStoreBaseUrl}/{orderStatus.OrderId.ToString()}");
        var resp = await respStr;
        order = JsonSerializer.Deserialize<Order>(resp)!;

        // update order status
        
        order.Status = orderStatus.Status;


    // post the updated order to storage state store

    var orderInfoJson = JsonSerializer.Serialize(
        new[] {
            new {
                key = order.OrderId.ToString(),
                value = order
            }
        }
    );

    var state = new StringContent(orderInfoJson, Encoding.UTF8, "application/json");

    await httpClient.PostAsync(stateStoreBaseUrl, state);

 
    return Results.Ok(order);
});

// Post order
app.MapPost("/order", (DaprData<Order> requestData) => {
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
    httpClient.PostAsync(stateStoreBaseUrl, state);
    Console.WriteLine("Saving Order: " + order);
    
    return Results.Ok();
});

await app.RunAsync();

public record DaprData<T> ([property: JsonPropertyName("data")] T Data);