<#
  Script: WaitForUserDeviceRegistration.ps1
  Author: Mark Goodman (based on script by Steve Prentice)
  Version: 1.02
  Date: 21-Mar-2022

  Update History
  --------------
  1.02 - Improved logging and wait times
  1.01 - Added logging module for improved logging and reduced check to every 5 mins instead of 1 min
  1.00 - Intiial script
  
  Notes:
  - Based on the script by Steve Prentice available at https://github.com/steve-prentice/autopilot/blob/master/WaitForUserDeviceRegistration.ps1
  - Script modified to suit targeted environment (Cisco AnyConnect), add additional features and general tidy up

  Information:
  Used to pause device ESP during Autopilot Hybrid Join to wait for
  the device to sucesfully register into AzureAD before continuing.

  Intended to be wrapped using IntuneWinAppUtil and deployed as a Windows app (Win32).
#>

[CmdletBinding()]
param (
    # MaxWaitTime defines the maximum time (in minutes) to wait for device registration before exiting
    [Parameter(Mandatory=$false,Position=0)]
    [Int16]$MaxWaitTime = 60,

    # Reboot indicates a reboot return code (3010) should be returned
    [Parameter(Position=1)]
    [Switch]$Reboot
)

# Define variables
$TaskPath = "\Microsoft\Windows\Workplace Join\"
$TaskName = "Automatic-Device-Join"
$LogPath = "$($env:Temp)\WaitForUserDeviceRegistraion.log"
$TagFile = "$($env:ProgramData)\DeviceRegistration\WaitForUserDeviceRegistration.tag"

# Create a tag file just so Intune knows this was installed (used for Win32 app detection logic)
New-Item -Path $TagFile -ItemType File -Force | Out-Null

# Start logging
Import-Module -Name "$($PSScriptRoot)\Logging.psm1"
Write-LogEntry -Message "Starting..." -Severity Information -Path $LogPath

# Define events
$filterRegistrationFailed = @{
  LogName = 'Microsoft-Windows-User Device Registration/Admin'
  Id = '304' # Automatic registration failed at join phase
}

$filterRegistrationSuccess = @{
  LogName = 'Microsoft-Windows-User Device Registration/Admin'
  Id = '306' # Automatic registration Succeeded
}

$filterNoDomainController = @{
  LogName = 'Microsoft-Windows-User Device Registration/Admin'
  Id = '334' # Automatic device join pre-check tasks completed. The device can NOT be joined because a domain controller could not be located.
}

$filterAlreadyJoined = @{
  LogName = 'Microsoft-Windows-User Device Registration/Admin'
  Id = '335' # Automatic device join pre-check tasks completed. The device is already joined.
}

$filterAnyConnectVPNEstablished = @{
  LogName = 'Cisco AnyConnect Secure Mobility Client'
  Id = '2039' # The management VPN connection has been established and can now pass data
}

# Wait for up to 60 minutes, re-checking every 5 minutes...
$timer = 0
While (($timer -lt $MaxWaitTime) -and (-Not $exitWhile)) {
    # Let's get some events...
    Write-LogEntry -Message "Collecting events" -Severity Information -Path $LogPath
    $eventsRegistrationFailed = Get-WinEvent -FilterHashtable $filterRegistrationFailed -MaxEvents 1 -EA SilentlyContinue
    $eventsRegistrationSuccess = Get-WinEvent -FilterHashtable $filterRegistrationSuccess -MaxEvents 1 -EA SilentlyContinue
    $eventsNoDomainController = Get-WinEvent -FilterHashtable $filterNoDomainController -MaxEvents 1 -EA SilentlyContinue
    $eventsAlreadyJoined = Get-WinEvent -FilterHashtable $filterAlreadyJoined -MaxEvents 1 -EA SilentlyContinue
    #$events20225 = Get-WinEvent -FilterHashtable $filter20225 -MaxEvents 1 -EA SilentlyContinue
    $eventsAnyConnectVPNEstablished = Get-WinEvent -FilterHashtable $filterAnyConnectVPNEstablished -MaxEvents 1 -EA SilentlyContinue

    # Process events
    if ($eventsAlreadyJoined -or $eventsRegistrationSuccess) {
      Write-LogEntry -Message "Device registration completed successfully" -Severity Information -Path $LogPath
      $exitWhile = $true
    }
    elseif ($eventsNoDomainController -and $eventsAnyConnectVPNEstablished -and -not $eventsRegistrationFailed) {
      Write-LogEntry -Message "VPN tunnel established, running Automatic-Device-Join task to create userCertificate" -Severity Information -Path $LogPath
      Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
      Write-LogEntry -Message "Waiting 2 minutes for task to process..." -Severity Information -Path $LogPath
      Start-Sleep -Seconds 120
      $timer+= 2
    }
    elseif ($eventsRegistrationFailed) {
      Write-LogEntry -Message "Running Automatic-Device-Join task again" -Severity Information -Path $LogPath
      Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
      Write-LogEntry -Message "Waiting 2 minutes for task to process..." -Severity Information -Path $LogPath
      Start-Sleep -Seconds 120
      $timer += 2
    }
    else {
      Write-LogEntry -Message "No events indicating successful device registration with Azure AD" -Severity Warning -Path $LogPath
      Write-LogEntry -Message "Waiting 1 minute for additional events..." -Severity Information -Path $LogPath
      Start-Sleep -Seconds 60
      $timer+= 1
    }

    # Write timeout time remaining
    if (-Not $exitWhile) {
      Write-LogEntry -Message "Running for $($timer.toString()) minutes" -Severity Information -Path $LogPath
      Write-EventLog -Message "Timeout in $(($MaxWaitTime - $timer).toString()) minutes" -Severity Information -Path $LogPath
    }
}

# Update log when device registration process succeeded
if ($eventsRegistrationSuccess) { 
  Write-LogEntry -Message $eventsRegistrationSuccess.Message -Severity Information -Path $LogPath
}

# Update log if device already joined to Azure AD
if ($eventsAlreadyJoined) {
  Write-LogEntry -Message $eventsAlreadyJoined.Message -Severity Information -Path $LogPath
}

# Exit script
if ($Reboot) {
  Exit 3010
}
else {
  Exit 0
}