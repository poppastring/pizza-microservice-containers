#Switch parameter
Param(
    [switch]$noAzureLogin,
    [switch]$createFailure,
    [switch]$fixFailure
)

$CONTAINERAPPS_ENVIRONMENT
$RESOURCE_GROUP

if(!$noAzureLogin)
{
    az login
}

az account set --s $SUBSCRIPTION_ID
az extension add --name containerapp --upgrade

Write-Output "pass -createFailure or -fixFailure to start"
if($createFailure)
{
    $revisionSuffix = $((get-date).toString("yyyy-mm-dd-hhmmss"))
    Write-Output "Creating failrue by changing ORDER_PROCESSOR_HTTP_URL"
    #az containerapp update --name order-web --resource-group $RESOURCE_GROUP --image $DOCKERHUB_USERNAME/node-pizza-web-appinsights-debug:latest --revision-suffix $revisionSuffix --set-env-vars `ORDER_PROCESSOR_HTTP_URL=$ORDER_PROCESSOR_HTTP_URL`
    az containerapp update --name order-web --resource-group $RESOURCE_GROUP --revision-suffix $revisionSuffix --set-env-vars `ORDER_PROCESSOR_HTTP_URL="thisiswrongurl"`
}

if($fixFailure)
{
    $revisionSuffix = $((get-date).toString("yyyy-mm-dd-hhmmss"))
    Write-Output "Fixing failrue by resetting ORDER_PROCESSOR_HTTP_URL"
    $pizzaprocessingCheck = az containerapp list --environment $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --query "[?name=='order-processor-http']" | ConvertFrom-Json
    $ORDER_PROCESSOR_HTTP_URL=$pizzaprocessingCheck.properties.Configuration.Ingress.fqdn
    #az containerapp update --name order-web --resource-group $RESOURCE_GROUP --image $DOCKERHUB_USERNAME/node-pizza-web-appinsights-debug:latest --revision-suffix $revisionSuffix --set-env-vars `ORDER_PROCESSOR_HTTP_URL=$ORDER_PROCESSOR_HTTP_URL`
    az containerapp update --name order-web --resource-group $RESOURCE_GROUP --revision-suffix $revisionSuffix --set-env-vars `ORDER_PROCESSOR_HTTP_URL=$ORDER_PROCESSOR_HTTP_URL`
}
