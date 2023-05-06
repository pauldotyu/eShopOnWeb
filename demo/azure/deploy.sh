RAND=$RANDOM
LOCATION=eastus

# resource group
RG_NAME=$(az group create --name rg-build2023-$RAND --location $LOCATION --query name --output tsv)

# azure openai
AOAI_NAME=$(az cognitiveservices account create --name aoai-build2023-$RAND \
  --location $LOCATION \
  --resource-group $RG_NAME \
  --kind OpenAI \
  --sku S0 \
  --query name \
  --output tsv)

# azure openai models
az cognitiveservices account deployment create \
  --name $AOAI_NAME \
  --resource-group $RG_NAME \
  --deployment-name text-davinci-003 \
  --model-format OpenAI \
  --model-name text-davinci-003 \
  --model-version 1 \
  --scale-type Standard

az cognitiveservices account deployment create \
  --name $AOAI_NAME \
  --resource-group $RG_NAME \
  --deployment-name text-davinci-003 \
  --model-format OpenAI \
  --model-name text-davinci-003 \
  --model-version 1 \
  --scale-type Standard

az cognitiveservices account deployment create \
  --name $AOAI_NAME \
  --resource-group $RG_NAME \
  --deployment-name text-embedding-ada-002 \
  --model-format OpenAI \
  --model-name text-embedding-ada-002 \
  --model-version 2 \
  --scale-type Standard

az cognitiveservices account deployment create \
  --name $AOAI_NAME \
  --resource-group $RG_NAME \
  --deployment-name gpt-35-turbo \
  --model-format OpenAI \
  --model-name gpt-35-turbo \
  --model-version "0301" \
  --scale-type Standard

# azure container registry
ACR_NAME=$(az acr create --name acrbuild2023$RAND \
  --resource-group $RG_NAME \
  --sku Premium \
  --query name \
  --output tsv)

ACR_SERVER=$(az acr show --name acrbuild2023$RAND \
  --resource-group $RG_NAME \
  --query loginServer \
  --output tsv)

# azure managed grafana
AMG_ID=$(az grafana create \
  --name amg-build2023-$RAND \
  --resource-group $RG_NAME \
  --query id \
  --output tsv)

# azure monitor workspace
AMON_ID=$(az resource create \
  --resource-group $RG_NAME \
  --namespace microsoft.monitor \
  --resource-type accounts \
  --name amon-build2023-$RAND \
  --location $LOCATION \
  --properties {} \
  --query id \
  --output tsv)

# grant the current user access to the workspace
az role assignment create \
  --role "Monitoring Data Reader" \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope $AMON_ID

# azure kubernetes service
AKS_NAME=$(az aks create --name aks-build2023-$RAND \
  --resource-group $RG_NAME \
  --enable-addons azure-keyvault-secrets-provider,gitops \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-cluster-autoscaler \
  --enable-keda \
  --enable-asm \
  --min-count 3 \
  --max-count 20 \
  --node-vm-size Standard_D4s_v5 \
  --attach-acr $ACR_NAME \
  --query name \
  --output tsv)

# add prometheus and grafana to aks
az aks update --name $AKS_NAME \
  --resource-group $RG_NAME \
  --enable-azuremonitormetrics \
  --azure-monitor-workspace-resource-id $AMON_ID \
  --grafana-resource-id $AMG_ID

# enable istio external gateway
az aks mesh enable-ingress-gateway --resource-group $RG_NAME --name $AKS_NAME --ingress-gateway-type external

# enable istio internal gateway
az aks mesh enable-ingress-gateway --resource-group $RG_NAME --name $AKS_NAME --ingress-gateway-type internal

# import grafana dashboards
AMG_NAME=$(az resource list \
  --resource-group $RG_NAME \
  --resource-type microsoft.dashboard/grafana \
  --query "[0].name" -o tsv)

az grafana folder create \
  --name $AMG_NAME \
  --resource-group $RG_NAME \
  --title "Istio"

# Istio workload dashboard
az grafana dashboard import \
  --name $AMG_NAME \
  --resource-group $RG_NAME \
  --folder "Istio" \
  --definition 7630

# azure app configuration store
AAC_NAME=$(az appconfig create \
  --name aac-build2023-$RAND \
  --location $LOCATION \
  --resource-group $RG_NAME \
  --query name \
  --output tsv)

az appconfig feature set --name $AAC_NAME --feature Chat -y

# azure key vault
AKV_NAME=$(az keyvault create --name kvbuild2023$RAND \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --query id \
  --output tsv)

# azure load testing
ALT_NAME=$(az load create \
  --name alt-build2023-$RAND \
  --resource-group $RG_NAME \
  --query name \
  --output tsv)