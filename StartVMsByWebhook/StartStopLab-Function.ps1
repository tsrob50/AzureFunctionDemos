using namespace System.Net
# Start Stop Lab Function 
# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

<#
  Version:        1.0
  Author:         Travis Roberts, Ciraltos llc
  Creation Date:  1/17/2021
  Purpose/Change: Initial script development
  ****This script provided as-is with no warranty. Test it before you trust it.****
  See my YouTube channel at http://www.youtube.com/c/TravisRoberts or https://www.Ciraltos.com for details.
#>

# Variables
# Set the tag for the VM's to start and stop and the tag value
# VM's with matching tag and value, in the specified scope will start or stop
$tag = "Environment"
$tagVale = "Lab"

# Write to the Azure Functions log stream.
write-host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$action = $Request.query.action
write-host "Action set to: $action"

$body = "Lab Start Stop Ran, action set to $action"


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})

############## Functions ####################

Function Start-Vms {
    param (
        $vms
    )
    foreach ($vm in $vms) {
        try {
            # Start the VM
            $vm | Start-AzVM -ErrorAction Stop -NoWait
        }
        catch {
            $ErrorMessage = $_.Exception.message
            Write-Error ("Error starting the VM: " + $ErrorMessage)
            Break
        }
    }
}
function Stop-Vms {
    param (
        $vms
    )
    foreach ($vm in $vms) {
        try {
            # Start the VM
            $vm | stop-AzVM -ErrorAction Stop -Force -NoWait
        }
        catch {
            $ErrorMessage = $_.Exception.message
            Write-Error ("Error starting the VM: " + $ErrorMessage)
            Break
        }
    }

}  

# Get the servers
try {
    # Start the VM
    $vms = (get-azvm -ErrorAction Stop | Where-Object { $_.tags[$tag] -eq $tagVale })
    write-host "Lab VM list:"
    write-host $vms.name
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Error ("Error returning the VMs: " + $ErrorMessage)
    Break
}

# call the start or stop function
If ($action -eq "start") {
    write-host "Starting the following servers:"
    write-host $vms.Name
    start-vms $vms
}
elseif ($action -eq "stop") {
    write-host "Stopping the following servers:"
    write-host $vms.Name
    stop-vms $vms
}
else {
    write-host "no servers were started or stopped"
}

