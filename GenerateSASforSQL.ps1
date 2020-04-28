

# Input parameters  
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    $StorageAccountName,
    [Parameter(Mandatory=$true)]
    $resourceGroupName,
    [Parameter(Mandatory=$true)]
    $containerName
)


# Get the access keys for the Azure Resource Manager storage account  
$accountKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName  

# Create a new storage account context using an Azure Resource Manager storage account  
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $accountKeys[0].Value

# Creates a new container in blob storage if doesn't exist
$container = Get-AzStorageContainer -Context $storageContext -Name $containerName
if ($null -eq $container)
{
    $container = New-AzStorageContainer -Context $storageContext -Name $containerName  
}

$policyName=$containerName+"_pol_sql_rwld"
# Sets up a Stored Access Policy and a Shared Access Signature for the new container  
$policy = New-AzStorageContainerStoredAccessPolicy -Container $containerName -Policy $policyName -Context $storageContext -StartTime $(Get-Date).ToUniversalTime().AddMinutes(-5) -ExpiryTime $(Get-Date).ToUniversalTime().AddYears(10) -Permission rwld

# Gets the Shared Access Signature for the policy  
$sas = New-AzStorageContainerSASToken -name $containerName -Policy $policy -Context $storageContext
Write-Host 'Shared Access Signature= '$($sas.Substring(1))''  

# Sets the variables for the new container you just created
$cbc = $container.CloudBlobContainer 

# Outputs the Transact SQL to the clipboard and to the screen to create the credential using the Shared Access Signature  
Write-Host 'Credential T-SQL for SQL Server & Managed Instance'  
$tSql1 = "CREATE CREDENTIAL [{0}] WITH IDENTITY='Shared Access Signature', SECRET='{1}'" -f $cbc.Uri,$sas.Substring(1)   
Write-Host $tSql1 
Write-Host 'Credential T-SQL for Azure SQL Database'  
$tSql2 = "CREATE DATABASE SCOPED CREDENTIAL [{0}] WITH IDENTITY='Shared Access Signature', SECRET='{1}'" -f $cbc.Uri,$sas.Substring(1)   
Write-Host $tSql2
 
$choice=Read-Host "Which one you want to copy to clipboard \n 1)Server scoped 2)Database scoped \n Enter 1 or 2"
if ($choice -eq 1)
   {$tSql1 | clip}
else {$tsql2 | clip}


