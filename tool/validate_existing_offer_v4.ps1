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
$vipAccess = 'lib/marketplace/marketplace_vip_access.dart'
$backupDir = Join-Path $repoRoot '_local_backups'
New-Item -ItemType Directory -Force $backupDir | Out-Null
Copy-Item -LiteralPath $marketplace -Destination (Join-Path $backupDir 'oil_gas_marketplace_before_v4_validation.dart') -Force
Copy-Item -LiteralPath $analysis -Destination (Join-Path $backupDir 'marketplace_offer_analysis_before_v4_validation.dart') -Force
Copy-Item -LiteralPath $summary -Destination (Join-Path $backupDir 'marketplace_offer_summary_before_v5_validation.dart') -Force
Copy-Item -LiteralPath $vipAccess -Destination (Join-Path $backupDir 'marketplace_vip_access_before_v4_validation.dart') -Force

Write-Step 'Normalizing the existing local Make Offer wiring'
& node '.\tool\fix_existing_offer_v4.mjs'
if ($LASTEXITCODE -ne 0) { throw 'Existing Make Offer normalization failed.' }

Write-Step 'Normalizing the V5 web comparison layout'
& node '.\tool\fix_offer_v5_layout.mjs'
if ($LASTEXITCODE -ne 0) { throw 'Make Offer V5 layout normalization failed.' }

Write-Step 'Normalizing VIP UTC timing, policy and lints'
& node '.\tool\fix_vip_access_lints.mjs'
if ($LASTEXITCODE -ne 0) { throw 'VIP early-access normalization failed.' }

Write-Step 'Formatting the offer and VIP files'
& dart format $marketplace $analysis $summary $vipAccess
if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }

Write-Step 'Checking Dart diff quality'
& git diff --check -- $marketplace $analysis $summary $vipAccess
if ($LASTEXITCODE -ne 0) { throw 'git diff --check found whitespace or patch problems.' }

Write-Step 'Analyzing Flutter application'
& flutter analyze lib
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze found an issue. Your backups remain in _local_backups.' }

Write-Step 'Testing offer calculation regression cases'
& flutter test '.\test\marketplace_offer_analysis_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Marketplace offer calculation tests failed.' }

& flutter test '.\test\marketplace_offer_commerce_summary_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Marketplace offer commerce-summary tests failed.' }

Write-Step 'Testing VIP early-access regression cases'
& flutter test '.\test\marketplace_vip_access_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Marketplace VIP early-access tests failed.' }

Write-Step 'Showing only the intended offer/VIP diff'
git diff --stat -- $marketplace $analysis $summary $vipAccess

Write-Step 'Staging only PipeBuyer offer and VIP files'
git add -- $marketplace $analysis $summary $vipAccess

git diff --cached --quiet
$hasStagedChanges = $LASTEXITCODE -ne 0
if ($hasStagedChanges) {
  git commit -m 'Finalize static listing offer analytics and VIP gate'
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }

  git push origin pipebuyer-premium-ui
  if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
} else {
  Write-Host 'No new offer/VIP changes needed committing.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Make Offer V5 and VIP access changes validated successfully.' -ForegroundColor Green
Write-Host 'Generated Flutter plugin files and _local_backups were not staged.' -ForegroundColor Green
Write-Host 'You can now restart the full PipeBuyer sandbox.' -ForegroundColor Green
