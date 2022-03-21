<#
  .SYNOPSIS
  The SyncNewHybridJoinDevicestoAAD script triggers an ADDConnect Delta Sync if new objects are found to be have been created
  in the OU in question, this is helpful to speed up Hybrid AD join and helps avoid the AAD authentication prompt during Autopilot user phase.

  .DESCRIPTION
  Only devices with a userCertificate attribute are synced by AAD Connect, so this script
  will only perform a delta sync it finds devices with this attribute set. To minimise the
  retured devices, this script searchs only for devices created in the last 5 hours 
  (configurable using the -CreatedTimeHours parameter) and that have been modified since the
  last time the script ran (first run is for devices modified in last 5 minutes).
  
  To install this script you can use the Install-SyncNewHybridJoinDevicesToAAD script. Using this
  will set the scheduled task to run as SYSTEM.
  
  Alternatively you can perform the following:
  - Create a scheduled task to run this script every 5 minutes. Ensure the account used to run
    the task is a member of the ADSyncOperators local group, has permissions to read computer 
    objects in the OU and has permissions to write to the '%ProgramData%\Sync New Hybrid Join Devices' 
    folder containing this script.
  - Add an event source named 'Sync New Hybrid Join Devices' to the Application event log
    (New-EventLog -LogName Application -Source "Sync New Hybrid Join Devices"

  .PARAMETER OrgUnitDN
  The distinguised name of the organisational unit to search in. This OU and all sub-OUs will be searched

  .PARAMETER CreatedTimeHours
  Defines the number of hours to search back for newly created devies. Any device with a created time equal
  or greater will be included.
	
  .EXAMPLE
  SyncNewHybridJoinDevicestoAAD.ps1 -OrgUnit "OU=Computers,DC=domain,DC=com"
	
  Description
  -----------
  Searches the Computers OU for newly create hybrid join devices.

  .NOTES
  Author: Mark Goodman (based on script by Steve Prentice)
  Version: 1.00
  Date: 21-Mar-2022

  Update History
  --------------
  1.00 - Intiial script
  
  Notes
  -----
  - Based on the script by Steve Prentice available at https://github.com/steve-prentice/autopilot/blob/master/SyncNewAutoPilotComputersandUsersToAAD.ps1
  - Script modified to suit targeted environment and add additional functionality

  MIT LICENSE
  -----------
  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
#>

[CmdletBinding()]
param (
    # Distibguised name of source Organisational Unit
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$OrgUnitDN,

    # CreatedTimeHours defines the period of time to include devices
    [Parameter(Mandatory=$false,Position = 1)]
    [Int16]$CreatedTimeHours = 5
)

#region Functions
#endregion Functions

#region Main code
# Define variables
$initialModifiedTime = 5
$syncComputers = $false
$eventParams = @{
    LogName = "Application"
    Source = "Sync New Hybrid Join Devices"
    Category = 0
}
$settingsFile = "$($PSScriptRoot)\SyncNewHybridDevices.xml"

# Import Active Directory module
try {
    Import-Module ActiveDirectory
    Import-Module ADSync
}
catch {
    # Write failure to application event log
    Write-EventLog -EntryType Error -EventId 2 -Message "Failed to load ActiveDirectory or ADSync PowerShell modules" @eventParams
    Exit 2
}

# Skip if ADSync in progress (to avoid missing devices)
$syncScheduler = Get-ADSyncScheduler -ErrorAction SilentlyContinue
if ($null -eq $syncScheduler) {
    # Unable to get sync scheduler. Possibly permissions issue
    Write-EventLog -EntryType Error -EventId 2 -Message "Failed to query ADSync scheduler! Please check account has appropriate permissions" @eventParams
    Exit 2
}
elseif ($syncScheduler.SyncCycleInProgress) {
    # Sync currently in progress, skipping
    Write-EventLog -EntryType Information -EventId 1 -Message "ADSync cycle in progress, skipping search for new hybrid joing devices" @eventParams
}
else {
    # Define filter criteria
    if (Test-Path -Path $settingsFile -PathType Leaf) {
        # Use last end time as the start time
        $modifiedStartTime = Import-Clixml -Path $settingsFile
    }
    else {
        $modifiedStartTime = [DateTime]::Now.AddMinutes(-$initialModifiedTime)
    }
    $modifiedEndTime = [DateTime]::Now
    $createdTime = [DateTime]::Now.AddHours(-$CreatedTimeHours)
    $filter = 'Created -ge $createdTime -and Modified -ge $modifiedStartTime -and Modified -le $modifiedEndTime -and userCertificate -like "*"'

    # Search for matching devices
    try {
        $computers = Get-ADComputer -Filter $filter -SearchBase $OrgUnitDN
    }
    catch {
        # Write failure to application event log
        Write-EventLog -EntryType Error -EventId 2 -Message "Query against Active Directory failed" @eventParams
        Exit 2
    }
    if ($null -ne $computers) {
        # Get count of devices
        if ($computers -is [Array]) {
            $deviceCount = $computers.Count
        }
        else {
            $deviceCount = 1
        }

        # Set flag to sync computers
        $syncComputers = $true

        # Wait for 30 seconds to allow for some replication
        Start-Sleep -Seconds 30
    }

    # Save end time for next run
    try {
        $modifiedEndTime | Export-Clixml -Path $settingsFile -Force
    }
    catch {
        # Failed to write settings file
        Write-EventLog -EntryType Error -EventId 2 -Message "Failed to write $($settingsFile)" @eventParams
    }

    # sync computer if required
    if ($syncComputers) {
        try {
            # Write info to application event log
            Write-EventLog -EntryType Information -EventId 1 -Message "Found $($deviceCount) devices to sync, running delta sync" @eventParams
            
            # Run delta AD Connect sync cycle
            Start-ADSyncSyncCycle -PolicyType Delta
        }
        catch {
            # Write failure to application event log
            Write-EventLog -EntryType Error -EventId 2 -Message "Failed to run delta sync" @eventParams
            Exit 2
        }
    }
}
#endregion Main code