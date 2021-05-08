
<#
.SYNOPSIS
    Automated process to stop unused session hosts in a Windows Virtual Desktop (WVD) personal host pool.
.DESCRIPTION
    This script is intended to automatically stop personal host pool session hosts in a Windows Virtual Desktop
    host pool. The script will evaluate session hosts in a host pool and create a list of session hosts with
    active connections. The script will then compare all session hosts in the personal host pool that are 
    powered on and not in drain mode.  The script will shut down the session hosts that have no active connections.

    Requirements:
    WVD personal host pool with Start on Connect enabled 
    https://docs.microsoft.com/en-us/azure/virtual-desktop/start-virtual-machine-connect?WT.mc_id=AZ-MVP-5004159
    An Azure Function App
        Use System Assigned Managed ID
        Give Virtual Machine Contributor and Desktop Virtualization Reader rights for the Session Host VM Resource Group to the Managed ID
        Az powershell modules enabled
    For best results set a GPO to log out disconnected and idle sessions (Users have to disconnect or the session hosts won't shut down)
    For help with setting the Azure Function schedule:
    https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-timer?tabs=csharp&WT.mc_id=AZ-MVP-5004159#ncrontab-expressions
    For full  details, check here:
    TBD
.NOTES
    Script is offered as-is with no warranty, expressed or implied.
    Test it before you trust it
    Author      : Travis Roberts, Ciraltos llc
    Website     : www.ciraltos.com
    Version     : 1.0.0.0 Initial Build
#>

# Input bindings are passed in via param block.
# For the Function App
param($Timer)

######## Variables ##########
# Add the personal host pool name and resource group.
$personalHp = '<Personal Host Pool Name>'
$personalHpRg = '<Personal Host Pool Resource Group>'

# Add the resource group for the session hosts.
# Update if different from the resource group of the Host Pool
$sessionHostVmRg = $personalHpRg

########## Script Execution ##########

# Get the active Session hosts
$activeShs = (Get-AzWvdUserSession -HostPoolName $personalHp -ResourceGroupName $personalHpRg).name
$allActive = @()
foreach ($activeSh in $activeShs) {
    $activeSh = ($activeSh -split { $_ -eq '.' -or $_ -eq '/' })[1]
    $allActive += $activeSh
}

# Get the Session Hosts
# Exclude servers in drain mode and do not allow new connections
$sessionHosts = (Get-AzWvdSessionHost -HostPoolName $personalHp -ResourceGroupName $personalHpRg | Where-Object { $_.AllowNewSession -eq $true } )
$runningSessionHosts = $sessionHosts | Where-Object { $_.Status -eq "Available" }
#Evaluate the list of running session hosts against 
foreach ($sessionHost in $runningSessionHosts) {
    $sessionHost = (($sessionHost).name -split { $_ -eq '.' -or $_ -eq '/' })[1]
    if ($sessionHost -notin $allActive) {
        Write-Host "Server $sessionHost is not active, shut down"
        try {
            # Stop the VM
            Stop-AzVM -ErrorAction Stop -ResourceGroupName $sessionHostVmRg -Name $sessionHost -Force -NoWait
        }
        catch {
            $ErrorMessage = $_.Exception.message
            Write-Error ("Error stopping the VM: " + $ErrorMessage)
            Break
        }
    }
    else {
        write-host "Server $sessionHost has an active session, won't shut down"
    }
}
