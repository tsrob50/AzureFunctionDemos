<#
Sample Script to test Azure Function Input
#>

param($eventGridEvent, $TriggerMetadata)

# log webhookdata in one output stream
write-output "## WebhookData ##"
$eventGridEvent | out-string | Write-Output

# Get Data Type
write-output "## Get-Member ##"
$eventGridEvent | Get-Member| Out-string | Write-Output

# Get output as JSON
write-output "## WebhookData.json ##"
$eventGridEvent | convertto-json | Write-Output