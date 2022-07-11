<#
  Script: Install-SyncNewHybridJoinDevicesToAAD.ps1
  Author: Mark Goodman
  Version: 1.02
  Date: 11-Jul-2022

  Update History
  --------------
  1.02 - Changed scheduled task to not run if missed scheduled time as this is running frequently anyway
  1.01 - Changed scheduled task to ignore new task if already running to prevent issues
  1.00 - Intiial script
  
  Notes:
  Installs SyncNewHybridJoinDevicesToAAD.ps1 script, including creation of scheduled task and event log source
#>

# Parameters
[CmdletBinding()]
param (
    # Distibguised name of source Organisational Unit
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [String]$OrgUnitDN,

    # TaskRepetition defines the scheduled task repetition interval in minutes
    [Parameter(Mandatory=$false)]
    [Int16]$TaskRepetition = 5
)

#region Functions
#endregion Functions

#region Script environment
#Requires -RunAsAdministrator
#endregion Script environment

#region Main code
# Define variables
$ScriptName = "SyncNewHybridJoinDevicesToAAD.ps1"
$SourceScriptPath = "$($PSScriptRoot)\$($ScriptName)"
$TargetPath = "$($env:ProgramData)\Sync New Hybrid Join Devices"
$TaskName = "Sync New Hybrid Join Devices"
$TriggerStartTime = Get-Date -Hour 0 -Minute 0 -Second 0

# Create target path if it does not exist
if (-Not (Test-Path -Path $TargetPath -PathType Container)) {
    Write-Host -Object "Creating folder $($TargetPath)"
    New-Item -Path $TargetPath -ItemType Directory | Out-Null
}

# Copy script file
if (Test-Path -Path $SourceScriptPath -PathType Leaf) {
    Write-Host -Object "Copying script $($SourceScriptPath)"
    Copy-Item -Path $SourceScriptPath -Destination $TargetPath -Force
}

# Configure scheduled task
Write-Host -Object "Creating scheduled task '$($TaskName)'"
$stAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument " -ExecutionPolicy Bypass -File ""$($TargetPath)\$($ScriptName)"" -OrgUnitDN ""$($OrgUnitDN)"""
$stTrigger = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At $TriggerStartTime
$stTempTrigger = New-ScheduledTaskTrigger -Once -At $TriggerStartTime -RepetitionDuration (New-TimeSpan -Days 1) -RepetitionInterval (New-TimeSpan -Minutes $TaskRepetition)
$stTempTrigger.Repetition.StopAtDurationEnd = $false
$stTrigger.Repetition = $stTempTrigger.Repetition
$stPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
$stSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

# Register scheduled task
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    $existingTask | Unregister-ScheduledTask -Confirm:$false
}
Register-ScheduledTask -TaskName $TaskName -TaskPath "\" -Action $stAction -Trigger $stTrigger -Principal $stPrincipal -Settings $stSettings | Out-Null

# Creating event source
Write-Host -Object "Creating event source '$($TaskName)"
New-EventLog -LogName Application -Source $TaskName -ErrorAction SilentlyContinue

Write-Host -Object "Done"
#endregion Main code