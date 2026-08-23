param(
  [string]$ReleaseSha = ''
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Get-TextSha256([string]$Text) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($bytes)
  }
  finally {
    $algorithm.Dispose()
  }
  return ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = 'design/formal-beautification-foundation'

if ([string]::IsNullOrWhiteSpace($ReleaseSha)) {
  Write-Step 'Resolving current formal branch release SHA'
  git fetch origin $branch
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not fetch the formal branch.'
  }
  $ReleaseSha = ((git rev-parse "origin/$branch" | Out-String).Trim())
}

if ($ReleaseSha -notmatch '^[0-9a-fA-F]{40}$') {
  throw "ReleaseSha must be a full 40-character Git commit SHA. Received: $ReleaseSha"
}

$releasePrefix = $ReleaseSha.Substring(0, 7)
$hosts = @(
  'https://flutter-flow-pipe.web.app',
  'https://www.pipebuyer.com'
)

$markers = @(
  'Set service area on map',
  'Approximate home base:',
  'Fleet capabilities saved.',
  'Dispatch company profile saved.',
  'Sign in to use Dispatch.'
)

$bundleHashes = @{}
$bundleLengths = @{}
$releaseProofModes = @{}

Write-Host 'PIPE BUYER LIVE RELEASE VERIFICATION' -ForegroundColor Yellow
Write-Host "Expected release SHA: $ReleaseSha" -ForegroundColor Yellow

foreach ($hostName in $hosts) {
  Write-Step "Checking live Flutter bundle at $hostName"
  $url = "$hostName/main.dart.js?release=$ReleaseSha"
  $response = Invoke-WebRequest `
    -Uri $url `
    -UseBasicParsing `
    -TimeoutSec 45 `
    -Headers @{
      'Cache-Control' = 'no-cache'
      'Pragma' = 'no-cache'
    }

  if ($response.StatusCode -ne 200) {
    throw "$url returned HTTP $($response.StatusCode)."
  }

  $contentType = "$(($response.Headers['Content-Type']))".ToLowerInvariant()
  if (-not $contentType.Contains('javascript')) {
    throw "$url did not return JavaScript. Content-Type: $contentType"
  }

  $body = $response.Content
  if ([string]::IsNullOrWhiteSpace($body)) {
    throw "$url returned an empty JavaScript bundle."
  }

  if ($body.Contains($ReleaseSha)) {
    $releaseProofModes[$hostName] = 'full-sha'
  }
  elseif ($body.Contains($releasePrefix)) {
    $releaseProofModes[$hostName] = 'sha-prefix'
  }
  else {
    throw "$hostName bundle does not contain the expected compiled release SHA or seven-character prefix."
  }

  foreach ($marker in $markers) {
    if (-not $body.Contains($marker)) {
      throw "$hostName bundle is missing release marker text: $marker"
    }
  }

  $bundleHashes[$hostName] = Get-TextSha256 $body
  $bundleLengths[$hostName] = $response.RawContentLength

  Write-Host "Bundle bytes: $($response.RawContentLength)" -ForegroundColor Green
  Write-Host "Bundle SHA256: $($bundleHashes[$hostName])" -ForegroundColor Green
  Write-Host "Compiled release proof: $($releaseProofModes[$hostName])" -ForegroundColor Green
  Write-Host 'Dispatch feature markers: PASS' -ForegroundColor Green
}

$defaultHost = $hosts[0]
$customHost = $hosts[1]

if ($bundleHashes[$defaultHost] -ne $bundleHashes[$customHost]) {
  throw 'Firebase default host and www.pipebuyer.com are not serving the same Flutter bundle.'
}

Write-Step 'Checking public production routes'
foreach ($path in @('/', '/about', '/privacy', '/terms')) {
  $url = "https://www.pipebuyer.com$path"
  $response = Invoke-WebRequest `
    -Uri $url `
    -UseBasicParsing `
    -TimeoutSec 30 `
    -Headers @{
      'Cache-Control' = 'no-cache'
      'Pragma' = 'no-cache'
    }
  if ($response.StatusCode -ne 200) {
    throw "$url returned HTTP $($response.StatusCode)."
  }
  Write-Host "$url -> HTTP 200" -ForegroundColor Green
}

Write-Host ''
Write-Host '======================================================' -ForegroundColor Green
Write-Host ' PIPE BUYER VERIFIED WEB RELEASE IS LIVE' -ForegroundColor Green
Write-Host '======================================================' -ForegroundColor Green
Write-Host "Release SHA: $ReleaseSha" -ForegroundColor Green
Write-Host "Bundle SHA256: $($bundleHashes[$customHost])" -ForegroundColor Green
Write-Host "Bundle bytes: $($bundleLengths[$customHost])" -ForegroundColor Green
Write-Host "Release proof: $($releaseProofModes[$customHost])" -ForegroundColor Green
Write-Host 'Firebase default host: PASS' -ForegroundColor Green
Write-Host 'www.pipebuyer.com: PASS' -ForegroundColor Green
Write-Host 'Dispatch feature markers: PASS' -ForegroundColor Green
Write-Host 'Public routes: PASS' -ForegroundColor Green
