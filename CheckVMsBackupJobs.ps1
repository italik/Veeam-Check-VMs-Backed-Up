<#
    .SYNOPSIS
    This script allows you to check if there are VMs missing from a backup job when comparing it to a Hyper-V Server
    .DESCRIPTION
    Script outputs at the end which VMs are missing, and you can also use -verbose to get more output
    .EXAMPLE
    CheckVMsBackupJobs.ps1 -Environment HyperV -includeFailedBackupJobs -daysToCheck 1
    Includes failed backup jobs within the last 1 day where the environment is HyperV
    .EXAMPLE
    CheckVMsBackupJobs.ps1 -Environment VMware -daysToCheck 1
    Excludes failed backup jobs within the last 1 day where the environment is VMware
    .Notes
    NAME: CheckVMsBackupJobs.ps1
    VERSION: 1.1
    AUTHOR: Robert Milner (@robm82)
    .Link
    https://www.italik.co.uk
 #>


Param (
    [Parameter( Mandatory=$true )]
    [ValidateSet('HyperV','VMware')]
    [string[]]$Environment,

    [Parameter( Mandatory=$false )]
    [switch]$includeFailedBackupJobs,

    [Parameter( Mandatory=$false )]
    [string]$daysToCheck
)

# Import Veeam Snapin
Write-Host "Importing Veeam PowerShell Module" -ForegroundColor Magenta
asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue

$vms=@{}

# Get list of all VMs from Hyper-V according to Veeam
if ($Environment -eq "HyperV") {
    Write-Host "Getting list of all VMs from Hyper-V according to Veeam" -ForegroundColor Cyan
    Find-VBRHvEntity |
        Where-Object {$_.Type -eq "Vm"} |
        ForEach-Object {$vms.Add($_.ID, $_.Name)}
}
# Get list of all VMs from VMWare according to Veeam <- Not tested!
elseif ($Environment -eq "VMware"){
    Write-Host "Getting list of all VMs from virtualisation infrastructure according to Veeam" -ForegroundColor Cyan
    Find-VBRHvEntity |
        Where-Object {$_.Type -eq "Vm"} |
        ForEach-Object {$vms.Add($_.ID, $_.Name)}
}

Write-Host "Getting all backup task sessions" -ForegroundColor Cyan
# Find all backup task sessions in the last X days including failures
if ($includeFailedBackupJobs) {
    $vbrTaskSessions = (Get-VBRBackupSession |
        Where-Object {$_.JobType -eq "Backup" -and $_.EndTime -ge (Get-Date).AddDays(-$daysToCheck)}) |
        Get-VBRTaskSession
}
# Find all backup task sessions in the last X days excluding failures
else {
    $vbrTaskSessions = (Get-VBRBackupSession |
    Where-Object {$_.JobType -eq "Backup" -and $_.EndTime -ge (Get-Date).AddDays(-$daysToCheck)}) |
    Get-VBRTaskSession | Where-Object {$_.Status -ne "Failed"}
}

Write-Host "Checking VMs..." -ForegroundColor Cyan
$vmList=@()
foreach ($vm in $vms.GetEnumerator()) {
    $vmFound=@()
    foreach ($vmtask in $vbrTaskSessions) {
        if ($vm.Value -eq $vmtask.Name) {
            Write-Verbose "Found $($vm.Value) in backup job $($vmtask.JobSess.JobName)"
            $vmFound += "Found"
        }
    }
    if (!$vmFound) {
        Write-Verbose "Could not find $($vm.Value) in a Backup Job"
        $vmList += $vm.Value
    }
}

# Report on those VMs not in a backup job
if ($vmList){
    Write-Host "There are $($vmList.Count) VMs that are not in a backup job:" -ForegroundColor Cyan
    foreach ($item in $vmList){
        Write-Host $item -ForegroundColor Red
    }
}