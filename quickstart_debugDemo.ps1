#Run this script to update your container apps. Assuming steps in README are followed so:
# 1) Storage and Service bus dependencies, App Insights and Log Analytics workspaces are created.
# 2) dapr component files are configured

#Switch parameter
Param(
    [switch]$noAzureLogin,
    [switch]$noDockerLogin,
    [switch]$noDockerBuildWeb,
    [switch]$noDockerBuildProcessor
)

#Environment variables
$SUBSCRIPTION_ID=""
$DOCKERHUB_USERNAME=""
$RESOURCE_GROUP=""
$LOCATION=""
$CONTAINERAPPS_ENVIRONMENT=""
$DAPR_INSTRUMENTATION_KEY=""
$LOGANALYTICS_WORKSPACE_ID=""
$LOGS_WORKSPACE_KEY=""
$APPLICATIONINSIGHTS_CONNECTION_STRING=""
$ORDER_PROCESSOR_HTTP_URL=""

#Login to Docker for publishing images
if(!$noDockerLogin)
{
    docker login
}

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
    docker build -t $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights-debug -f ./PizzaOrderProcessor/Dockerfile .
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
    az containerapp create --name order-processor-http --resource-group $RESOURCE_GROUP --yaml app_test_local.yaml

}
else
{
    if(!$noDockerBuildProcessor)
    {
        $revisionSuffix = $((get-date).toString("yyyy-mm-dd-hhmmss"))
        Write-output "Creating containerapp order-processor-http revision with suffix $revisionSuffix"
        #az containerapp update --name order-processor-http --resource-group $RESOURCE_GROUP --image $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights-debug:latest --revision-suffix $revisionSuffix
        az containerapp update --name order-processor-http --resource-group $RESOURCE_GROUP --revision-suffix $revisionSuffix --yaml app_test_local.yaml
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