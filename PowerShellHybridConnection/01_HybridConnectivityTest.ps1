<#
Hybrid connection test
Verify remote command execution over the Hybrid Connection

#>

param($eventGridEvent, $TriggerMetadata)

# Get Function App hostname
Write-Output '## App Service Hostname ##'
$env:COMPUTERNAME

# Get remote computer hostname
# this should return the Hybrid Connection Manager endpoint 



# This is the name of the hybrid connection computer
# Enter your endpoint here
$HybridEndpoint = "Endpoint Name"

# Note that AdminPassword is a function app setting, so it can be referanced with $env:AdminPassword
# Update $userName and $appPassword with your values
$UserName = "administrator"
$appPassword = $Env:AdminPassword 
$securedPassword = ConvertTo-SecureString  $appPassword -AsPlainText -Force
$Credential = [System.management.automation.pscredential]::new($UserName, $SecuredPassword)


$script = {
    $env:COMPUTERNAME
}

# Display the hostname from the remote endpoint
Write-Output '## Remote Endpoint Hostname ##'
Invoke-Command -ComputerName $HybridEndpoint `
               -Credential $Credential `
               -Port 5986 `
               -UseSSL `
               -ScriptBlock $Script `
               -ArgumentList "*" `
               -SessionOption (New-PSSessionOption -SkipCACheck)


