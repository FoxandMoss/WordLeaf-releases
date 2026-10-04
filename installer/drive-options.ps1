param(
  [Parameter(Mandatory=$true)][string]$OutputPath,
  [string]$CurrentInstallDir = ""
)
$ErrorActionPreference = "SilentlyContinue"
$rows = @()
$currentDrive = if ($CurrentInstallDir -match '^([A-Za-z]:)') { $Matches[1].ToUpper() } else { "" }

Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  $root = "$($_.DeviceID)\"
  if (-not $_.FileSystem -or $_.FileSystem -eq "CDFS") { return }
  if ($_.VolumeName -match '(?i)Google Drive|OneDrive|Dropbox|iCloud|Box') { return }

  $probe = Join-Path $root (".foxmoss-write-test-" + [Guid]::NewGuid().ToString("N"))
  $writable = $false
  try {
    [IO.File]::WriteAllText($probe, "ok")
    Remove-Item -LiteralPath $probe -Force
    $writable = $true
  } catch {}
  if (-not $writable) { return }

  $freeGb = if ($_.FreeSpace) { [math]::Round($_.FreeSpace / 1GB, 1) } else { 0 }
  $label = if ($_.VolumeName) { " — $($_.VolumeName)" } else { "" }
  $rows += [pscustomobject]@{
    Root = $root
    Display = "$($_.DeviceID)$label — $freeGb GB free"
    Default = [int]($_.DeviceID.ToUpper() -eq $currentDrive)
    Free = [double]$_.FreeSpace
  }
}

if (-not ($rows | Where-Object Default -eq 1)) {
  $best = $rows | Sort-Object Free -Descending | Select-Object -First 1
  if ($best) { $best.Default = 1 }
}
$rows = @($rows | Sort-Object @{Expression='Default';Descending=$true}, @{Expression='Free';Descending=$true})

"[General]" | Set-Content -LiteralPath $OutputPath -Encoding ASCII
"Count=$($rows.Count)" | Add-Content -LiteralPath $OutputPath -Encoding ASCII
for ($i=0; $i -lt $rows.Count; $i++) {
  "" | Add-Content -LiteralPath $OutputPath -Encoding ASCII
  "[Drive$($i+1)]" | Add-Content -LiteralPath $OutputPath -Encoding ASCII
  "Root=$($rows[$i].Root)" | Add-Content -LiteralPath $OutputPath -Encoding ASCII
  "Display=$($rows[$i].Display)" | Add-Content -LiteralPath $OutputPath -Encoding ASCII
  "Default=$($rows[$i].Default)" | Add-Content -LiteralPath $OutputPath -Encoding ASCII
}
