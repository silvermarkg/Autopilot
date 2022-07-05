<#PSScriptInfo

.VERSION 1.51

.GUID 6d57e471-104f-4165-aca1-e0c0174fd226

.AUTHOR Michael Niehaus (Updated by Mark Goodman)

.COMPANYNAME Microsoft

.COPYRIGHT 

.TAGS Windows AutoPilot

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.51: Added ability to search for specific serial number
Version 1.5:  Added additional group tag checking logic.
Version 1.4:  Updated authentication logic.
Version 1.3:  Original public version.

#>

<#
.SYNOPSIS
Verfies that all Autopilot-related devices (from the Autopilot service, Inune, and Azure AD) are all in sync, with the ability to fix them
if they aren't.
.DESCRIPTION
This script checks all the Autopilot-related devices to make sure that they are named correctly, have the right attributes (e.g. Group Tag
and Purchase Order ID), and aren't redundant (e.g. because the device has been deployed multiple times, creating a new Hybrid AADJ device
each time).  By default, this script will just display information about what isn't in sync.  If you want it to actually fix it, you have
to specify additional command line paraemters.  At present, extra Hybrid Azure AD devices can be removed from Active Directory (with 
-CleanDevices switch) and device name issues can be fixed (with -FixNames).

Due to the amount of data this will retrieve, it is possible this won't work for large tenants due to Graph API throttling. 
.PARAMETER CleanDevices
Switch that specifies to automatically remove extra device from Active Directory.  This requires that the script is running as an account
that has access to Active Directory (e.g. a Domain Admin account) and on a server or workstation with the ActiveDirectory module. 
.PARAMETER FixNames
Switch that specifies to correct any Azure AD (AzureAd) devices that have names that don't match the Intune device that it is associated
with.  This would typically happen in a Hybrid AADJ scenario where the device was renamed (locally and in AD) after the device was deployed.
.EXAMPLE
Report on any issues:

.\AutopilotDeviceSync.ps1
.EXAMPLE
Report on issues and fix those that can be fixed:

.\AutopilotDeviceSync.ps1 -CleanDevices -FixNames
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)] [ValidateNotNullOrEmpty()] [String] $SerialNumber = "*",
	[Parameter(Mandatory=$False)] [Switch] $CleanDevices = $false,
	[Parameter(Mandatory=$False)] [Switch] $FixNames = $false
)

Process {

    Import-Module WindowsAutopilotIntune -Scope Global
    Import-Module AzureAD -Scope Global
    $intuneId = Connect-MSGraph
    $aadId = Connect-AzureAD -AccountId $intuneId.UPN

    # Determine which Autopilot devices to process
    if ($SerialNumber -ne "*") {
        # Get specific device (by serial number)
        $AutopilotParams = @{
            Serial = $SerialNumber
        }
    }

    # Data gathering
    Write-Host -Object "Gathering devices..."
    $autopilotDevices = Get-AutopilotDevice @AutopilotParams | Get-MSGraphAllPages
    $aadDevices = Get-AzureADDevice -All $true
    $intuneDevices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Windows')" | Get-MSGraphAllPages

    # Maintain a list of devices to remove
    $extra = @()

    # Process each Autopilot device
    $autopilotDevices | % {

        # Find the objects linked to the Autopilot device
        $currentAutopilotDevice = $_
        $relatedIntuneDevice = $intuneDevices | ? { $_.id -eq $currentAutopilotDevice.managedDeviceId }
        $relatedAadDevice = $aadDevices | ? { $_.DeviceId -eq $currentAutopilotDevice.azureActiveDirectoryDeviceId }
        $relatedIntuneAadDevice = $aadDevices | ? { $_.DeviceId -eq $relatedIntuneDevice.azureADDeviceId }

        # Find all the Azure AD devices with the ZTDID of this Autopilot device
        $matchedDevices = $aadDevices | ? { $_.DevicePhysicalIds -match $currentAutopilotDevice.Id }

        # Display a summary for this device
        Write-Host "$($currentAutopilotDevice.SerialNumber):"
        Write-Host "  Au:AAD     = $($relatedAadDevice.DisplayName) [$($relatedAadDevice.DeviceTrustType)]"
        Write-Host "  Au:Intune  = $($relatedIntuneDevice.DeviceName)"
        Write-Host "  Intune:AAD = $($relatedIntuneAadDevice.DisplayName) [$($relatedIntuneAadDevice.DeviceTrustType)]"

        # If there are no devices in AAD with this ZTDID, the pre-created device was removed - that's bad
        if ($matchedDevices.Count -eq 0) {
            Write-Host "  No AAD devices found with the ZTDID" -ForegroundColor Red
        }
        else {

            # We would normally expect one AAD device for AAD Join scenarios, and two for Hybrid AAD Join scenarios, but there can be more
            Write-Host "  $($matchedDevices.Count) devices found with the ZTDID"

            # Check if Intune and Autopilot are linked to the same AAD device.  With Hybrid AADJ, they are typically different.
            if ($relatedIntuneDevice)
            {
                if ($relatedIntuneDevice.azureADDeviceId -ne $relatedAadDevice.DeviceId)
                {
                    Write-Host "  Intune and Autopilot are linked to different AAD devices"
                }
                elseif ($relatedIntuneDevice.DeviceName -ne $relatedAadDevice.DisplayName)
                {
                    # This can be fixed later
                    Write-Host "  Intune and AAD device names do not match" -ForegroundColor Yellow
                }
            }

            $matchedDevices | % {

                # Make sure the ZTDID-matched AAD device ($_) is the one associated with the Intune object
                if ($relatedIntuneDevice -and ($_.DeviceId -eq $relatedIntuneDevice.azureADDeviceId))
                {
                    Write-Host "  AAD:Intune object match $($_.DisplayName) $($_.DeviceTrustType)"
                }
                # Make sure the ZTDID-matched AAD device ($_) is the one associated with the Autopilot object
                elseif ($_.DeviceId -eq $currentAutopilotDevice.azureActiveDirectoryDeviceId)
                {
                    Write-Host "  AAD:Au object match $($_.DisplayName) $($_.DeviceTrustType)"
                }
                # Otherwise, this is an extra object
                else
                {
                    if ($relatedIntuneDevice -and ($relatedIntuneDevice.DeviceName -eq $_.DisplayName))
                    {
                        Write-Host "  Found match on Intune device name, not safe to remove"
                    }
                    elseif ($_.DeviceTrustType -eq 'ServerAd')
                    {
                        Write-Host "  Extra Hybrid AADJ device $($_.DisplayName) $($_.DeviceTrustType)" -ForegroundColor Yellow
                        $extra += $_
                    }
                    else
                    {
                        Write-Host "  Extra AAD device $($_.DisplayName) $($_.DeviceTrustType), manually remove" -ForegroundColor Yellow
                    }
                }

                # Check the device name (assuming the Intune device has the right name, which is typically the case)
                if ($_.DeviceTrustType -eq 'AzureAd') {
                    if ($relatedIntuneDevice) {
                        if ($relatedIntuneDevice.deviceName -ne $_.DisplayName)
                        {
                            Write-Host "  AAD name mismatch $($relatedIntuneDevice.deviceName) $($_.DisplayName)" -ForegroundColor Yellow
                            if ($FixNames)
                            {
                                Set-AzureADDevice -ObjectId $_.ObjectId -DisplayName $relatedIntuneDevice.deviceName
                            }
                        }
                    }
                }

                # Check if the device has the expected attributes, if not already marked for removal
                if (-not ($extra -contains $_))
                {
                    if ($currentAutopilotDevice.groupTag)
                    {
                        if (-not ($_.DevicePhysicalIds -match "\[OrderID\]:$($currentAutopilotDevice.groupTag)")) {
                            Write-Host "  GroupTag missing from AAD device $($_.DisplayName) $($_.DeviceTrustType)" -ForegroundColor Yellow
                        }
                    }
                    else 
                    {
                        if ($_.DevicePhysicalIds -match "\[OrderID\]:") {
                            Write-Host "  GroupTag should not be on AAD device $($_.DisplayName) $($_.DeviceTrustType)" -ForegroundColor Yellow
                        }
                    }
                    if ($currentAutopilotDevice.purchaseOrderIdentifier)
                    {
                        if (-not ($_.DevicePhysicalIds -match "\[PurchaseOrderID\]:$($currentAutopilotDevice.purchaseOrderIdentifier)")) {
                            Write-Host "  PurchaseOrderId missing from AAD device $($_.DisplayName) $($_.DeviceTrustType)" -ForegroundColor Yellow
                        }
                    }
                    else 
                    {
                        if ($_.DevicePhysicalIds -match "\[PurchaseOrderID\]:") {
                            Write-Host "  PurchaseOrderId should not be on AAD device $($_.DisplayName) $($_.DeviceTrustType)" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
    }

    # Remove extra devices
    Write-Host " "
    if ($CleanDevices)
    {
        Write-Host "Removing unused (ZTDID-matched) Hybrid Azure AD Join devices from Active Directory:"
        $extra | % {
            Write-Host "  $($_.DisplayName)"
            # First try to remove it from AD so the deletion can sync to AAD
            $current = $_
            try {
                Get-ADComputer -Identity $current.DisplayName | Remove-ADObject -Recursive -Confirm:$false
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                # If the deletion failed from AD because it wasn't found, just remove it from AAD directly
                Remove-AzureADDevice -ObjectId $current.ObjectId
            }
        }
    }
    else {
        Write-Host "Hybrid Azure AD Join (ServerAd) devices that can be removed from Active Directory:"
        $extra | % {
            # Make sure we can retrieve the AD device object
            $_.DisplayName
        }
    }

}
