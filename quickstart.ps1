#Run this script to update your container apps. Assuming steps in README are followed so:
# 1) Storage and Service bus dependencies, App Insights and Log Analytics workspaces are created.
# 2) dapr component files are configured

#Switch parameter
Param(
    [switch]$noAzureLogin,
    [switch]$noDockerBuild
)

#Environment variables
$SUBSCRIPTION_ID="9de7ded6-0ad3-43e6-87b8-17d93e3ff695"
$DOCKERHUB_USERNAME="cathyxwang"
$RESOURCE_GROUP="PizzaOrderDemo2"
$LOCATION="westus"
$CONTAINERAPPS_ENVIRONMENT="pizzaorderdemo2"
$LOGANALYTICS_WORKSPACE_ID="cf856dd7-a3b2-465b-8536-50b5ca48ae06"
$APPLICATIONINSIGHTS_CONNECTION_STRING=""

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
if(!$noDockerBuild)
{
    docker build -t $DOCKERHUB_USERNAME/node-pizza-web-appinsights ./PizzaWeb/.
    docker push $DOCKERHUB_USERNAME/node-pizza-web-appinsights

    docker build -t $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights ./PizzaOrderProcessor/.
    docker push $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights
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
    az containerapp env create --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --location $LOCATION --logs-workspace-id $LOGANALYTICS_WORKSPACE_ID
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
    az containerapp env dapr-component set --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --dapr-component-name pubsub --yaml ./aca-dapr-components_local/pubsub.yaml
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
    az containerapp env dapr-component set --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --dapr-component-name statestore --yaml ./aca-dapr-components_local/statestore.yaml
}
else
{
    Write-Output "Dapr component statestore exists already, skip creation"
}

#Deploy container app revisions
$pizzaprocessingCheck = az containerapp list --environment pizzaorderdemo2 --resource-group pizzaorderdemo2 --query "[?name=='order-processor-http']" | ConvertFrom-Json
$pizzaprocessingExists = $pizzaprocessingCheck.Length -gt 0
if(!$pizzaprocessingExists)
{
    Write-Output "Creating containerapp order-web ..."
    az containerapp create --name order-processor-http --resource-group $RESOURCE_GROUP --environment $CONTAINERAPPS_ENVIRONMENT --image $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights:latest --target-port 80 --ingress external --min-replicas 1 --max-replicas 1 --enable-dapr --dapr-app-id order-processor-http --dapr-app-port 80 --env-vars `APPLICATIONINSIGHTS_CONNECTION_STRING=$APPLICATIONINSIGHTS_CONNECTION_STRING`
}
else
{
    if(!$noDockerBuild)
    {
        $revisionSuffix = $((get-date).toString("yyyy-mm-dd-hhmmss"))
        Write-output "Creating containerapp order-web revision with suffix $revisionSuffix"
        az containerapp update --name order-processor-http --resource-group $RESOURCE_GROUP --image $DOCKERHUB_USERNAME/dotnet-pizza-backend-appinsights:latest --revision-suffix $revisionSuffix
    }
    else
    {
        Write-Output "order-processor-http exists. No container image update. Skip creation or update"
    }
     
}

#Deploy container app revisions
$pizzawebCheck = az containerapp list --environment pizzaorderdemo2 --resource-group pizzaorderdemo2 --query "[?name=='order-web']" | ConvertFrom-Json
$pizzawebExists = $pizzawebCheck.Length -gt 0
if(!$pizzawebExists)
{
    Write-Output "Creating containerapp order-web ..."
    az containerapp create --name order-web --resource-group $RESOURCE_GROUP --environment $CONTAINERAPPS_ENVIRONMENT  --image $DOCKERHUB_USERNAME/node-pizza-web-appinsights:latest --target-port 3000 --ingress external --min-replicas 1 --max-replicas 1 --enable-dapr --dapr-app-id order-web --dapr-app-port 3000 --env-vars `APPLICATIONINSIGHTS_CONNECTION_STRING=$APPLICATIONINSIGHTS_CONNECTION_STRING`
}
else
{
    if(!$noDockerBuild)
    {
        $revisionSuffix = $((get-date).toString("yyyy-mm-dd-hhmmss"))
        Write-output "Creating containerapp order-web revision with suffix $revisionSuffix"
        az containerapp update --name order-web --resource-group $RESOURCE_GROUP --image $DOCKERHUB_USERNAME/node-pizza-web-appinsights:latest --revision-suffix $revisionSuffix
    }
    else
    {
        Write-Output "order-web exists. No container image update. Skip creation or update"
    }
     
}