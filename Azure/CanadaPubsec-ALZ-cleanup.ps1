#Parameters
[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $rgPrefix
)


#loop through all the resource groups
$resourceGroups = Get-AzResourceGroup "$rgPrefix*"

foreach ($rg in $resourceGroups) {
    #loop through all the resources in the resource group
    Write-Host "Deleting resources in group: $($rg.ResourceGroupName)"
    $resources = Get-AzResource -ResourceGroup $rg.ResourceGroupName
    foreach ($resource in $resources) {
        if($resource.ResourceType -eq "Microsoft.KeyVault/vaults") {
            Write-Host "Skipping vault: $($resource.Name)"
            continue
        }
        else {
            #remove the resource
            Write-Host "Deleting resource: $($resource.Name) of type: $($resource.ResourceType)"
            Remove-AzResource -ResourceGroup $rg.ResourceGroupName -Name $resource.Name -ResourceType $resource.ResourceType -Force 
        } 
    
    }
}
Write-Host ""
Write-Host "Delete empty resource groups"
#loop again to remove empty resource groups
foreach ($rg in $resourceGroups) {
    #check if the resource group has any resources
    $resources = Get-AzResource -ResourceGroup $rg.ResourceGroupName
    if($resources.Count -eq 0) {
        #remove the resource group
        Write-Host "Deleting resource group: $($rg.ResourceGroupName)"
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force
    }
}