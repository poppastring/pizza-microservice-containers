using System.Text.Json.Serialization;

namespace PizzaOrderProcessor1.models;

public class Order {
    [property: JsonPropertyName("orderId")] public int OrderId { get; set; }
    [property: JsonPropertyName("cart")] public  List<Pizza>? Cart{ get; set; } 
    [property: JsonPropertyName("status")] public  string? Status{ get; set; } 
}