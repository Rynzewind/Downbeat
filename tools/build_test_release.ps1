[CmdletBinding()]
param(
  [switch]$PreflightOnly,
  [switch]$UseExistingBuilds
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$client = Join-Path $root 'apps\client'
$flutter = 'C:\DownbeatTools\flutter\bin\flutter.bat'
$apk = Join-Path $client 'build\app\outputs\flutter-apk\app-debug.apk'
$windows = Join-Path $client 'build\windows\x64\runner\Release'
$runtime = Join-Path $windows 'runtime'
$dist = Join-Path $root 'dist'

function Assert-File([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required build file: $Path" }
}

function Test-BuildInputs {
  Assert-File (Join-Path $client 'windows\runtime\yt-dlp.exe')
  Assert-File (Join-Path $client 'windows\runtime\ffmpeg.exe')
  $manifest = Get-Content -Raw (Join-Path $client 'android\app\src\main\AndroidManifest.xml')
  if ($manifest -notmatch 'DownbeatDownloadService') { throw 'Android foreground service declaration is missing' }
  if ((Get-Content -Raw (Join-Path $client 'pubspec.yaml')) -notmatch 'name: downbeat') { throw 'Downbeat branding is missing' }
}

Test-BuildInputs
if ($PreflightOnly) { Write-Host 'Downbeat packaging preflight passed'; exit 0 }

if (-not $UseExistingBuilds) {
  & (Join-Path $root 'tools\fetch_windows_runtime.ps1')
  Push-Location $client
  try {
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed' }
    $env:ANDROID_HOME = 'C:\DownbeatTools\android-sdk'
    $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
    $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
    & $flutter build apk --debug --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }
    & $flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
  } finally { Pop-Location }
}

Assert-File $apk
Assert-File (Join-Path $windows 'Downbeat.exe')
Assert-File (Join-Path $runtime 'yt-dlp.exe')
Assert-File (Join-Path $runtime 'ffmpeg.exe')
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$androidOut = Join-Path $dist 'Downbeat-android-arm64-test.apk'
$windowsOut = Join-Path $dist 'Downbeat-windows-x64-test.zip'
Copy-Item -LiteralPath $apk -Destination $androidOut -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\THIRD-PARTY-NOTICES.md') -Destination (Join-Path $windows 'THIRD-PARTY-NOTICES.md') -Force
Compress-Archive -Path (Join-Path $windows '*') -DestinationPath $windowsOut -CompressionLevel Optimal -Force
$hashes = foreach ($artifact in $androidOut, $windowsOut) {
  $hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
  "$($hash.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($artifact))"
}
Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Value $hashes -Encoding ascii
Write-Host "Downbeat test builds are ready in $dist"
