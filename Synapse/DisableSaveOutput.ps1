# THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
# EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
# OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Change the published notebooks in Synapse workspaces to not save the outputs
# And clear all the notebooks outputs
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Parameters
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    $workspaceName,
    [Parameter(Mandatory=$true)]
    $tenantId
)

$devDomain="dev.azuresynapse.net"
$apiVersion="2020-12-01"
$WorkspaceSpecificUrl="https://$workspaceName.$devDomain"


#function to get the token for the workspace dev endpoint
function getToken() {
    Write-Host "Getting token for workspace $workspaceName"
    $token = (Get-AzAccessToken -ResourceUrl "https://$devDomain" -TenantId $tenantId).Token
    return $token
}

# function to call the Synapse REST API
function invokeREST($method, $relativeUrl,$headers, $body) {
    
    
    $uri=$WorkspaceSpecificUrl + $relativeUrl + "?api-version=" +$apiVersion
    
    # Authorization header
    $defaultHeaders = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }

    # check if headers passed
    if ($headers.Count -gt 0) {
        $headers = $defaultHeaders + $headers
    } else {
        $headers = $defaultHeaders
    }

    # send the request
    try{
        $response = Invoke-RestMethod -Method $method -Uri $uri -Body $body -Headers $headers | ConvertTo-Json -Depth 99
    }
    catch{
        Write-Host "Error: $($_.Exception.Message)"
        Write-Host "Details:" $_.ErrorDetails.Message
        exit 1
    }
    return $response
}

# Get Access token to https://dev.azuresynapse.net
$token = getToken

# Get a list of notebooks in the workpsace
$response=invokeREST -method GET -relativeUrl "/notebooksSummary" -body $null

#convert the response to a list of notebooks
$notebooks = $response | ConvertFrom-Json

# check if the notebook exists
if($notebooks.value.Length -eq 0)
{
    Write-Host "No Notebooks in workspace $workspaceName"
    exit 1
}

#loop through the notebooks and get the notebook details
foreach($notebook in $notebooks.value) {
    Write-Host "Notebook: $($notebook.name)"
    $response = invokeREST -method GET -relativeUrl "/notebooks/$($notebook.name)" -body $null

    # convert the response to a notebookDetails object
    $notebookDetails = $response | ConvertFrom-Json

    # Set the saveOutput flag to false
    $notebookDetails.properties.metadata.saveOutput=$false

    # Remove the state of the notebook
    $notebookDetails.properties.metadata.synapse_widget=New-Object -TypeName object

    # Remove the outputs of the notebook cells
    foreach($cell in $notebookDetails.properties.cells) {
        $cell.outputs=@()
    }

    $headers = @{
        "If-Match" =  """$($notebookDetails.etag)"""
    }
   
    # Remove id, type and etag properties from the notebook details
    $notebookDetails.PSObject.properties.remove('id')
    $notebookDetails.PSObject.properties.remove('type')
    $notebookDetails.PSObject.properties.remove('etag')

    # convert notebookDetails to a json string
    $notebookDetails = $notebookDetails | ConvertTo-Json -Depth 99

    # Update the notebook
    $updateNotebookResponse = invokeREST -method PUT -relativeUrl "/notebooks/$($notebook.name)" -headers $headers -body $notebookDetails

    $updateNotebookResponse
}

