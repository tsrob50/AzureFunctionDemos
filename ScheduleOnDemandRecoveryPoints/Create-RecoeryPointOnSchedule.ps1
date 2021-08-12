<#
.SYNOPSIS
    Automated process to create on-demand snapshots of an azure files share based on a cron schedule.
.DESCRIPTION
    This script is intended to initiate an on-demand recovery point (snapshot) based on a cron schedule.  Azure Recovery Vault File 
    Share back up is limited to one scheduled recovery point per day. For some organizations, this will not meet their recovery point 
    objectives (RPO). This script is intended to run at an intervale specified in a cron schedule and run on-demand snapshots for 
    additional recovery points.

    Please be aware of the following limitations with Azure File Share Snapshots (Aug, 2021):
        Maximum on-demand backups per day               10
        Maximum total recovery points per file share    200
    Factor in scheduled and on-demand backups to verify total recovery points do not exceed 200
    https://docs.microsoft.com/en-us/azure/backup/azure-file-share-support-matrix

    The cron example below will run at the top of the 15, 18 and 20th hour UTC, Monday through Friday
    Credit https://github.com/atifaziz/NCrontab
    Cron Example:
    0 0 15,18,20 * * 1,2,3,4,5
    - - -        - - -
    | | |        | | |
    | | |        | | +----- day of week (0 - 6) (Sunday=0)
    | | |        | +------- month (1 - 12)
    | | |        +--------- day of month (1 - 31)
    | | +----------- hour (0 - 23 Script uses UTC)
    | +------------- min (0 - 59)
    +------------- sec (0 - 59)
    Link to view the cron expression:
    https://crontab.cronhub.io/
    Link to convert local time to UTC:
    https://www.worldtimebuddy.com/
    
    Use this script for file shares that are configured for backup by the recovery vault.
    This script runs on an Azure Function app.  Use a user assigned managed identity with the backup contributor role 
    assigned to the storage account resource group to create the recovery points.
    Private endpoints will need to be modified when used.

.NOTES
    Script is offered as-is with no warranty, expressed or implied.
    Test it before you trust it
    Author      : Travis Roberts, Ciraltos llc
    Website     : www.ciraltos.com
    Version     :1.0.0.0 Initial Build
#>

# Get the timer parameter
param($Timer)

##### Set Variables #####

# Retention Days, the snapshots will expire at the end of the retention period.
# Days must be grater then one (use 1.1 for a one day retention)
$expireDays = 1.1

# Enter the name of the Recovery Vault configured to back up the file shares.
$vaultName = "<RecoveryVaultName>"

# Enter the name of the storage account getting backed up.
$StgActName = "<StorageAccountName>"

# Enter one or more Azure File Share Names to be backed up. 
$shareNames = @(
    '<Share1>'
    '<Share2>'
)

##### Execution #####

# Get the expiry date for the share.
$expiryDate = (get-date).AddDays($expireDays)

# Get the vault id
Try {
    $vaultID = (Get-AzRecoveryServicesVault -ErrorAction Stop -Name $vaultName).id 
    Write-Output "The vaultID is: $vaultID"
}
Catch {
    $ErrorMessage = $_.Exception.message
    write-host ('Error getting the vaultID: ' + $ErrorMessage)
    Break
}

Try {
    $rsvContainer = Get-AzRecoveryServicesBackupContainer -ErrorAction Stop -FriendlyName $stgActName -ContainerType AzureStorage -VaultId $vaultID 
    Write-Output "the afsContainer is $rsvContainer"
}
Catch {
    $ErrorMessage = $_.Exception.message
    write-host ('Error getting the backup container: ' + $ErrorMessage)
    Break
}

foreach ($shareName in $shareNames) {
    Try {
        $rsvBkpItem = Get-AzRecoveryServicesBackupItem -ErrorAction Stop -Container $rsvContainer -WorkloadType "AzureFiles" -VaultId $vaultID -FriendlyName $shareName
        $Job = Backup-AzRecoveryServicesBackupItem -ErrorAction Stop -Item $rsvBkpItem -VaultId $vaultID -ExpiryDateTimeUTC $expiryDate
        Write-output "Job data:"
        $Job | Out-String | Write-Host
    }
    Catch {
        $ErrorMessage = $_.Exception.message
        write-host ('Error creating the recovery point: ' + $ErrorMessage)
        Break
    }    
}

