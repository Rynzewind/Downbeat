[CmdletBinding()]
param(
  [string]$Destination = (Join-Path $PSScriptRoot '..\apps\client\windows\runtime'),
  [string]$Cache = (Join-Path $PSScriptRoot '..\.tooling\windows-runtime')
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $PSScriptRoot 'runtime\windows-runtime.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $Cache, $Destination | Out-Null

function Get-VerifiedAsset {
  param([string]$Name, [string]$Url, [string]$Sha256)
  $target = Join-Path $Cache $Name
  if (-not (Test-Path -LiteralPath $target) -or
      (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $Sha256) {
    Invoke-WebRequest -Uri $Url -OutFile $target -UseBasicParsing
  }
  $actual = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $Sha256.ToLowerInvariant()) {
    Remove-Item -LiteralPath $target -Force
    throw "Checksum mismatch for $Name"
  }
  return $target
}

$ytDlp = Get-VerifiedAsset -Name 'yt-dlp.exe' -Url $manifest.ytDlp.url -Sha256 $manifest.ytDlp.sha256
$ffmpegArchive = Get-VerifiedAsset -Name 'ffmpeg.zip' -Url $manifest.ffmpeg.url -Sha256 $manifest.ffmpeg.sha256
Copy-Item -LiteralPath $ytDlp -Destination (Join-Path $Destination 'yt-dlp.exe') -Force

$extract = Join-Path $Cache 'ffmpeg-extracted'
if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
Expand-Archive -LiteralPath $ffmpegArchive -DestinationPath $extract -Force
foreach ($name in 'ffmpeg.exe', 'ffprobe.exe', 'LICENSE.txt') {
  $source = Get-ChildItem -LiteralPath $extract -Recurse -File -Filter $name | Select-Object -First 1
  if (-not $source) { throw "FFmpeg archive is missing $name" }
  Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $Destination $name) -Force
}
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $Destination 'windows-runtime.json') -Force
Write-Host "Verified Windows runtime staged at $Destination"
