$githubOrganizationName = 'Duffney'
$githubRepositoryName  = 'eShopOnWeb'
$testApplicationRegistration = New-AzADApplication -DisplayName 'cnny-week3-day5'

New-AzADAppFederatedCredential `
   -Name 'cnny-week3-day5' `
   -ApplicationObjectId $testApplicationRegistration.Id `
   -Issuer 'https://token.actions.githubusercontent.com' `
   -Audience 'api://AzureADTokenExchange' `
   -Subject "repo:$($githubOrganizationName)/$($githubRepositoryName):ref:refs/heads/week3/day5"

# $testResourceGroup = get-azresourcegroup -name 'cnny-week3'
New-AzADServicePrincipal -AppId $($testApplicationRegistration.AppId)
# New-AzRoleAssignment `
#    -ApplicationId $($testApplicationRegistration.AppId) `
#    -RoleDefinitionName Contributor `
#    -Scope $($testResourceGroup.ResourceId)

$azureContext = Get-AzContext

New-AzRoleAssignment -ApplicationId $($testApplicationRegistration.AppId) -RoleDefinitionName Owner -Scope "/subscriptions/$($azurecontext.subscription.id)"

Write-Host "AZURE_CLIENT_ID: $($testApplicationRegistration.AppId)"
Write-Host "AZURE_TENANT_ID: $($azureContext.Tenant.Id)"
Write-Host "AZURE_SUBSCRIPTION_ID: $($azureContext.Subscription.Id)"
Write-Host "AZURE_USER_OBJECT_ID: $($testApplicationRegistration.Id)"

# Enable WorkLoadIdentityPreivew for AKS
Register-AzProviderFeature -FeatureName "EnableWorkloadIdentityPreview" -ProviderNamespace "Microsoft.ContainerService"
# az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
