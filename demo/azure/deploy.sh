RAND=$RANDOM
LOCATION=eastus

# resource group
RG_NAME=$(az group create --name rg-build2023-$RAND --location $LOCATION --query name --output tsv)

# azure openai
AOAI_NAME=$(az cognitiveservices account create --name aoaibuild2023$RAND \
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
  --name amgbuild2023$RAND \
  --resource-group $RG_NAME \
  --query id \
  --output tsv)

# azure monitor workspace
AMON_ID=$(az resource create \
  --resource-group $RG_NAME \
  --namespace microsoft.monitor \
  --resource-type accounts \
  --name amonbuild2023$RAND \
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
AKS_NAME=$(az aks create --name aksbuild2023$RAND \
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
  --name aacbuild2023$RAND \
  --location $LOCATION \
  --resource-group $RG_NAME \
  --query name \
  --output tsv)

az appconfig feature set --name $AAC_NAME --feature Chat -y

SQL_USER="eshopadmin"
SQL_PASSWORD=$(openssl rand -base64 32)

SQL_NAME=$(az sql server create --name sqlbuild2023$RAND \
  --resource-group $RG_NAME \
  --admin-password $SQL_PASSWORD \
  --admin-user $SQL_USER \
  --enable-public-network true \
  --query name \
  --output tsv)

az sql server firewall-rule create \
  --resource-group $RG_NAME \
  --server $SQL_NAME \
  --name AllowAllWindowsAzureIps \
  --start-ip-address "0.0.0.0" \
  --end-ip-address "0.0.0.0"

SQL_POOL_NAME=$(az sql elastic-pool create \
  --resource-group $RG_NAME \
  --server $SQL_NAME \
  --name "$SQL_NAME-pool" \
  --edition GeneralPurpose \
  --family Gen5 \
  --capacity 2 \
  --query name \
  --output tsv)

SQL_DB_CATALOG=eShopOnWeb.CatalogDb

az sql db create \
  --name $SQL_DB_CATALOG \
  --resource-group $RG_NAME \
  --server $SQL_NAME \
  --license-type BasePrice \
  --elastic-pool $SQL_POOL_NAME

SQL_DB_IDENTITY=eShopOnWeb.Identity

az sql db create \
  --name $SQL_DB_IDENTITY \
  --resource-group $RG_NAME \
  --server $SQL_NAME \
  --license-type BasePrice \
  --elastic-pool $SQL_POOL_NAME

# azure key vault
AKV_NAME=$(az keyvault create --name akvbuild2023$RAND \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --query name \
  --output tsv)

az keyvault secret set \
  --vault-name $AKV_NAME \
  --name "openai-api-key" \
  --value $(az cognitiveservices account keys list \
    --name $AOAI_NAME \
    --resource-group $RG_NAME \
    --query key1 \
    --output tsv)
  
az keyvault secret set \
  --vault-name $AKV_NAME \
  --name "openai-api-url" \
  --value $(az cognitiveservices account show \
    --name $AOAI_NAME \
    --resource-group $RG_NAME \
    --query properties.endpoint \
    --output tsv)

az keyvault secret set \
  --vault-name $AKV_NAME \
  --name "sqlserver-password" \
  --value $SQL_PASSWORD

CATALOGDB_CONNECTION=$(az sql db show-connection-string --client ado.net --name $SQL_DB_CATALOG --server $SQL_NAME --output tsv)
CATALOGDB_CONNECTION=$(echo $CATALOGDB_CONNECTION | sed "s/<username>/${SQL_USER}/g" | sed "s^<password>^${SQL_PASSWORD}^g")

az keyvault secret set \
  --vault-name $AKV_NAME \
  --name "catalog-db-connection" \
  --value "${CATALOGDB_CONNECTION}"

IDENTITY_CONNECTION=$(az sql db show-connection-string --client ado.net --name $SQL_DB_IDENTITY --server $SQL_NAME --output tsv)
IDENTITY_CONNECTION=$(echo $IDENTITY_CONNECTION | sed "s/<username>/${SQL_USER}/g" | sed "s^<password>^${SQL_PASSWORD}^g")

az keyvault secret set \
  --vault-name $AKV_NAME \
  --name "identity-db-connection" \
  --value "${IDENTITY_CONNECTION}"

az keyvault secret set \
  --vault-name $AKV_NAME \
  --name "app-config-connection" \
  --value $(az appconfig credential list \
    --resource-group $RG_NAME \
    --name $AAC_NAME \
    --query "[0].connectionString" \
    --output tsv)

# azure load testing
ALT_NAME=$(az load create \
  --name altbuild2023$RAND \
  --resource-group $RG_NAME \
  --query name \
  --output tsv)