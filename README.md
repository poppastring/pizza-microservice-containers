# Pizza Order App Demo

This demo is a containerized microservice application consisting of a Node.js web app taking Pizza orders from customers, and an .NET 6 backend for dispatching the order to be made and for getting order status upon customer inqueries. The instruction is for testing locally and deploying to Azure Container Apps platform. This tutorial was created on Windows 11. The command line deployment scripts may vary on different platforms.
* [Demo Walkthrough](#demo-walkthrough)
* [Pre-requisites](#pre-requisites)
* [Test locally](#test-locally)
* [Deploy to Azure](#deploy-to-azure)

## Demo Walkthrough
The Pizza Order App demo has the following features:
* Browse pizza options on homepage 
* Add pizzas to cart on homepage
* Edit shopping cart
* Submit order
* Check oder status by order ID

**1. Browse pizza options and add to cart on the homepage**
![Homepage](./images/PizzaHome.png)

**2. Add pizzas to cart on homepage**
![Add Pizza to Cart](./images/AddPizzaToCart.png)

**3. Edit shopping cart**
![Edit cart](./images/EditCart.png)

**4. Submit Order**
![Submit order](./images/SubmitOrder.png)

**5. Check oder status by order ID**
![Check order status](./images/CheckOrderStatus.png)
![Order Status displayed](./images/OrderStatusDisplayed.png)

## Pre requisites
* Install [Docker](https://docs.docker.com/engine/install/)
* Install [Dapr CLI](https://docs.dapr.io/getting-started/install-dapr-cli/)
* Install [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
* Install [Node.js](https://nodejs.org/download/)
* Install [.NET 6](https://dotnet.microsoft.com/download/dotnet/6.0)
* Have a working Azure subscription
* Create dependencies resources used in the app (Azure Service Bus, Storage Account, Log Analytics and App Insights) by edit and run [create-dependencyResources.ps1](./create-dependencyResources.ps1)
**NOTE: there is a limitation on the script for creating Storage Container. Workaround is manually create the Container in Azure portal**

## Test Locally
Download this repository to test the code locally.
### Edit Dapr component files
In */components* directory there are two Dapr component files:
* pubsub.yaml
* statestore.yaml

Make a copy of the /components folder, name it *components_local* and put your Azure service bus connection string in pubsub.yaml and Azure Storage blob info in statestore.yaml. *components_local* is ignored by this repo so you won't check in your resource keys.

### Start Dapr process
```
dapr init
```

### Run PizzaWeb
Change project to the *PizzaWeb* directory. 

Set App Insights connection string environment vairable:
```
set APPLICATIONINSIGHTS_CONNECTION_STRING="your_appinsights_connectionstring"
```

Initialize the project:
```
npm install
```
Run the service with Dapr side car process:

Run the following command under the dir *pizza-microservice-containers/PizzaWeb*
```
dapr run --dapr-http-port 3500 --app-id order-web --components-path ../components_local/ --app-port 3001 -- npm run debug
```

Web application's entry point is : http://localhost:3000/ 

## PizzaOrderProcessor
Change project to the *PizzaOrderProcessor* directory.

Set App Insights connection string environment vairable:
```
set APPLICATIONINSIGHTS_CONNECTION_STRING="your_appinsights_connectionstring"
```

Initialize the project:
```
dotnet restore
dotnet build
```
Run the service with Dapr side car process:
```
dapr run --dapr-http-port 3600 --app-id order-processor-http --components-path ../components_local/ --app-port 3001 -- dotnet run --project .
```
The Pizza Demo App should be running locally now. Test by creating orders and checking for order status. 

## Deploy To Azure
In */aca-dapr-components* directory there are two Dapr component files:
* pubsub.yaml
* statestore.yaml

Make a copy of /aca-dapr-components folder and call it *aca-dapr-components_$yourResourceGroup*, replace the variable with the resource group name you will use or create. This ensures the quickstart.ps1 script an execute smoothly and the folder won't be checked in to protect resource secret keys. Put your Azure Service Bus connection string in pubsub.yaml and Azure Storage blob container info in statestore.yaml.

Edit and run [quickstart.ps1](./quickstart.ps1)