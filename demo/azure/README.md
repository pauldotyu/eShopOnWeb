# Deploying Azure Resources

Run the deployment script

```bash
cd /demo/azure
./deploy.sh
```

> It takes about 30+ minutes for the resources to deploy

Setup the GitHub repo for workflow runs

```bash
# get repo name
REPO=pauldotyu/eShopOnWeb
BRANCH=main

# set app name
APP_NAME=<YOUR_APP_REGISTRATION_NAME>

# create app registration and service principal
APP_OBJECT_ID=$(az ad app create --display-name ${APP_NAME} --query id -o tsv)
USER_OBJECT_ID=$(az ad sp create --id $APP_OBJECT_ID --query id -o tsv)

# assign role to service principal
az role assignment create --role "Owner" --assignee-object-id $USER_OBJECT_ID

# create the federated credential for the app registration
az ad app federated-credential create \
   --id $APP_OBJECT_ID \
   --parameters "{\"name\":\"${APP_NAME}\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:${REPO}:ref:refs/heads/${BRANCH}\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

# get resource group name
RG_NAME=<YOUR_RESOURCE_GROUP_NAME>

# get aks name
AKS_NAME=$(az resource list \
  --resource-group $RG_NAME \
  --resource-type Microsoft.ContainerService/ManagedClusters \
  --query "[0].name" -o tsv)

# get acr name
ACR_NAME=$(az resource list \
  --resource-group $RG_NAME \
  --resource-type Microsoft.ContainerRegistry/registries \
  --query "[0].name" -o tsv)

# set the default repo to be your fork
gh repo set-default

# set gh recrets
gh secret set AZURE_CLIENT_ID --body "$(az ad app show --id $APP_OBJECT_ID --query appId -o tsv)" --repo $REPO
gh secret set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)" --repo $REPO
gh secret set AZURE_SUBSCRIPTION_ID --body "$(az account show --query id -o tsv)" --repo $REPO
gh secret set AZURE_USER_OBJECT_ID --body "${USER_OBJECT_ID}" --repo $REPO
gh secret set ACR_NAME --body $ACR_NAME --repo $REPO
gh secret set AKS_NAME --body $AKS_NAME --repo $REPO
gh secret set RG_NAME --body $RG_NAME --repo $REPO
```

Build an .env file and upload as a GitHub secret. This will be used to load as configmap

```bash
# remove old .env file
rm .env

# create new .env file
touch .env

# add sql connection strings
echo "SQL_PASSWORD=@someThingComplicated1234" >> .env
echo "SQL_CONNECTION_CATALOG=Server=sqlserver,1433;Integrated Security=true;Database=Microsoft.eShopOnWeb.CatalogDb;User Id=sa;Password=@someThingComplicated1234;Trusted_Connection=false;TrustServerCertificate=True;" >> .env
echo "SQL_CONNECTION_IDENTITY=Server=sqlserver,1433;Integrated Security=true;Database=Microsoft.eShopOnWeb.Identity;User Id=sa;Password=@someThingComplicated1234;Trusted_Connection=false;TrustServerCertificate=True;" >> .env

# get azure app config connection string
AAC_NAME=$(az resource list \
  --resource-group $RG_NAME \
  --resource-type Microsoft.AppConfiguration/configurationStores \
  --query "[0].name" -o tsv)

AAC_CONN=$(az appconfig credential list \
  --resource-group $RG_NAME \
  --name $AAC_NAME \
  --query "[0].connectionString" \
  --output tsv)

echo "APP_CONFIG_CONNECTION=$AAC_CONN" >> .env

# get azure open ai connection info
AOAI_NAME=$(az resource list \
  --resource-group $RG_NAME \
  --resource-type Microsoft.CognitiveServices/accounts \
  --query "[0].name" -o tsv)

AOAI_ENDPOINT=$(az cognitiveservices account show \
  --name $AOAI_NAME \
  --resource-group $RG_NAME \
  --query properties.endpoint \
  --output tsv)

AOAI_KEY=$(az cognitiveservices account keys list \
  --name $AOAI_NAME \
  --resource-group $RG_NAME \
  --query key1 \
  --output tsv)

echo "AOAI_ENDPOINT=$AOAI_ENDPOINT" >> .env
echo "AOAI_KEY=$AOAI_KEY" >> .env
echo "AOAI_CHATCOMPLETION_MODEL_ALIAS=chatgpt-azure" >> .env
echo "AOAI_CHATCOMPLETION_MODEL_DEPLOYMENT=gpt-35-turbo" >> .env
echo "AOAI_EMBEDDING_MODEL_ALIAS=ada-azure" >> .env
echo "AOAI_EMBEDDING_MODEL_DEPLOYMENT=text-embedding-ada-002" >> .env
echo "AOAI_TEXTCOMPLETION_MODEL_ALIAS=davinci-azure" >> .env
echo "AOAI_TEXTCOMPLETION_MODEL_DEPLOYMENT=text-davinci-003" >> .env

INGRESS_IP=$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "CHAT_URL=http://$INGRESS_IP/shopassist" >> .env

# upload .env file as a secret
gh secret set ENV --repo $REPO < .env
```

Configure Istio on the AKS cluster

```bash
# get kubectl credentials
az aks get-credentials --name $AKS_NAME --resource-group $RG_NAME

# make sure you are in the k8s directory
cd ../k8s

# enable automatic sidecar injection
kubectl label namespace default istio.io/rev=asm-1-17

# deploy the prometheus configmap for istio
kubectl create configmap ama-metrics-prometheus-config --from-file=prometheus-config -n kube-system
```

Deploy app to Kubernetes

```bash
# deploy the sqlserver
kubectl apply -f sqlserver.yaml

# get acr server
ACR_SERVER=$(az acr show \
  --name $ACR_NAME \
  --resource-group $RG_NAME \
  --query loginServer \
  --output tsv)

# build images (make sure you are in the root of the repo)
PUBLICAPI_VERSION=<YOUR_VERSION_NUMBER>
WEB_VERSION=<YOUR_VERSION_NUMBER>
CHATAPI_VERSION=<YOUR_VERSION_NUMBER>

kustomize edit set image publicapi=$ACR_SERVER/eshop/publicapi:$PUBLICAPI_VERSION
kustomize edit set image web=$ACR_SERVER/eshop/web:$WEB_VERSION
kustomize edit set image chatapi=$ACR_SERVER/eshop/chatapi:$CHATAPI_VERSION
kustomize build . | k apply -f -
```

Test the ChatApi

```bash
curl -v http://$INGRESS_IP/shopassist -H "Content-Type: application/json" -d '{"text": "hello"}'
```

Enable the Chat Feature on Web

```bash
az appconfig feature enable -n $AAC_NAME --feature Chat -y

# restart web for the change to take effect
kubectl rollout restart deploy web
```

Disable the Chat Feature on Web

```bash
az appconfig feature disable -n $AAC_NAME --feature Chat -y

# restart web for the change to take effect
kubectl rollout restart deploy web
```

Send a consistent stream of requests to the ChatApi

```bash
while true; do curl -s http://$INGRESS_IP/shopassist -H "Content-Type: application/json" -d '{"text": "hello"}'; echo; sleep 1; done
```
