# ----------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#
# THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
# EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
# OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# ----------------------------------------------------------------------------------


$DebugPreference="Continue"
#$DebugPreference="SilentlyContinue"

$TargetServerName = Read-Host "Please enter Server Name"
$InstanceName = Read-Host "Please enter the named instance name if it's named instance, if not leave blank"
$workingDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$PerfUserName = Read-Host "Please enter the user name that will be used for the collection, blank means system"

# Set location to the location of the script file
Set-Location $workingDirectory

#Get the list of the template files
$templateFiles=(Get-ChildItem -Path *.template).Name
[System.Collections.ArrayList]$templates = New-Object System.Collections.ArrayList
foreach ($file in $templateFiles) {
   $templates.Add($file.Split('_')[0]) | Out-Null  # Add the file to the list
}
#all lower case 
$templates = $templates | ForEach-Object {$_.ToLower()}
# remove duplicates
$templates = [System.Collections.ArrayList]($templates | Select-Object -Unique | Sort-Object)


#list all templates
Write-Host "List all available template files"
foreach ($template in $templates) {
   Write-Host '** '$template
}

$perfTemplatePrefix = Read-Host "Please type the template name and press ENTER"
if($perfTemplatePrefix -eq ""){
   Write-Error -Message "No template selected...exiting"
   Exit 1
}

#ready to copy the template files
Write-Host "Data ready....generating files"

$CounterFile='Counters_' + $TargetServerName + '_' + $InstanceName + '.txt'

if ($InstanceName -eq "")
{
	Copy-Item -Path ($perfTemplatePrefix + "_defaultInstance.template") -Destination $CounterFile 
	(get-content $CounterFile) | foreach-object {$_ -replace "\|ServerName\|", $TargetServerName} | set-content $CounterFile
}
else
{
	Copy-Item -Path ($perfTemplatePrefix + "_namedInstance.template") -Destination $CounterFile
	(get-content $CounterFile) | foreach-object {$_ -replace "\|ServerName\|", $TargetServerName} | set-content $CounterFile
	(get-content $CounterFile) | foreach-object {$_ -replace "\|InstanceName\|", $InstanceName} | set-content $CounterFile

}

Write-Host "Counter files generated"

Write-Host "Generating command "



$logmanCommand = get-content "template_command.txt"
$logmanCommand = $logmanCommand.Replace("|ServerName|",$TargetServerName) 
$logmanCommand = $logmanCommand.Replace("|TimeStamp|", (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
$logmanCommand = $logmanCommand.Replace("|InstanceName|" ,$InstanceName)
$logmanCommand = $logmanCommand.Replace("|WorkingFolder|",$workingDirectory)
if($PerfUserName -eq "")
{
     $logmanCommand = $logmanCommand.Replace('-u "|UserName|" *','')
}else
{
    $logmanCommand = $logmanCommand.Replace("|UserName|",$PerfUserName)
}

Write-Debug $logmanCommand

cmd /c $logmanCommand
$startCollection=Read-Host "Collection created, enter s if you like to start it, blank to skip"
if($startCollection -eq "s")
{
$startcommand='logman start PerfCollector_' + $TargetServerName + '_' +$InstanceName
Write-Debug $startcommand
cmd /c $startcommand
}
