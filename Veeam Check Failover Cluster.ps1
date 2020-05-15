# Version 1.1

# Import Veeam Snapin
asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue

# Get list of VMs in the Failover Cluster from Veeam
$vms = Find-VBRHvEntity | Where-Object {$_.Type -eq "Vm"} | Sort-Object Name
$backupJobs = Get-VBRJob
$vmList=@()
$vmCount = $vms.Count
$i = 0


foreach ($vm in $vms) {
    $i++
    $percentComplete = ($i / $vmCount) * 100
    Write-Progress -Activity "Backup Job Check" -Status "Checking to see if $($vm.Name) is in a backup job (VM $($i) of $($vmCount))" -PercentComplete $percentComplete
    $vmFound=@()
    foreach ($backupJob in $backupJobs) {
        $vmsinBackupJob = $backupJob.GetObjectsInJob().Name
        foreach ($vminBackupJob in $vmsinBackupJob) {
            if ($vminBackupJob -eq $vm.Name) {
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
    Write-Host "Found the following VMs which are not in a backup job:" -ForegroundColor Cyan
    foreach ($vm in $vmList){
        Write-Host $vm -ForegroundColor Red
    }
}