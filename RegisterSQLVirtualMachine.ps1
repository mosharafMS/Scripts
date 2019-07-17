






Function Register-SQLVirtualMachine {
Param(
[Parameter(Mandatory=$true)]
[string] $resourceGroupName,
[Parameter(Mandatory=$true)]
[string] $virtualMachineName,
[Parameter()]
[string] $subscriptionID
)

#login if there's no context available
$context=Get-AzContext
if($null -eq $context)
{
    Add-AzAccount
}

# Register the new SQL resource provider to your subscription
$provider=Get-AzResourceProvider -ProviderNamespace Microsoft.SqlVirtualMachine -ErrorAction SilentlyContinue
if($null -eq $provider)
{
    Register-AzResourceProvider -ProviderNamespace Microsoft.SqlVirtualMachine
    Start-Sleep -Seconds 30
}
#switch the context if subscription provided
if($subscriptionID -ne $null)
{
    Select-AzSubscription -SubscriptionId $subscriptionID
}

$vm=Get-AzVm -ResourceGroupName $resourceGroupName -Name $virtualMachineName -ErrorAction SilentlyContinue
if($null -eq $vm)
{
    ThrowError -ExceptionMessage "Could not find Virtual machine"
    return
}

#check if the machine is running
$powerStatus=Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status | Select @{n="Status"; e={$_.Statuses[1].Code}}
if("PowerState/running" -ne $powerStatus.Status)
{
    ThrowError -ExceptionMessage "Virtual machine should be running to apply the changes"
    return
}


#make sure the SQL IaaS extension is installed on the machine Microsoft.SqlServer.Management.SqlIaaSAgent
$sqlIaaSExtension=Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -Name "SqlIaasExtension" -ErrorAction SilentlyContinue

if($null -eq $sqlIaaSExtension)
{
   # Register SQL VM with 'Lightweight' SQL IaaS agent
   New-AzResource -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Location $vm.Location `
      -ResourceType Microsoft.SqlVirtualMachine/SqlVirtualMachines `
      -Properties @{virtualMachineResourceId=$vm.Id;SqlServerLicenseType='AHUB';sqlManagement='LightWeight'} `
      -Force
}
else {
    New-AzResource -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Location $vm.Location `
      -ResourceType Microsoft.SqlVirtualMachine/SqlVirtualMachines `
      -Properties @{virtualMachineResourceId=$vm.Id;SqlServerLicenseType='AHUB'} `
      -Force
}


}


#read the config file
$configFile=(Split-Path -Parent $MyInvocation.MyCommand.Path)+"\RegisterSQLVirtualMachine.json"
$SQLVMs=Get-Content -Path $configFile | ConvertFrom-Json

foreach($virtualMachine in $SQLVMs.SQLVMs)
{
    Write-Host "ResourceGroup: " $virtualMachine.ResourceGroup 
    Write-Host "VirtualMachine: "  $virtualMachine.VirtualMachineName
    Register-SQLVirtualMachine -resourceGroupName $virtualMachine.ResourceGroup  -virtualMachineName $virtualMachine.VirtualMachineName 
}
