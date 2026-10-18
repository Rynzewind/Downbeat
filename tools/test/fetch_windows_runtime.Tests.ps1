$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$manifestPath = Join-Path $root 'tools\runtime\windows-runtime.json'

Describe 'Windows runtime manifest' {
  It 'pins HTTPS assets and SHA-256 digests' {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    foreach ($asset in $manifest.ytDlp, $manifest.ffmpeg) {
      $asset.url | Should Match '^https://'
      $asset.url | Should Not Match '/latest/'
      $asset.sha256 | Should Match '^[a-f0-9]{64}$'
      [string]::IsNullOrWhiteSpace($asset.version) | Should Be $false
    }
  }
}
