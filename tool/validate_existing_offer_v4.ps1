$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

Write-Step 'Checking Pipe Buyer sandbox branch'
$branch = (git branch --show-current).Trim()
if ($branch -ne 'pipebuyer-premium-ui') {
  throw "This validator is only for pipebuyer-premium-ui. Current branch: $branch"
}

$marketplace = 'lib/marketplace/oil_gas_marketplace.dart'
$analysis = 'lib/marketplace/marketplace_offer_analysis.dart'
$summary = 'lib/marketplace/marketplace_offer_commerce_summary.dart'
$backupDir = Join-Path $repoRoot '_local_backups'
New-Item -ItemType Directory -Force $backupDir | Out-Null
Copy-Item -LiteralPath $marketplace -Destination (Join-Path $backupDir 'oil_gas_marketplace_before_v4_validation.dart') -Force
Copy-Item -LiteralPath $analysis -Destination (Join-Path $backupDir 'marketplace_offer_analysis_before_v4_validation.dart') -Force

Write-Step 'Normalizing the existing local V4 offer patch'
& node '.\tool\fix_existing_offer_v4.mjs'
if ($LASTEXITCODE -ne 0) { throw 'Existing V4 normalization failed.' }

Write-Step 'Formatting the offer files'
& dart format $marketplace $analysis $summary
if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }

Write-Step 'Checking Dart diff quality'
& git diff --check -- $marketplace $analysis $summary
if ($LASTEXITCODE -ne 0) { throw 'git diff --check found whitespace or patch problems.' }

Write-Step 'Analyzing Flutter application'
& flutter analyze lib
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze found an issue. Your backups remain in _local_backups.' }

Write-Step 'Testing offer calculation regression cases'
& flutter test '.\test\marketplace_offer_analysis_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Marketplace offer calculation tests failed.' }

& flutter test '.\test\marketplace_offer_commerce_summary_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Marketplace offer commerce-summary tests failed.' }

Write-Step 'Showing only the intended offer diff'
git diff --stat -- $marketplace $analysis $summary

Write-Step 'Staging only PipeBuyer offer files'
git add -- $marketplace $analysis $summary

if (-not (git diff --cached --quiet)) {
  git commit -m 'Finalize static listing and live offer analytics'
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }

  git push origin pipebuyer-premium-ui
  if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
} else {
  Write-Host 'No new offer changes needed committing.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Existing Make Offer V4 changes validated successfully.' -ForegroundColor Green
Write-Host 'Generated Flutter plugin files and _local_backups were not staged.' -ForegroundColor Green
Write-Host 'You can now restart the full PipeBuyer sandbox.' -ForegroundColor Green
