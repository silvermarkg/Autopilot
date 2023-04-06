
<#PSScriptInfo
.DESCRIPTION
 Gets the device name for an Autopilot registered device based on format.

.VERSION 1.0.0
.GUID 
.AUTHOR Mark Goodman (@silvermarkg)
.COMPANYNAME 
.COPYRIGHT 2023 Mark Goodman
.TAGS 
.LICENSEURI https://gist.github.com/silvermarkg/f58688cacdd51f9228441b8d124a6a03
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0.0 | 06-Apr-2023 | Initial script

#>

<#
  .SYNOPSIS
  Gets the device name for an Autopilot registered device based on format.

  .DESCRIPTION
  Calculates the device name for Azure AD joined Autopilot device, based on prefix and serial number. This is useful when using
  Hyper-V VMs and needing to determine the device name from the long serial number.

  .PARAMETER Prefix
  Specifiy the prefix for the device name (e.g. AAD-)
	
  .PARAMETER SerialNumber
  Specify the serial number of the device.

  .EXAMPLE
  Get-AutopilotDeviceName.ps1 -Prefix 'AAD-' -SerialNumber '1234-5678-9012-3456-7890-1234-56'

  Description
  -----------
  Returns the device name AAD-67890123456 based on the prefix and serial number.

  .EXAMPLE
  Get-AutopilotDeviceName.ps1 -SerialNumber '1234-5678-9012-3456-7890-1234-56'

  Description
  -----------
  Returns the device name 67890123456 based on the serial number.
 #> 

#region - Parameters
[Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [Parameter(Mandatory = $false)]
  [String]$Prefix = "",

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [String]$SerialNumber
)
#endregion - Parameters

#region - Script Environment
#Requires -Version 5
# #Requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
#endregion - Functions

#region - Variables
$ScriptBaseName = (Get-ChildItem -Path $PSCommandPath).BaseName
$LogFileName = "$($ScriptBaseName).log"
#endregion - Variables

#region - Script
# Remove non-alphanumeric characters from serial number
$sn = $SerialNumber -replace "[^a-zA-Z0-9]", ""

# Get name
$name = $Prefix + $sn.substring($sn.length - (15 - $Prefix.Length))

return $name
#endregion - Script