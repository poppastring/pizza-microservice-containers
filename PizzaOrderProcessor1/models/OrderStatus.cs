using System.Text.Json.Serialization;

namespace PizzaOrderProcessor1.models;

public class OrderStatus {
    [property: JsonPropertyName("orderId")] public int OrderId { get; set; }
    [property: JsonPropertyName("status")] public  string? Status{ get; set; } 
}