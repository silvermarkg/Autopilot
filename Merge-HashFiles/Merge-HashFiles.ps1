<#
Merges Autopilot hash CSV files into one for bulk import

Exmaples:
Merge-HashFiles.ps1 -Path C:\HashFiles
Above will merge all hash files found in the folder

Merger-HashFiles.ps1 -Path C:\HashFiles\ABC*.csv
Above will merge all ABC*.csv hash files found in folder
#>

param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [String]$Path
)

# Set import file path
if (Test-Path -Path $Path -PathType Container) {
  $ImportPath = $Path
}
else {
  $ImportPath = Split-Path -Path $Path -Parent
}

# Get hash file content and write to Import file
$Content = Get-Content -Path $Path
$Content[0] | Set-Content -Path $ImportPath
for ($i = 1; $i -lt $Content.Count; $i += 2) {
  $Content[$i] | Add-Content -Path $ImportPath
}
