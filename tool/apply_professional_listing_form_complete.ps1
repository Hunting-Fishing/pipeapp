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

$basePass = Join-Path $PSScriptRoot 'apply_professional_listing_form.ps1'
$compactor = Join-Path $PSScriptRoot 'compact_professional_listing_fields_v1.mjs'
$page = Join-Path $repoRoot 'lib\marketplace\oil_gas_marketplace.dart'
$presentation = Join-Path $repoRoot 'lib\marketplace\marketplace_listing_form_presentation.dart'
$presentationTest = Join-Path $repoRoot 'test\marketplace_listing_form_presentation_test.dart'
$timedBuyingTest = Join-Path $repoRoot 'test\marketplace_timed_buying_presentation_test.dart'

foreach ($required in @($basePass, $compactor, $page, $presentation, $presentationTest, $timedBuyingTest)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required professional listing-form file is missing: $required. Pull the latest formal branch first."
  }
}

Write-Step 'Running the verified professional listing-form foundation pass'
& powershell -ExecutionPolicy Bypass -File $basePass
if ($LASTEXITCODE -ne 0) {
  throw 'Professional listing-form foundation pass failed.'
}

$backup = Join-Path $env:TEMP "pipebuyer-listing-form-compact-$([guid]::NewGuid().ToString('N')).dart"
Copy-Item -LiteralPath $page -Destination $backup -Force
$completed = $false

try {
  Write-Step 'Syntax-checking compact industrial-field migration'
  & node --check $compactor
  if ($LASTEXITCODE -ne 0) {
    throw 'Compact industrial-field migration has a JavaScript syntax error.'
  }

  Write-Step 'Compacting category-aware industrial specification fields'
  & node $compactor
  if ($LASTEXITCODE -ne 0) {
    throw 'Compact industrial-field migration failed.'
  }

  Write-Step 'Formatting compact listing form'
  & dart format $page
  if ($LASTEXITCODE -ne 0) {
    throw 'dart format failed after compacting listing fields.'
  }

  Write-Step 'Analyzing final professional listing-form surface'
  & dart analyze $page $presentation $presentationTest $timedBuyingTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Dart analyzer failed for the final professional listing form.'
  }

  Write-Step 'Re-running listing-form widget contracts after field compaction'
  & flutter test $presentationTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-listing-form-complete
  if ($LASTEXITCODE -ne 0) {
    throw 'Listing-form widget tests failed after field compaction.'
  }

  Write-Step 'Re-running Timed Buying presentation regression contracts'
  & flutter test $timedBuyingTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-listing-form-complete
  if ($LASTEXITCODE -ne 0) {
    throw 'Timed Buying presentation tests failed after listing-form compaction.'
  }

  Write-Step 'Complete professional listing-form verification passed'
  git diff --stat
  git status --short
  Write-Host ''
  Write-Host 'Visual review: open Create Listing and switch between Marketplace, Timed Buying and Wanted Ad.' -ForegroundColor Green
  Write-Host 'For Timed Buying, verify quick durations, opening offer, seller minimum and Buy It Now presentation.' -ForegroundColor DarkGray
  $completed = $true
}
finally {
  if (-not $completed -and (Test-Path -LiteralPath $backup)) {
    Write-Host "`nCompact listing-field pass failed; restoring the already-verified professional form from before compaction." -ForegroundColor Red
    Copy-Item -LiteralPath $backup -Destination $page -Force
  }
  Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
}
