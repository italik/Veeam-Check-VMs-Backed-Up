# Import Veeam Snapin
asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue

# Get list of VMs in the Failover Cluster from Veeam
$vms = Find-VBRHvEntity | Where-Object {$_.Type -eq "Vm"} | Sort-Object Name
$backupJobs = Get-VBRJob

foreach ($vm in $vms) {
    $vmFound=@()
    foreach ($backupJob in $backupJobs) {
        $vmsinBackupJob = $backupJob.GetObjectsInJob().Name
        foreach ($vminBackupJob in $vmsinBackupJob) {
            if ($vminBackupJob -eq $vm.Name) {
                $vmFound += "Found"
                Write-Host "Found $($vm.Name) In Backup Job" $backupJob.Name -ForegroundColor Green
            }
        }
    }
    if (!$vmFound) {
        Write-Host "Could not find $($vm.Name) in a Backup Job"
    }
}