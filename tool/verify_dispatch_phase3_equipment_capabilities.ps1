$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "Dispatch Phase 3 equipment verification requires design/formal-beautification-foundation. Current branch: $branch"
}

$equipmentFile = '.\lib\marketplace\marketplace_dispatch_equipment_capability.dart'
$profilePage = '.\lib\marketplace\marketplace_dispatch_company_profile_page.dart'
$profileModel = '.\lib\marketplace\marketplace_dispatch_company_profile.dart'
$profileRepository = '.\lib\marketplace\marketplace_dispatch_company_profile_repository.dart'
$equipmentTest = '.\test\marketplace_dispatch_equipment_capability_test.dart'
$profileTest = '.\test\marketplace_dispatch_company_profile_test.dart'
$persistenceTest = '.\test\marketplace_dispatch_company_profile_persistence_contract_test.dart'
$taxonomyTest = '.\test\marketplace_dispatch_service_taxonomy_test.dart'
$navigationTest = '.\test\marketplace_dispatch_navigation_test.dart'
$authTest = '.\test\dispatch_auth_reactivity_contract_test.dart'
$rulesFile = '.\firebase\firestore.rules'
$masterPlan = '.\docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$finalizer = '.\tool\finalize_dispatch_phase3_profile_acceptance.mjs'

foreach ($required in @(
  $equipmentFile,
  $profilePage,
  $profileModel,
  $profileRepository,
  $equipmentTest,
  $profileTest,
  $persistenceTest,
  $taxonomyTest,
  $navigationTest,
  $authTest,
  $rulesFile,
  $masterPlan,
  $finalizer
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Phase 3 equipment file is missing: $required"
  }
}

Write-Step 'Recording accepted Phase 3 company-profile browser progress'
& node $finalizer
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 browser-acceptance plan finalizer failed.'
}

$planSource = Get-Content -LiteralPath $masterPlan -Raw
foreach ($requiredText in @(
  '**Current verified completion:** **48%**',
  '| 3 | Provider/company profile system | 15 | 11 | IN PROGRESS |',
  '**Current verified:** 11/15',
  '- [x] Availability: now/today/this week/unavailable. **1 pt**',
  '- [x] Owner/operator and corporation/business-type support. **1 pt**',
  '- [x] Profile completeness + edit experience. **1 pt**'
)) {
  if (-not $planSource.Contains($requiredText)) {
    throw "Master plan did not record accepted Phase 3 profile progress: $requiredText"
  }
}

Write-Step 'Checking the already-repaired equipment source before formatter/analyzer'
$preflightSource = Get-Content -LiteralPath $equipmentFile -Raw
foreach ($requiredText in @(
  'if (!mounted || !dialogContext.mounted) return;',
  'final Object? numberValue = value;',
  'final num? canonical = numberValue is num ? numberValue : null;',
  'final Object? multiValue = value;',
  "multiValue.join(', ')"
)) {
  if (-not $preflightSource.Contains($requiredText)) {
    throw "Equipment source repair marker missing before verification: $requiredText"
  }
}

Write-Step 'Formatting Phase 3 equipment capability source'
& dart format $equipmentFile $profilePage $equipmentTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 equipment formatting failed.'
}

Write-Step 'Confirming formatter stability'
& dart format --output=none --set-exit-if-changed $equipmentFile $profilePage $equipmentTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 equipment files are not formatter stable.'
}

Write-Step 'Running strict analyzer'
foreach ($target in @(
  $equipmentFile,
  $profilePage,
  $profileModel,
  $profileRepository
)) {
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 equipment strict analyzer failed for $target"
  }
}

Write-Step 'Running equipment capability model tests'
& flutter test $equipmentTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 equipment capability tests failed.'
}

Write-Step 'Re-running Phase 3 company-profile regressions'
foreach ($target in @($profileTest, $persistenceTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 company-profile regression failed for $target"
  }
}

Write-Step 'Re-running Phase 2 and Phase 1 regressions'
foreach ($target in @($taxonomyTest, $navigationTest, $authTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch regression failed for $target"
  }
}

Write-Step 'Checking equipment persistence and compatibility contracts'
$equipmentSource = Get-Content -LiteralPath $equipmentFile -Raw
foreach ($requiredText in @(
  "collection('dispatch_carriers')",
  ".collection('vehicles')",
  "'equipmentTypeCode'",
  "'serviceCodes'",
  "'capabilityProfile'",
  "'provider_declared'",
  "'services'",
  "'pilotTruck'",
  "'maximumPayloadKg'",
  'if (!mounted || !dialogContext.mounted) return;',
  'final Object? numberValue = value;',
  'final num? canonical = numberValue is num ? numberValue : null;',
  'final Object? multiValue = value;'
)) {
  if (-not $equipmentSource.Contains($requiredText)) {
    throw "Phase 3 equipment source contract missing: $requiredText"
  }
}

$profilePageSource = Get-Content -LiteralPath $profilePage -Raw
foreach ($requiredText in @(
  'MarketplaceDispatchEquipmentCapabilitiesPage',
  'Manage fleet',
  'Fleet & equipment capabilities'
)) {
  if (-not $profilePageSource.Contains($requiredText)) {
    throw "Company Profile fleet wiring contract missing: $requiredText"
  }
}

Write-Step 'Checking existing carrier-vehicle ownership rule anchors'
$rulesSource = Get-Content -LiteralPath $rulesFile -Raw
foreach ($requiredText in @(
  'match /dispatch_carriers/{carrierId}',
  'match /vehicles/{vehicleId}',
  'request.resource.data.ownerUid == request.auth.uid'
)) {
  if (-not $rulesSource.Contains($requiredText)) {
    throw "Dispatch vehicle Firestore rule anchor missing: $requiredText"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 3 EQUIPMENT CAPABILITY GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Accepted profile progress recorded at 48%: PASS' -ForegroundColor Green
Write-Host 'Equipment source preflight: PASS' -ForegroundColor Green
Write-Host 'Stable equipment type codes: PASS' -ForegroundColor Green
Write-Host 'Structured equipment service codes: PASS' -ForegroundColor Green
Write-Host 'Known capability normalization: PASS' -ForegroundColor Green
Write-Host 'North American display to canonical units: PASS' -ForegroundColor Green
Write-Host 'Legacy fleet compatibility: PASS' -ForegroundColor Green
Write-Host 'Company Profile fleet wiring: PASS' -ForegroundColor Green
Write-Host 'Carrier vehicle ownership rules: PASS' -ForegroundColor Green
Write-Host 'Phase 3 profile regressions: PASS' -ForegroundColor Green
Write-Host 'Phase 2 taxonomy regression: PASS' -ForegroundColor Green
Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch auth reactivity regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Official Dispatch progress remains 48% until equipment browser acceptance.' -ForegroundColor Yellow
Write-Host 'After equipment browser acceptance, Phase 3 becomes 13/15 and overall becomes 50%.' -ForegroundColor Yellow
Write-Host 'Phase 4 remains blocked.' -ForegroundColor Yellow
