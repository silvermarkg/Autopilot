# WaitForUserDeviceRegistration

*Originally forked from Steve Prentice [https://github.com/steve-prentice/autopilot]*

Waits for hybrid join to fully complete, including Azure AD sync so that you can user user ESP. By default it will check for 60 minutes but you can use the `MaxWaitTime` parameter to specific a different period.

Package the WaitForUserDeviceRegistration.ps1 into a Win32 app (.intunewin) and deploy via Intune as required to the appropriate set of devices. Use the following values for the Win32 app:

**Install Command**
`powershell.exe -noprofile -executionpolicy bypass -file .\WaitForUserDeviceRegistration.ps1`

**Uninstall Command**
`powershell.exe -noprofile -executionpolicy bypass -command "Remove-Item -Path ""$($env:ProgramData)\DeviceRegistration\WaitForUserDeviceRegistration.tag"""`

**Detection Rule**
For a detection rule, specify the path and file and "File or folder exists" detection method:
`%ProgramData%\DeviceRegistration\WaitForUserDeviceRegistration.tag`

*Note: You also need my [https://github.com/silvermarkg/PowerShell/tree/main/Logging] module. Place the `Logging.psm1` module in the same folder as the WaitForUserDeviceRegistration.ps1 script*

# SyncNewHybridJoinDevicesToAAD

*Originally forked from Steve Prentice [https://github.com/steve-prentice/autopilot]*

The SyncNewHybridJoinDevicestoAAD script triggers an ADDConnect Delta Sync if new objects are found to be have been created in the OU in question, this is helpful to speed up Hybrid AD join and helps avoid the AAD authentication prompt during Autopilot user phase.

Only devices with a userCertificate attribute are synced by AAD Connect, so this script will only perform a delta sync it finds devices with this attribute set. To minimise the retured devices, this script searchs only for devices created in the last 5 hours (configurable using the `CreatedTimeHours` parameter) and that have been modified since the last time the script ran (first run is for devices modified in last 5 minutes).

To install this script you can use the `Install-SyncNewHybridJoinDevicesToAAD` script, which will run the scheduled task as SYSTEM.
  
Alternatively you can perform the following:
  - Create a scheduled task to run this script every 5 minutes. Ensure the account used to run
    the task is a member of the ADSyncOperators local group, has permissions to read computer 
    objects in the OU and has permissions to write to the '%ProgramData%\Sync New Hybrid Join Devices' 
    folder containing this script.
  - Add an event source named 'Sync New Hybrid Join Devices' to the Application event log
    (`New-EventLog -LogName Application -Source "Sync New Hybrid Join Devices"`)
