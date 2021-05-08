<#
.SYNOPSIS
  This Azure Function is used to tag new resource groups with the user name of the creator.
.DESCRIPTION
  ****This script provided as-is with no warranty. Test it before you trust it.****
  Event Grid send a trigger to the Azure Function when a resource group is added to a subscription.  
  Advanced filters in Event Grid limit the alter to a defined data type.  
  Resource types are specified in the input data from Event Grid.  Resource Provider Operations are listed in the document:
  https://docs.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations#microsoftcompute
  The Azure function formats the tag and value from the Event Grid data.
  Azure function applies the tag and tag value to the resource group.
.INPUTS
  Data passed in from Event Grid
.OUTPUTS
  Errors write to the Error stream
  Logging and test data writes to the Output stream
.NOTES
  Version:        1.0
  Author:         Travis Roberts
  Creation Date:  4/27/2021
  Purpose/Change: Initial script development
  ****This script provided as-is with no warranty. Test it before you trust it.****
.EXAMPLE
  TBD
#>

<# FOR VIDEO:

Code to convert event data to json:
Write-Host "## eventGridEvent.json ##"
$eventGridEvent | convertto-json | Write-Host

Event Grid filter information for Resource Group Writes:
data.authorization.action
Operator:
String Contains
Value:
Microsoft.Resources/subscriptions/resourceGroups/write

#>

# Parameter Name must match bindings
param($eventGridEvent, $TriggerMetadata)

# Get the day in Month Day Year format
$date = Get-Date -Format "MM/dd/yyyy"
# Add tag and value to the resource group
$nameValue = $eventGridEvent.data.claims.name
$tags = @{"Creator"="$nameValue";"DateCreated"="$date"}


write-output "Tags:"
write-output $tags

# Resource Group Information:

$rgURI = $eventGridEvent.data.resourceUri
write-output "rgURI:"
write-output $rgURI

# Update the tag value

Try {
    Update-AzTag -ResourceId $rgURI -Tag $tags -operation Merge -ErrorAction Stop
}
Catch {
    $ErrorMessage = $_.Exception.message
    write-host ('Error assigning tags ' + $ErrorMessage)
    Break
}