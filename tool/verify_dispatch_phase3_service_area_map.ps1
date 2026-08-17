$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranchOutput = git branch --show-current
$currentBranch = (($currentBranchOutput | Out-String).Trim())

if ([string]::IsNullOrWhiteSpace($currentBranch)) {
  $headSha = ((git rev-parse HEAD | Out-String).Trim())
  $expectedRef = "origin/$expectedBranch"
  $expectedSha = ((git rev-parse $expectedRef 2>$null | Out-String).Trim())

  if ([string]::IsNullOrWhiteSpace($headSha) -or
      [string]::IsNullOrWhiteSpace($expectedSha) -or
      $headSha -ne $expectedSha) {
    throw "Dispatch Phase 3 service-area verification detached HEAD must exactly match $expectedRef. HEAD: $headSha Expected: $expectedSha"
  }

  Write-Host "Detached release worktree verified at $expectedRef ($headSha)." -ForegroundColor DarkGray
}
elseif ($currentBranch -ne $expectedBranch) {
  throw "Dispatch Phase 3 service-area verification requires $expectedBranch. Current branch: $currentBranch"
}

$profileModel = '.\lib\marketplace\marketplace_dispatch_company_profile.dart'
$profileRepository = '.\lib\marketplace\marketplace_dispatch_company_profile_repository.dart'
$geography = '.\lib\marketplace\marketplace_dispatch_geography.dart'
$serviceArea = '.\lib\marketplace\marketplace_service_area.dart'
$geographyTest = '.\test\marketplace_dispatch_geography_test.dart'
$serviceAreaContractTest = '.\test\marketplace_dispatch_service_area_persistence_contract_test.dart'
$profileTest = '.\test\marketplace_dispatch_company_profile_test.dart'
$persistenceTest = '.\test\marketplace_dispatch_company_profile_persistence_contract_test.dart'
$equipmentTest = '.\test\marketplace_dispatch_equipment_capability_test.dart'
$taxonomyTest = '.\test\marketplace_dispatch_service_taxonomy_test.dart'
$navigationTest = '.\test\marketplace_dispatch_navigation_test.dart'
$authTest = '.\test\dispatch_auth_reactivity_contract_test.dart'
$masterPlan = '.\docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$equipmentFinalizer = '.\tool\finalize_dispatch_phase3_equipment_acceptance.mjs'

foreach ($required in @(
  $profileModel,
  $profileRepository,
  $geography,
  $serviceArea,
  $geographyTest,
  $serviceAreaContractTest,
  $profileTest,
  $persistenceTest,
  $equipmentTest,
  $taxonomyTest,
  $navigationTest,
  $authTest,
  $masterPlan,
  $equipmentFinalizer
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Phase 3 service-area file is missing: $required"
  }
}

Write-Step 'Recording accepted equipment browser progress'
& node $equipmentFinalizer
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 equipment browser-acceptance finalizer failed.'
}

$planSource = Get-Content -LiteralPath $masterPlan -Raw
foreach ($requiredText in @(
  '**Current verified completion:** **50%**',
  '| 3 | Provider/company profile system | 15 | 13 | IN PROGRESS |',
  '**Current verified:** 13/15',
  '- [x] Equipment/fleet capability profiles. **2 pts**',
  '- [ ] Service area and home-base map setup. **1 pt**'
)) {
  if (-not $planSource.Contains($requiredText)) {
    throw "Master plan did not record the expected 50% equipment-accepted baseline: $requiredText"
  }
}

Write-Step 'Formatting mapped service-area source and tests'
& dart format `
  $profileModel `
  $profileRepository `
  $geography `
  $geographyTest `
  $serviceAreaContractTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 mapped service-area formatting failed.'
}

Write-Step 'Confirming formatter stability'
& dart format --output=none --set-exit-if-changed `
  $profileModel `
  $profileRepository `
  $geography `
  $geographyTest `
  $serviceAreaContractTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 mapped service-area files are not formatter stable.'
}

Write-Step 'Running strict analyzer'
foreach ($target in @(
  $profileModel,
  $profileRepository,
  $geography,
  $geographyTest,
  $serviceAreaContractTest
)) {
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 mapped service-area strict analyzer failed for $target"
  }
}

Write-Step 'Running mapped geography privacy and persistence tests'
foreach ($target in @($geographyTest, $serviceAreaContractTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 mapped service-area test failed for $target"
  }
}

Write-Step 'Re-running Phase 3 profile and equipment regressions'
foreach ($target in @($profileTest, $persistenceTest, $equipmentTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 regression failed for $target"
  }
}

Write-Step 'Re-running Phase 2 and Phase 1 regressions'
foreach ($target in @($taxonomyTest, $navigationTest, $authTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch regression failed for $target"
  }
}

Write-Step 'Checking mapped service-area integration contracts'
$profileSource = Get-Content -LiteralPath $profileModel -Raw
foreach ($requiredText in @(
  'MarketplaceServiceAreaPicker.show',
  'Set service area on map',
  'Edit service area on map',
  'Approximate home base:',
  'effectiveServiceAreaLabel'
)) {
  if (-not $profileSource.Contains($requiredText)) {
    throw "Dispatch profile map integration contract missing: $requiredText"
  }
}

$repositorySource = Get-Content -LiteralPath $profileRepository -Raw
foreach ($requiredText in @(
  'DispatchPublicGeographyProjection.homeLocation',
  'DispatchPublicGeographyProjection.serviceArea',
  "'serviceArea': serviceArea.toMap()",
  "privateDispatch['serviceArea']",
  "carrier['serviceArea']"
)) {
  if (-not $repositorySource.Contains($requiredText)) {
    throw "Dispatch service-area persistence contract missing: $requiredText"
  }
}

$geographySource = Get-Content -LiteralPath $geography -Raw
foreach ($requiredText in @(
  "precisionCode = 'approximate_1km'",
  '(value * 100).roundToDouble() / 100',
  "'source': 'service_area_center'",
  "'countryCodes': area.countryCodes",
  "'placeKeys': area.placeKeys"
)) {
  if (-not $geographySource.Contains($requiredText)) {
    throw "Dispatch public geography privacy contract missing: $requiredText"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 3 SERVICE AREA MAP GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Equipment browser acceptance recorded at 50%: PASS' -ForegroundColor Green
Write-Host 'Existing Pipe Buyer open-map picker reuse: PASS' -ForegroundColor Green
Write-Host 'Structured service-area persistence: PASS' -ForegroundColor Green
Write-Host 'Approximate public home-base projection: PASS' -ForegroundColor Green
Write-Host 'Exact service-area data private: PASS' -ForegroundColor Green
Write-Host 'Legacy dispatch_carriers service-area fallback: PASS' -ForegroundColor Green
Write-Host 'Phase 3 profile/equipment regressions: PASS' -ForegroundColor Green
Write-Host 'Phase 2 taxonomy regression: PASS' -ForegroundColor Green
Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch auth reactivity regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Official Dispatch progress remains 50% until mapped service-area browser acceptance.' -ForegroundColor Yellow
Write-Host 'After mapped service-area browser acceptance, Phase 3 becomes 14/15 and overall becomes 51%.' -ForegroundColor Yellow
Write-Host 'Phase 4 remains blocked until credentials metadata completes Phase 3.' -ForegroundColor Yellow
