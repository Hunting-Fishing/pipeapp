$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "Dispatch Phase 3 verification requires design/formal-beautification-foundation. Current branch: $branch"
}

$profileFile = '.\lib\marketplace\marketplace_dispatch_company_profile.dart'
$taxonomyFile = '.\lib\marketplace\marketplace_dispatch_service_taxonomy.dart'
$profileTest = '.\test\marketplace_dispatch_company_profile_test.dart'
$taxonomyTest = '.\test\marketplace_dispatch_service_taxonomy_test.dart'
$navigationTest = '.\test\marketplace_dispatch_navigation_test.dart'

foreach ($required in @(
  $profileFile,
  $taxonomyFile,
  $profileTest,
  $taxonomyTest,
  $navigationTest
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Phase 3 file is missing: $required"
  }
}

Write-Step 'Formatting Phase 3 profile foundation'
& dart format $profileFile $profileTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 profile formatting failed.'
}

Write-Step 'Confirming formatter stability'
& dart format --output=none --set-exit-if-changed $profileFile $profileTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 profile files are not formatter stable.'
}

Write-Step 'Running strict analyzer'
foreach ($target in @($profileFile, $taxonomyFile)) {
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 strict analyzer failed for $target"
  }
}

Write-Step 'Running company profile model and widget tests'
& flutter test $profileTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 company profile tests failed.'
}

Write-Step 'Re-running Phase 2 taxonomy regression'
& flutter test $taxonomyTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 2 taxonomy regression failed during Phase 3.'
}

Write-Step 'Re-running Phase 1 navigation regression'
& flutter test $navigationTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 1 navigation regression failed during Phase 3.'
}

Write-Step 'Checking public profile privacy contract'
$source = Get-Content -LiteralPath $profileFile -Raw
foreach ($requiredText in @(
  'normalizedServiceCodes',
  'toPublicProfileMap',
  'profileCompleteness',
  'DispatchBusinessType',
  'DispatchAvailability',
  'Save company profile'
)) {
  if (-not $source.Contains($requiredText)) {
    throw "Phase 3 source contract missing: $requiredText"
  }
}

$publicStart = $source.IndexOf('Map<String, dynamic> toPublicProfileMap()')
if ($publicStart -lt 0) {
  throw 'Public profile projection was not found.'
}
$publicEnd = $source.IndexOf('class MarketplaceDispatchCompanyProfileEditor', $publicStart)
if ($publicEnd -lt 0) {
  throw 'Public profile projection boundary was not found.'
}
$publicProjection = $source.Substring($publicStart, $publicEnd - $publicStart)
foreach ($privateMarker in @(
  "'email'",
  "'phone'",
  "'ownerUid'",
  "'insuranceDocument'",
  "'authUid'"
)) {
  if ($publicProjection.Contains($privateMarker)) {
    throw "Private field leaked into public profile projection: $privateMarker"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 3 PROFILE FOUNDATION GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Business identity model: PASS' -ForegroundColor Green
Write-Host 'Business type model: PASS' -ForegroundColor Green
Write-Host 'Structured multi-service selection: PASS' -ForegroundColor Green
Write-Host 'Availability model: PASS' -ForegroundColor Green
Write-Host 'Profile completeness: PASS' -ForegroundColor Green
Write-Host 'Public profile privacy projection: PASS' -ForegroundColor Green
Write-Host 'Phase 2 taxonomy regression: PASS' -ForegroundColor Green
Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Phase 3 is still in progress.' -ForegroundColor Yellow
Write-Host 'Next Phase 3 task: protected persistence and compatibility bridge.' -ForegroundColor Yellow
