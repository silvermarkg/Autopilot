[CmdletBinding()]
param(
  [Parameter(Mandatory=$false,Position=0)]
  [ValidateNotNullOrEmpty()]
  [String]$GroupTag
)

# Variables
$USBDrive = (Get-CimInstance -Class Win32_DiskDrive -Filter 'InterfaceType = "USB"' -KeyOnly | Get-CimAssociatedInstance -Association Win32_DiskDriveToDiskPartition -KeyOnly | Get-CimAssociatedInstance -Association Win32_LogicalDiskToPartition).DeviceID
$serialNumber = (gwmi Win32_BIOS).SerialNumber
$ScriptFile = Join-Path -Path $PSScriptRoot -ChildPath "Get-WindowsAutoPilotInfo.ps1"
$hfPath = "$($USBDrive)\AutopilotHH\HashFiles"
if (Test-Path -Path $hfPath -PathType Container) {
  $hfFolder = Get-Item -Path $hfPath
}
else {
  $hfFolder = New-Item -Path $USBDrive\AutopilotHH -Name HashFiles -ItemType Directory -Force
}
$Path = $hfFolder.FullName
if ($PSBoundParameters.ContainsKey("GroupTag")) {
  $outFile1 = "$($Path)\$($GroupTag)_$($serialNumber).csv"
}
else {
  $outFile1 = "$($Path)\$($serialNumber).csv"
}
$outFile2 = "$($Path)\_AllHHs.csv"

# Determine if group tag specified
$GroupTagParam = ""
if ($PSBoundParameters.ContainsKey("GroupTag")) {
  $GroupTagParam  = @{
    GroupTag = $GroupTag
  }
}

# Get hardware hash
powershell -executionpolicy bypass -nologo -noprofile -file $ScriptFile @GroupTagParam -OutputFile $outFile1
powershell -executionpolicy bypass -nologo -noprofile -file $ScriptFile @GroupTagParam -OutputFile $outFile2 -append

# Shutdown if hash file exists and NoShutdown=$false
if (Test-Path -Path $outFile1 -PathType Leaf) {
  Start-Sleep -Seconds 2
  Stop-Computer
}
else {
  Write-Host -Object "Run Stop-Computer to shutdown the computer"
}
