<#
.SYNOPSIS
  This Azure Function sends a message to a Teams channel when a defined object is added to an Azure subscription.
.DESCRIPTION
  ****This script provided as-is with no warranty. Test it before you trust it.****
  Event Grid send a trigger to the Azure Function when a defined object is added to a subscription.  Advanced filters in Event Grid limit the alter to a defined data type.  If statements
  are used to customize the message based on the resource type.
  Resource types are specified in the input data from Event Grid.  Resource Provider Operations are listed in the document:
  https://docs.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations#microsoftcompute
  The Azure function formats the message using static and dynamic content from the input data.
  Azure function sends the formated web hook with the message for the Teams Channel.
.INPUTS
  Hashtable data passed in from Event Grid
.OUTPUTS
  Errors write to the Error stream
  Logging and test data writes to the Output stream
  Notification in Teams
.NOTES
  Version:        1.0
  Author:         Travis Roberts
  Creation Date:  9/6/2019
  Purpose/Change: Initial script development
  ****This script provided as-is with no warranty. Test it before you trust it.****
.EXAMPLE
  See my YouTube channel at http://www.youtube.com/c/TravisRoberts or https://www.Ciraltos.com for details.
#>

# Parameter Name must match bindings
param($eventGridEvent, $TriggerMetadata)

# Logging data, informational only
# log eventGridEvent in one output stream
write-output "## eventGridEvent ##"
$eventGridEvent | out-string | Write-Output

# Get Data Type
write-output "## Get-Member ##"
$eventGridEvent | Get-Member | Out-string | Write-Output

# Get output as JSON
write-output "## eventGridEvent.json ##"
$eventGridEvent | convertto-json | Write-Output

# Declarations

# Set the default error action
$errorActionDefault = $ErrorActionPreference

# Channel Webhook.  This URL comes from the Teams chanel that will receive the messages.
$ChannelURL = "Enter Teams Webhook Here"

# Get the subscription
try {
    $ErrorActionPreference = 'stop'
    $SubscriptionId = $eventGridEvent.data.subscriptionId
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error getting Subscription ID ' + $ErrorMessage)
    Break
}
Finally {
    $ErrorActionPreference = $errorActionDefault
}

# Set the ActivityTitle (name of resource) and ActivityType (type of resource)
# Based on they filter set in Event Grid 
if ($eventGridEvent.data.authorization.action -like "Microsoft.Compute/virtualMachines/write") {
    # Set the type of resource created
    $ActivityType = "Server"

    # Set the image used for the message.  
    # leave blank for no image
    $image = ""

    # Get the server name
    try {
        $ErrorActionPreference = 'stop'
        $subjectSplit = $eventGridEvent.subject -split '/'
        $typeName = $subjectSplit[8]
    }
    catch {
        $ErrorMessage = $_.Exception.message
        write-error ('Error getting Resource Group name ' + $ErrorMessage)
        Break
    }
    Finally {
        $ErrorActionPreference = $errorActionDefault
    }
}
elseif ($eventGridEvent.data.authorization.action -like "Microsoft.Resources/subscriptions/resourceGroups/write" ) {
    # Set the type of resource created
    $ActivityType = "Resource Group"

    # Set the image used for the message.  
    # leave blank for no image
    $image = ""

    # Get Resource Group
    try {
        $ErrorActionPreference = 'stop'
        $subjectSplit = $eventGridEvent.subject -split '/'
        $typeName = $subjectSplit[4]
    }
    catch {
        $ErrorMessage = $_.Exception.message
        write-error ('Error getting Resource Group name ' + $ErrorMessage)
        Break
    }
    Finally {
        $ErrorActionPreference = $errorActionDefault
    }
}
else {
    write-error 'No activity type defined in script.  Verfiy Event Grid Filter matches IF statement'
    Break
}

<#
# Used for testing
Write-Output '## Type Name ##'
Write-Output $typeName
Write-Output '## Subscription ##'
Write-Output $SubscriptionId
Write-Output '## name ##'
Write-Output $eventGridEvent.data.claims.name
#>

# Send Data to Teams
# Build the message body
$TargetURL = "https://portal.azure.com/#resource" + $eventGridEvent.data.resourceUri + "/overview"   
try {    
    $Body = ConvertTo-Json -ErrorAction Stop -Depth 4 @{
        title           = 'Azure Resource Creation Notification From Azure Functions' 
        text            = 'A new Azure ' + $activityType + ' has been created'
        sections        = @(
            @{
                activityTitle    = 'New Azure ' + $ActivityType
                activitySubtitle = 'Azure ' + $ActivityType + ' named ' + $typeName + ' has been created.'
                activityText     = 'An Azure ' + $ActivityType + ' was created in the subscription ' + $SubscriptionId + ' by ' + $eventGridEvent.data.claims.name
                activityImage    = $image
            }
        )
        potentialAction = @(@{
                '@context' = 'http://schema.org'
                '@type'    = 'ViewAction'
                name       = 'Click here to manage the Resource Group'
                target     = @($TargetURL)
            })
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error converting body to JSON ' + $ErrorMessage)
    Break
}
           
# call Teams webhook
try {
    write-output '## Invoke-ResgtMethod ##'
    Invoke-RestMethod -Method "Post" -Uri $ChannelURL -Body $Body | Write-output
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error with invoke-restmethod ' + $ErrorMessage)
    Break
}
