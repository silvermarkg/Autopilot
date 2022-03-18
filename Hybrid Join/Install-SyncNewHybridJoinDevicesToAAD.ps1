<#
  Script: Install-SyncNewHybridJoinDevicesToAAD.ps1
  Author: Mark Goodman
  Version: 1.00
  Date: 18-Mar-2022

  Update History
  --------------
  1.00 - Intiial script
  
  Notes:
  Installs SyncNewHybridJoinDevicesToAAD.ps1 script, including creation of scheduled task and event log source
#>

# Parameters
[CmdletBinding()]
param (
    # TaskRepetition defines the scheduled task repetition interval in minutes
    [Parameter(Mandatory=$false)]
    [Int16]$TaskRepetition = 5
)

#region Functions
#endregion Functions

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

# Create scheduled task
Write-Host -Object "Creating scheduled task '$($TaskName)'"
$stAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument " -ExecutionPolicy Bypass -File ""$($TargetPath)\$($ScriptName)"" -ModifiedTimeMinutes $TaskRepetition"
$stTrigger = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At $TriggerStartTime
#$stTrigger.ExecutionTimeLimit = (New-TimeSpan -Minutes 30)
$stTempTrigger = New-ScheduledTaskTrigger -Once -At $TriggerStartTime -RepetitionDuration (New-TimeSpan -Days 1) -RepetitionInterval (New-TimeSpan -Minutes $TaskRepetition)
$stTempTrigger.Repetition.StopAtDurationEnd = $false
$stTrigger.Repetition = $stTempTrigger.Repetition
$stPrincipal = New-ScheduledTaskPrincipal -UserId "LOCALSERVICE" -LogonType ServiceAccount
$stSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances Parallel -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName $TaskName -TaskPath "\" -Action $stAction -Trigger $stTrigger -Principal $stPrincipal -Settings $stSettings | Out-Null

# Creating event source
Write-Host -Object "Creating event source '$($TaskName)"
New-EventLog -LogName Application -Source $TaskName

Write-Host -Object "Done"
#endregion Main code