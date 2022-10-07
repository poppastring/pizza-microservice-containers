using System.Text.Json.Serialization;

namespace PizzaOrderProcessor1.models;

public class DaprSubscription {
    [property: JsonPropertyName("pubsubname")] public string PubsubName { get; set; } 
    [property: JsonPropertyName("topic")] public string Topic { get; set; } 
    [property: JsonPropertyName("route")] public string Route { get; set; }

    public DaprSubscription(string pubsubName, string topic, string route) {
        this.PubsubName = pubsubName;
        this.Topic = topic;
        this.Route = route;
    }
}