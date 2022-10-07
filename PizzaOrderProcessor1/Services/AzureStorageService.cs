namespace PizzaOrderProcessor1.Services
{
    public class AzureStorageService
    {
        private static string DAPR_HOST = Environment.GetEnvironmentVariable("DAPR_HOST") ?? "http://localhost";
        private static string DAPR_HTTP_PORT = Environment.GetEnvironmentVariable("DAPR_HTTP_PORT") ?? "3600";
        private static string STATESTORENAME = Environment.GetEnvironmentVariable("STATESTORENAME") ?? "statestore";
        private static string PUBSUBNAME = Environment.GetEnvironmentVariable("PUBSUBNAME") ?? "pubsub";
        private static string TOPICNAME = Environment.GetEnvironmentVariable("TOPICNAME") ?? "order";
        private static string stateStoreBaseUrl = $"{DAPR_HOST}:{DAPR_HTTP_PORT}/v1.0/state/{STATESTORENAME}";
        private readonly ILogger<AzureStorageService> _logger;
        HttpClient httpClient = new HttpClient();

        public AzureStorageService(ILogger<AzureStorageService> logger)
        {
            _logger = logger;
            httpClient.DefaultRequestHeaders.Accept.Add(new System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/json"));
        }
        public async Task<string> GetOrderById(string orderId)
        {
            _logger.LogDebug("Web URL in /order/{orderId}: " + $"{stateStoreBaseUrl}/{orderId}");
            return httpClient.GetStringAsync($"{stateStoreBaseUrl}/{orderId.ToString()}").Result;
        }

        public async Task<string> GetStatusByOrderId(string orderId)
        {
            return httpClient.GetStringAsync($"{stateStoreBaseUrl}/{orderId.ToString()}").Result;
        }

        public async Task<bool> UpdateStatusByOrderId(StringContent state)
        {
            bool result = false;
            var status = httpClient.PostAsync(stateStoreBaseUrl, state).Result;

            if (status?.StatusCode == System.Net.HttpStatusCode.OK)
            {
                result = true;
            }

            return result;
        }

        private async Task<string> GetConfigData()
        {
            var random = new Random();

            await Task.Delay(random.Next(3) * 1000);

            return Guid.NewGuid().ToString();
        }
    }
}
