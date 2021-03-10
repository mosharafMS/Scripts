

$builtInRole=Get-AzRoleDefinition "DevTest Labs User"

$builtinRole | ConvertTo-Json | Out-File "d:\temp\CustomDevTestLabRole.json"

#open the file and update it to be as below. ADD the assignable scope as shown in 
# https://docs.microsoft.com/en-us/azure/role-based-access-control/role-definitions#assignablescopes

<#
{
    "Name": "DevTest Labs Limited User",
    "Id": null,
    "IsCustom": true,
    "Description": "DevTest Labs user without the ability to create a VM",
    "Actions": [
      "Microsoft.Authorization/*/read",
      "Microsoft.Compute/availabilitySets/read",
      "Microsoft.Compute/virtualMachines/*/read",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.DevTestLab/*/read",
      "Microsoft.DevTestLab/labs/claimAnyVm/action",
      "Microsoft.DevTestLab/labs/ensureCurrentUserProfile/action",
      "Microsoft.DevTestLab/labs/formulas/delete",
      "Microsoft.DevTestLab/labs/formulas/read",
      "Microsoft.DevTestLab/labs/formulas/write",
      "Microsoft.DevTestLab/labs/policySets/evaluatePolicies/action",
      "Microsoft.DevTestLab/labs/virtualMachines/claim/action",
      "Microsoft.DevTestLab/labs/virtualmachines/listApplicableSchedules/action",
      "Microsoft.DevTestLab/labs/virtualMachines/getRdpFileContents/action",
      "Microsoft.Network/loadBalancers/backendAddressPools/join/action",
      "Microsoft.Network/loadBalancers/inboundNatRules/join/action",
      "Microsoft.Network/networkInterfaces/*/read",
      "Microsoft.Network/networkInterfaces/join/action",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkInterfaces/write",
      "Microsoft.Network/publicIPAddresses/*/read",
      "Microsoft.Network/publicIPAddresses/join/action",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Resources/deployments/operations/read",
      "Microsoft.Resources/deployments/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Storage/storageAccounts/listKeys/action"
    ],
    "NotActions": [
      "Microsoft.Compute/virtualMachines/vmSizes/read"
    ],
    "DataActions": [],
    "NotDataActions": [],
    "AssignableScopes": [
      "<put here management group or subscriptions>"
    ]
  }
#>

New-AzRoleDefinition -InputFile "d:\temp\CustomDevTestLabRole.json" 

#assignment can be done by the portal 