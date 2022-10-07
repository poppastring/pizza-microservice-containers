using System.Text.Json.Serialization;

namespace PizzaOrderProcessor1.models;

public class Pizza {
    [property: JsonPropertyName("name")] public string? Name{ get; set; }
    [property: JsonPropertyName("price")] public float? Price{ get; set; }
    [property: JsonPropertyName("count")] public int? Count{ get; set; }
}