param(
  [Parameter(Mandatory = $true)][string]$CurrentVersion,
  [Parameter(Mandatory = $true)][string]$ReleaseRepo,
  [Parameter(Mandatory = $true)][string]$StableAssetName,
  [Parameter(Mandatory = $true)][string]$AppName
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Parse-SemVer([string]$Value) {
  if ($Value -match '(\d+)\.(\d+)\.(\d+)') {
    return [version]("$($Matches[1]).$($Matches[2]).$($Matches[3])")
  }
  return $null
}

try {
  $current = Parse-SemVer $CurrentVersion
  if (-not $current) { exit 0 }

  try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$ReleaseRepo/releases/latest" -Headers @{ "User-Agent" = "$AppName-Installer" } -TimeoutSec 20
  } catch {
    Write-Output "Could not reach the release channel; continuing with this installer."
    exit 0
  }

  $latest = Parse-SemVer ([string]$release.tag_name)
  if (-not $latest -or $latest -le $current) {
    Write-Output "This installer is current."
    exit 0
  }

  $asset = $release.assets | Where-Object { $_.name -eq $StableAssetName } | Select-Object -First 1
  if (-not $asset) {
    Write-Output "A newer $AppName release exists, but its stable Windows installer asset is missing."
    exit 20
  }

  $destination = Join-Path $env:TEMP $StableAssetName
  Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
  Write-Output "A newer $AppName release ($latest) is available. Downloading it before installation..."
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $destination -UseBasicParsing -TimeoutSec 900

  if (-not (Test-Path -LiteralPath $destination) -or (Get-Item -LiteralPath $destination).Length -lt 1MB) {
    Write-Output "The newer installer download was incomplete."
    exit 20
  }

  $digest = [string]$asset.digest
  if ($digest -match '^sha256:(.+)$') {
    $expected = $Matches[1].ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
      Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
      Write-Output "The newer installer failed SHA-256 verification."
      exit 20
    }
  }

  Start-Process -FilePath $destination | Out-Null
  Write-Output "Opened the newest $AppName installer."
  exit 10
} catch {
  Write-Output ("Release check failed unexpectedly; continuing with this installer. " + $_.Exception.Message)
  exit 0
}
