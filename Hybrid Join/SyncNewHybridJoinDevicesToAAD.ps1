<#
  Script: SyncNewHybridJoinDevicesToAAD.ps1
  Author: Mark Goodman (based on script by Steve Prentice)
  Version: 1.00
  Date: 17-Mar-2022

  Update History
  --------------
  1.00 - Intiial script
  
  Notes:
  - Based on the script by Steve Prentice available at https://github.com/steve-prentice/autopilot/blob/master/SyncNewAutoPilotComputersandUsersToAAD.ps1
  - Script modified to suit targeted environment, add additional features and general tidy up

  Information:
  Triggers an ADDConnect Delta Sync if new objects are found to be have been created
  in the OU's in question, this is helpful to speed up Hybrid AD joined and helps avoid
  the AAD authentication prompt during Autopilot user phase.

  Only devices with a userCertificate attribute are synced by AAD Connect, so this script
  will only perform a delta sync it finds devices with this attribute set and that were 
  created in the last 5 hours (customisable) and have a modified time within the last 5 
  inutes (customisable).
  
  To install this script you can use the Install-SyncNewHybridJoinDevicesToAAD.ps1 or
  perform the following:
  - Create a scheduled task to run this script every x minutes, where x is the same as the period
    of time to check the modified date (default 5 mins)
  - Add an event source named 'Sync New Hybrid Join Devices' to the Application event log (you
    can use New-EventLog -LogName Application -Source "Sync New Hybrid Join Devices")
  - Change the $SourceOU variable in this script to match your environments
#>

[CmdletBinding()]
param (
    # CreatedTimeHours defines the period of time to include devices
    [Parameter(Mandatory = $false, Position = 0)]
    [Int16]$CreatedTimeHours = 5,

    # ModifiedTimeMinutes defines the  indicates a reboot return code (3010) should be returned
    [Parameter(Position = 1)]
    [Int16]$ModifiedTimeMinutes = 5
)

#region Functions
#endregion Functions

#region Main code
# Define variables
$SourceOU = "OU=Clients,DC=systems,DC=private"
$syncComputers = $false
$eventParams = @{
    LogName = "Application"
    Source = "Sync New Hybrid Join Devices"
    Category = 0
}

# Import Active Directory module
try {
    Import-Module ActiveDirectory
}
catch {
    # Write failure to application event log
    Write-EventLog -EntryType Error -EventId 2 -Message "Failed to load ActiveDirectory PowerShell module" @eventParams
    Exit 2
}

# Get computers modified in last x minutes and that have userCertificate value
try {
    $createdTime = [DateTime]::Now.AddHours(-5)
    $modifiedTime = [DateTime]::Now.AddMinutes(-5)
    $computers = Get-ADComputer -Filter 'Created -ge $createdTime -and Modified -ge $modifiedTime -and userCertificate -like "*"' -SearchBase $SourceOU
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
}
catch {
    # Write failure to application event log
    Write-EventLog -EntryType Error -EventId 2 -Message "Query against Active Directory failed" @eventParams
    Exit 2
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
#endregion Main code