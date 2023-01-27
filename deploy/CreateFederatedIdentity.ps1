$githubOrganizationName = 'smurawski'
$githubRepositoryName  = 'eShopOnWeb'
$testApplicationRegistration = New-AzADApplication -DisplayName 'cnny-week3-day1'

New-AzADAppFederatedCredential `
   -Name 'cnny-week3-day1' `
   -ApplicationObjectId $testApplicationRegistration.Id `
   -Issuer 'https://token.actions.githubusercontent.com' `
   -Audience 'api://AzureADTokenExchange' `
   -Subject "repo:$($githubOrganizationName)/$($githubRepositoryName):ref:refs/heads/week3/day1"

$testResourceGroup = get-azresourcegroup -name 'cnny-week2'
New-AzADServicePrincipal -AppId $($testApplicationRegistration.AppId)
New-AzRoleAssignment `
   -ApplicationId $($testApplicationRegistration.AppId) `
   -RoleDefinitionName Contributor `
   -Scope $($testResourceGroup.ResourceId)

New-AzRoleAssignment `
   -ApplicationId $($testApplicationRegistration.AppId) `
   -RoleDefinitionName Contributor `
   -Scope (Get-AzContext).Subscription.Id