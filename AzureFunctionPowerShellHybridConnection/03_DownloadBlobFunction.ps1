
<#
.SYNOPSIS
  This Azure Function copies a file from Azure BLob Storage to a local file server when a new file is added to a Storage Account
.DESCRIPTION
  ****This script provided as-is with no warranty. Test it before you trust it.****
  When a file is added to a blob container, Event Grid triggers this Azure Function.  
  The Function Uses Invoke-Command and a Relay Hybrid Connection to run the script on a hybrid 
  endpoint inside a private network.  The script copies the blob file to the local file system.
  Parts of the code below were used from Microsoft Document at:
  https://docs.microsoft.com/en-us/azure/azure-functions/functions-hybrid-powershell#configure-an-on-premises-server-for-powershell-remoting
.INPUTS
  Hashtable data passed by Event Grid
.OUTPUTS
  Errors write to the Error output stream
.NOTES
  Version:        1.0
  Author:         Travis Roberts
  Creation Date:  9/17/2019
  Purpose/Change: Initial script development
  ****This script provided as-is with no warranty. Test it before you trust it.****
.EXAMPLE
  See my YouTube channel at http://www.youtube.com/c/TravisRoberts or https://www.Ciraltos.com for details.
#>

param(
    $eventGridEvent,
    $TriggerMetadata
)

## declarations ##

# This is the name of the hybrid connection computer.
# Update with your hybred endpoint name.  Must be DNS resolveable by the Hybrid Connection Manager
$HybridEndpoint = "Endpoint Name"

# Local file path.  This is where the file will be copied to
$localFilePath = 'c:\Blob\'

# Note that AdminPassword is a function app setting, so I can access it as $env:AdminPassword  
# Update $userName and $appPassword with your values
$UserName = "administrator"
$securedPassword = ConvertTo-SecureString  $env:AdminPassword -AsPlainText -Force
$Credential = [System.management.automation.pscredential]::new($UserName, $SecuredPassword)

# Set the default error action
$errorActionDefault = $ErrorActionPreference

# Name of the storage account
try {
    $ErrorActionPreference = 'stop'
    $topicSplit = $eventGridEvent.topic -split '/'
    $storageAccountName = $topicSplit[8]
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error getting the Storage Account ' + $ErrorMessage)
    Break
}

# Get the container name
try {
    $ErrorActionPreference = 'stop'
    $subject = $eventGridEvent.subject -split '/'
    $container = $subject[4]
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error getting the container name ' + $ErrorMessage)
    Break
}
Finally {
    $ErrorActionPreference = $errorActionDefault
}

# Convert data.url to file and path
try {
    $ErrorActionPreference = 'stop'
    $fileName = $eventGridEvent.data.url -replace "https://$storageAccountName.blob.core.windows.net/$container/", ""
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error converting file path ' + $ErrorMessage)
    Break
}
Finally {
    $ErrorActionPreference = $errorActionDefault
}

# Script that executes on remote server
$Script = {
    param (
        $localFilePath,
        $StorageAccountName,
        $StorageAccountKey,
        $fileName,
        $container
    )

    # Check for target directory
    # Create if it doesn't exist
    # Needs to run remote
    try {
        if (!(Test-Path -Path $localFilePath)) {
            new-item -ErrorAction Stop -ItemType 'directory' -Path $localFilePath
        }
    }
    catch {
        $ErrorMessage = $_.Exception.message
        write-error ('Error checking and creating local file path ' + $ErrorMessage)
        Break
    }

    # Set the Storage Account Context
    try {
        $ctx = New-AzStorageContext -ErrorAction stop -storageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    }
    catch {
        $ErrorMessage = $_.Exception.message
        write-error ('Error converting file path ' + $ErrorMessage)
        Break
    }

    # Copy the file
    # This command copies the file local
    try {
        Get-AzStorageBlobContent -ErrorAction stop -Blob $fileName -Container $Container -Destination $localFilePath -Context $ctx -Force
    }
    catch {
        $ErrorMessage = $_.Exception.message
        write-error ('Error downloading file ' + $ErrorMessage)
        Break
    }
}

Write-Output "Running command via Invoke-Command"
Invoke-Command -ComputerName $HybridEndpoint `
    -Credential $Credential `
    -Port 5986 `
    -UseSSL `
    -ScriptBlock $Script `
    -ArgumentList $localFilePath, $StorageAccountName, $env:cirhybridfunctiondemokey, $fileName, $Container `
    -SessionOption (New-PSSessionOption -SkipCACheck)



    