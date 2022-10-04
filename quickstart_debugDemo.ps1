#Run this script to update your container apps. Assuming steps in README are followed so:
# 1) Storage and Service bus dependencies, App Insights and Log Analytics workspaces are created.
# 2) dapr component files are configured

#Switch parameter
Param(
    [switch]$noAzureLogin,
    [switch]$noDockerBuildWeb,
    [switch]$noDockerBuildProcessor
)

#Environment variables
$SUBSCRIPTION_ID="9de7ded6-0ad3-43e6-87b8-17d93e3ff695"
$DOCKERHUB_USERNAME="cathyxwang"
$RESOURCE_GROUP="PizzaOrderDemo3"
$LOCATION="centralus"
$CONTAINERAPPS_ENVIRONMENT="pizzaorderdemo3"
$DAPR_INSTRUMENTATION_KEY="39f6f103-a3c2-4d38-a24e-3468da850aba"
$LOGANALYTICS_WORKSPACE_ID="64d04329-08b5-4a54-b837-16ce633091ab"
$LOGS_WORKSPACE_KEY="6U0XEefXN1DqGTMhOELM7BHG/4C6+cUC1LOByaq5Zg50ZgJBMECp/41zxs3PN3o183Gk26FnzfkntWRT8gmF0w=="
$APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=39f6f103-a3c2-4d38-a24e-3468da850aba;IngestionEndpoint=https://centralus-2.in.applicationinsights.azure.com/;LiveEndpoint=https://centralus.livediagnostics.monitor.azure.com/"
$ORDER_PROCESSOR_HTTP_URL=""

#Connnect to an Azure subscription
if(!$noAzureLogin)
{
    az login
}

az account set --s $SUBSCRIPTION_ID
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights

#Build docker images
if(!$noDockerBuildWeb)
{
    docker build -t $DOCKERHUB_USERNAME/node-pizza-web-appinsights-debug ./PizzaWeb/.
    docker push $DOCKERHUB_USERNAME/node-pizza-web-appinsights-debug
}

if(!$noDockerBuildProcessor)
{
    docker build -t $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights-debug ./PizzaOrderProcessor/.
    docker push $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights-debug
}




#Create resource group if doesn't exist
$rgCheck = az group exists --name $RESOURCE_GROUP
if (!$rgCheck)
{
    Write-Output "Creating resource group $RESOURCE_GROUP ..."
    az group create --name $RESOURCE_GROUP --location $LOCATION
}
else
{
    Write-Output "$RESOURCE_GROUP exists, skip creation"
}



#Create Container App Env if doesn't exist
$envCheck = az containerapp env list --query "[?name=='$CONTAINERAPPS_ENVIRONMENT']" | ConvertFrom-Json
$envExists = $envCheck.Length -gt 0
if (!$envExists)
{
    Write-Output "Creating Container App Environment $CONTAINERAPPS_ENVIRONMENT ..."
    az containerapp env create --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --location $LOCATION --dapr-instrumentation-key $DAPR_INSTRUMENTATION_KEY --logs-workspace-id $LOGANALYTICS_WORKSPACE_ID --logs-workspace-key $LOGS_WORKSPACE_KEY
}
else
{
    Write-Output "$CONTAINERAPPS_ENVIRONMENT exists, skip creation"
}



#Deploy dapr components
$pubsubCheck = az containerapp env dapr-component list --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --query "[?name=='pubsub']" | ConvertFrom-Json
$pubsubExists = $pubsubCheck.Length -gt 0
if (!$pubsubExists)
{
    Write-Output "Creating Dapr component pubsub ..."
    az containerapp env dapr-component set --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --dapr-component-name pubsub --yaml ./aca-dapr-components_PizzaOrderDemo3/pubsub.yaml
}
else
{
    Write-Output "Dapr component pubsub exists already, skip creation"
}
    


$statestoreCheck = az containerapp env dapr-component list --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --query "[?name=='statestore']" | ConvertFrom-Json
$statestoreExists = $statestoreCheck.Length -gt 0
if (!$statestoreExists)
{
    Write-Output "Creating Dapr component statestore ..."
    az containerapp env dapr-component set --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --dapr-component-name statestore --yaml ./aca-dapr-components_PizzaOrderDemo3/statestore.yaml
}
else
{
    Write-Output "Dapr component statestore exists already, skip creation"
}

#Deploy container app revisions
$pizzaprocessingCheck = az containerapp list --environment $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --query "[?name=='order-processor-http']" | ConvertFrom-Json
$pizzaprocessingExists = $pizzaprocessingCheck.Length -gt 0
if(!$pizzaprocessingExists)
{
    Write-Output "Creating containerapp order-processor-http ..."
    az containerapp create --name order-processor-http --resource-group $RESOURCE_GROUP --yaml app.yaml

}
else
{
    if(!$noDockerBuildProcessor)
    {
        $revisionSuffix = $((get-date).toString("yyyy-mm-dd-hhmmss"))
        Write-output "Creating containerapp order-processor-http revision with suffix $revisionSuffix"
        az containerapp update --name order-processor-http --resource-group $RESOURCE_GROUP --image $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights-debug:latest --revision-suffix $revisionSuffix
    }
    else
    {
        Write-Output "order-processor-http exists. No container image update. Skip creation or update"
    }
     
}

$pizzaprocessingCheck = az containerapp list --environment $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --query "[?name=='order-processor-http']" | ConvertFrom-Json
$ORDER_PROCESSOR_HTTP_URL=$pizzaprocessingCheck.properties.Configuration.Ingress.fqdn
#Deploy container app revisions
$pizzawebCheck = az containerapp list --environment $CONTAINERAPPS_ENVIRONMENT  --resource-group $RESOURCE_GROUP --query "[?name=='order-web']" | ConvertFrom-Json
$pizzawebExists = $pizzawebCheck.Length -gt 0
if(!$pizzawebExists)
{
    Write-Output "Creating containerapp order-web ..."
    az containerapp create --name order-web --resource-group $RESOURCE_GROUP --environment $CONTAINERAPPS_ENVIRONMENT  --image $DOCKERHUB_USERNAME/node-pizza-web-appinsights-debug:latest --target-port 3000 --ingress external --min-replicas 1 --max-replicas 1 --enable-dapr --dapr-app-id order-web --dapr-app-port 3000 --env-vars `APPLICATIONINSIGHTS_CONNECTION_STRING=$APPLICATIONINSIGHTS_CONNECTION_STRING ORDER_PROCESSOR_HTTP_URL=$ORDER_PROCESSOR_HTTP_URL`
}
else
{
    if(!$noDockerBuildWeb)
    {
        $revisionSuffix = $((get-date).toString("yyyy-mm-dd-hhmmss"))
        Write-output "Creating containerapp order-web revision with suffix $revisionSuffix"
        az containerapp update --name order-web --resource-group $RESOURCE_GROUP --image $DOCKERHUB_USERNAME/node-pizza-web-appinsights-debug:latest --revision-suffix $revisionSuffix --set-env-vars `ORDER_PROCESSOR_HTTP_URL=$ORDER_PROCESSOR_HTTP_URL`
    }
    else
    {
        Write-Output "order-web exists. No container image update. Skip creation or update"
    }
     
}