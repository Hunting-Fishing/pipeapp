$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This helper is for design/formal-beautification-foundation. Current branch: $branch"
}

$timedPage = Join-Path $repoRoot 'lib\marketplace\marketplace_auctions_page.dart'
$marketplacePage = Join-Path $repoRoot 'lib\marketplace\oil_gas_marketplace.dart'
if (-not (Test-Path -LiteralPath $timedPage) -or -not (Test-Path -LiteralPath $marketplacePage)) {
  throw 'Marketplace source files are missing. Pull the latest formal branch first.'
}

$timedSource = Get-Content -LiteralPath $timedPage -Raw
if (-not $timedSource.Contains('Review & submit timed offer')) {
  throw 'The verified Timed Buying migration is not present. Apply that migration first.'
}

if (-not $timedSource.Contains("title: 'Asset overview'")) {
  Write-Step 'Applying compact professional Timed Buying asset details'
  & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'apply_compact_timed_buying_details.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'Compact Timed Buying detail pass failed.' }
} else {
  Write-Host 'Compact Asset overview already present.' -ForegroundColor DarkGray
}

$marketplaceSource = Get-Content -LiteralPath $marketplacePage -Raw
if (-not $marketplaceSource.Contains('WHERE SHOULD THIS APPEAR?')) {
  Write-Step 'Applying professional category-aware Create Listing form'
  & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'apply_professional_listing_form.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'Professional Create Listing pass failed.' }
} else {
  Write-Host 'Professional Create Listing destination selector already present.' -ForegroundColor DarkGray
}

$timedSource = Get-Content -LiteralPath $timedPage -Raw
if ($timedSource.Contains('TimedBuyingUrgencyFrame(')) {
  Write-Step 'Applying stronger Timed Buying urgency + buyer-position treatment'
  & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'apply_timed_buying_attention.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying attention pass failed.' }
} elseif ($timedSource.Contains('TimedBuyingAttentionFrame(')) {
  Write-Host 'Enhanced Timed Buying attention frame already present.' -ForegroundColor DarkGray
} else {
  throw 'No recognized Timed Buying urgency frame was found.'
}

$ports = @(19099, 18080, 15001, 19199)
$ready = @($ports | Where-Object {
  $null -ne (Get-NetTCPConnection -State Listen -LocalPort $_ -ErrorAction SilentlyContinue |
    Select-Object -First 1)
}).Count -eq $ports.Count

if ($ready) {
  Write-Step 'Reseeding deterministic marketplace fixtures with Timed Buying public language'
  & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'reseed_formal_test_data.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'Formal sandbox reseed failed after visual pass.' }
} else {
  Write-Host 'Firebase emulator suite is not fully running; reseed skipped.' -ForegroundColor Yellow
}

Write-Step 'Reviewed marketplace visual pass complete'
Write-Host 'Hot reload the running Flutter client, or relaunch http://127.0.0.1:5050.' -ForegroundColor Green
Write-Host 'Review Create Listing, the Timed Buying board, one live detail page, and Timed Offer Activity before committing.' -ForegroundColor DarkGray
