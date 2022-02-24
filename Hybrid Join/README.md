# WaitForUserDeviceRegistration

*Originally forked from Steve Prentice https://github.com/steve-prentice/autopilot*

Waits for hybrid join to fully complete, including Azure AD sync so that you can user user ESP. By default it will check for
60 minutes but you can use the `MaxWaitTime` parameter to specific a different period.

Package the WaitForUserDeviceRegistration.ps1 into a Win32 app (.intunewin) and deploy via Intune as required to the appropriate set of devices. Use the following values for the Win32 app:

**Install Command**
`powershell.exe -noprofile -executionpolicy bypass -file .\WaitForUserDeviceRegistration.ps1`

**Uninstall Command**
`powershell.exe -noprofile -executionpolicy bypass -command "Remove-Item -Path ""$($env:ProgramData)\DeviceRegistration\WaitForUserDeviceRegistration.tag"""`

**Detection Rule**
For a detection rule, specify the path and file and "File or folder exists" detection method:
`%ProgramData%\DeviceRegistration\WaitForUserDeviceRegistration.tag`
