param(
  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [string]$CurrentInstallDir = ""
)

$ErrorActionPreference = "Stop"

function Format-Bytes([double]$Bytes) {
  if ($Bytes -ge 1TB) { return ("{0:N2} TB" -f ($Bytes / 1TB)) }
  if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
  return ("{0:N0} MB" -f ($Bytes / 1MB))
}

function Clean-IniValue([string]$Value) {
  if ($null -eq $Value) { return "" }
  return ($Value -replace "[\r\n]", " ").Trim()
}

$physicalById = @{}
try {
  Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
    $physicalById[[string]$_.DeviceId] = $_
  }
} catch {}

$drives = @()

Get-CimInstance Win32_LogicalDisk |
  Where-Object {
    $_.DeviceID -and
    $_.Size -gt 0 -and
    $_.DriveType -in 2, 3
  } |
  ForEach-Object {
    $logical = $_
    $letter = [string]$logical.DeviceID
    $root = "$letter\"
    $media = if ($logical.DriveType -eq 3) { "Fixed drive" } else { "Removable drive" }
    $speedRank = if ($logical.DriveType -eq 3) { 2 } else { 1 }

    $hasPhysicalPartition = $false
    try {
      $partition = Get-Partition -DriveLetter $letter.TrimEnd(":") -ErrorAction Stop | Select-Object -First 1
      $disk = $partition | Get-Disk -ErrorAction Stop
      $hasPhysicalPartition = $true
      $physical = $physicalById[[string]$disk.Number]
      $physicalMedia = if ($physical) { [string]$physical.MediaType } else { "" }
      $bus = [string]$disk.BusType

      if ($bus -eq "NVMe") {
        $media = "NVMe SSD"
        $speedRank = 4
      } elseif ($physicalMedia -eq "SSD") {
        $media = "SSD"
        $speedRank = 3
      } elseif ($physicalMedia -eq "HDD") {
        $media = "HDD"
        $speedRank = 2
      } elseif ($bus -eq "USB") {
        $media = "USB drive"
        $speedRank = 1
      } elseif ($bus) {
        $media = "$bus drive"
      }
    } catch {}

    if ($logical.DriveType -eq 3 -and -not $hasPhysicalPartition) {
      return
    }

    $probe = Join-Path $root (".foxmoss-write-test-" + [Guid]::NewGuid().ToString("N"))
    try {
      [IO.File]::WriteAllText($probe, "ok")
      Remove-Item -LiteralPath $probe -Force
    } catch {
      return
    }

    $label = Clean-IniValue ([string]$logical.VolumeName)
    $free = [double]$logical.FreeSpace
    $total = [double]$logical.Size
    $display = "$root  -  $media  -  $(Format-Bytes $free) free of $(Format-Bytes $total)"
    if ($label) { $display += "  -  $label" }

    $drives += [pscustomobject]@{
      Root = $root
      Display = $display
      FreeBytes = $free
      TotalBytes = $total
      SpeedRank = $speedRank
      IsFixed = [int]($logical.DriveType -eq 3)
    }
  }

if ($drives.Count -eq 0) {
  throw "No writable local drives were found."
}

$currentRoot = ""
if ($CurrentInstallDir -match '^([A-Za-z]:\\)') {
  $currentRoot = $Matches[1].ToUpperInvariant()
}

$ordered = @(
  $drives | Sort-Object @{ Expression = "IsFixed"; Descending = $true }, @{ Expression = "SpeedRank"; Descending = $true }, @{ Expression = "FreeBytes"; Descending = $true }
)

$recommendedRoot = $ordered[0].Root
$defaultRoot = if ($currentRoot -and ($ordered.Root -contains $currentRoot)) { $currentRoot } else { $recommendedRoot }

$visible = @($ordered | Select-Object -First 10)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("[General]")
$lines.Add("Count=$($visible.Count)")
$lines.Add("DefaultRoot=$(Clean-IniValue $defaultRoot)")
$lines.Add("RecommendedRoot=$(Clean-IniValue $recommendedRoot)")
$lines.Add("")

for ($i = 0; $i -lt $visible.Count; $i++) {
  $drive = $visible[$i]
  $lines.Add("[Drive$($i + 1)]")
  $lines.Add("Root=$(Clean-IniValue $drive.Root)")
  $lines.Add("Display=$(Clean-IniValue $drive.Display)")
  $lines.Add("Default=$([int]($drive.Root -eq $defaultRoot))")
  $lines.Add("Recommended=$([int]($drive.Root -eq $recommendedRoot))")
  $lines.Add("")
}

$encoding = New-Object System.Text.UnicodeEncoding($false, $true)
[IO.File]::WriteAllLines($OutputPath, $lines, $encoding)
