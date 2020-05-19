# Version 1.1
# Examples of running this script:
# To get VMs included in all Veeam backup jobs run: .\VeeamCheckFailoverCluster.ps1 -checkBackupJobs
# To get VMs that have run in a backup job within the last 7 days and have either failed or been successful, run: .\VeeamCheckFailoverCluster.ps1 -checkRunningBackupJobs -includeFailedBackupJobs -daysToCheck 7
# To get VMs that have run in a backup job within the last 7 days and have been successful, run: .\VeeamCheckFailoverCluster.ps1 -checkRunningBackupJobs -daysToCheck 7

Param (
    [Parameter( Mandatory=$false )]
    [switch]$checkBackupJobs,

    [Parameter( Mandatory=$false )]
    [switch]$checkRunningBackupJobs,

    [Parameter( Mandatory=$false )]
    [switch]$includeFailedBackupJobs,

    [Parameter( Mandatory=$false )]
    [string]$daysToCheck
)

# Import Veeam Snapin
asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue

# Get list of VMs in the Failover Cluster from Veeam
$vms = Find-VBRHvEntity | Where-Object {$_.Type -eq "Vm"} | Sort-Object Name

if ($checkBackupJobs) {
    Write-Verbose "Checking all backups jobs within Veeam"
    Write-Verbose "Getting a list of backup jobs"
    $backupJobs = Get-VBRJob
    $vmsinBackupJob=@()
    Write-Verbose "Getting a list of VMs in backup jobs"
    foreach ($backupJob in $backupJobs) {
        $vmsinBackupJob += $backupJob.GetObjectsInJob().Name
    }
}
elseif ($checkRunningBackupJobs -and $includeFailedBackupJobs) {
    Write-Verbose "Checking backup jobs that have run in the last $($daysToCheck) days & including those jobs that have failed"
    $vmBackups = Get-VBRBackupSession | Where-Object {$_.EndTime -ge (Get-Date).AddDays(-$daysToCheck)} | Get-VBRTaskSession
}
elseif ($checkRunningBackupJobs) {
    Write-Verbose "Checking backup jobs that have run in the last $($daysToCheck) days"
    $vmBackups = Get-VBRBackupSession | Where-Object {$_.EndTime -ge (Get-Date).AddDays(-$daysToCheck)} | Get-VBRTaskSession | Where-Object {$_.Status -ne "Failed"}
}

$vmList=@()
$vmCount = $vms.Count
$i = 0


foreach ($vm in $vms) {
    $i++
    $percentComplete = ($i / $vmCount) * 100
    Write-Progress -Activity "Backup Job Check" -Status "Checking to see if $($vm.Name) is in a backup job (VM $($i) of $($vmCount))" -PercentComplete $percentComplete
    $vmFound=@()
    if ($checkBackupJobs) {
        foreach ($vminBackupJob in $vmsinBackupJob) {
            if ($vminBackupJob -eq $vm.Name) {
                $vmFound += "Found"
                Write-Verbose "Found $($vm.Name) In Backup Job $($backupJob.Name)"
            }
        }
    }
    else {
        foreach ($vmBackup in $vmBackups) {
            if ($vmBackups.Name -eq $vm.Name) {
                $vmFound += "Found"
                Write-Verbose "Found $($vm.Name) In Backup Job $($backupJob.Name)"
            }
        }
    }
    if (!$vmFound) {
        Write-Verbose "Could not find $($vm.Name) in a Backup Job"
        $vmList += $vm.Name
    }
}

if ($vmList){
    Write-Host "There are $($vmList.Count) VMs that are not in a backup job:" -ForegroundColor Cyan
    foreach ($vm in $vmList){
        Write-Host $vm -ForegroundColor Red
    }
}