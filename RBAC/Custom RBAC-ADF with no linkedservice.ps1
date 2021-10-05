
$RoleName = "ADF-Developers"
$SubscriptionID=Read-Host "Enter subscription id: "

Add-AzAccount

Get-AzProviderOperation -OperationSearchString "Microsoft.DataFactory/*" | Select operation,operationName,description | Out-GridView

# Decide which role you will inherit. Execute one of these two lines.
$Role = Get-AzRoleDefinition "Contributor"
$Role = Get-AzRoleDefinition "Data Factory Contributor" # like contributor but doesn't have the ability to publish

$Role.Name=$RoleName
$Role.Id=$null
$Role.IsCustom=$true
$Role.Description="ADF Developer- not permitting to create/alter linked services"
$Role.NotActions.Add("Microsoft.DataFactory/datafactories/linkedServices/delete")
$Role.NotActions.Add("Microsoft.DataFactory/datafactories/linkedServices/write")
$Role.NotActions.Add("Microsoft.DataFactory/factories/linkedServices/delete")
$Role.NotActions.Add("Microsoft.DataFactory/factories/linkedServices/write")

$Role.AssignableScopes.Clear()
$Role.AssignableScopes.Add("/subscriptions/"+$SubscriptionID)


New-AzRoleDefinition -Role $Role

$newRole = Get-AzRoleDefinition -Name $RoleName

Set-AzRoleDefinition -Role $newRole

