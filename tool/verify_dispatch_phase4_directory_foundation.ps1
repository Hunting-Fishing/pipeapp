$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranch = ((git branch --show-current | Out-String).Trim())

if ([string]::IsNullOrWhiteSpace($currentBranch)) {
  $headSha = ((git rev-parse HEAD | Out-String).Trim())
  $expectedSha = ((git rev-parse "origin/$expectedBranch" | Out-String).Trim())
  if ([string]::IsNullOrWhiteSpace($headSha) -or
      [string]::IsNullOrWhiteSpace($expectedSha) -or
      $headSha -ne $expectedSha) {
    throw "Detached Phase 4 verification worktree must exactly match origin/$expectedBranch."
  }
}
elseif ($currentBranch -ne $expectedBranch) {
  throw "Dispatch Phase 4 verification requires $expectedBranch. Current branch: $currentBranch"
}

$directorySource = '.\lib\marketplace\marketplace_dispatch_directory.dart'
$dispatchPage = '.\lib\marketplace\marketplace_dispatch_page.dart'
$directoryTest = '.\test\marketplace_dispatch_directory_test.dart'
$credentialTest = '.\test\marketplace_dispatch_credentials_test.dart'
$credentialPrivacyTest = '.\test\marketplace_dispatch_credentials_privacy_contract_test.dart'
$profileTest = '.\test\marketplace_dispatch_company_profile_test.dart'
$equipmentTest = '.\test\marketplace_dispatch_equipment_capability_test.dart'
$geographyTest = '.\test\marketplace_dispatch_geography_test.dart'
$serviceAreaTest = '.\test\marketplace_dispatch_service_area_persistence_contract_test.dart'
$taxonomyTest = '.\test\marketplace_dispatch_service_taxonomy_test.dart'
$navigationTest = '.\test\marketplace_dispatch_navigation_test.dart'
$authTest = '.\test\dispatch_auth_reactivity_contract_test.dart'
$firestoreRules = '.\firebase\firestore.rules'
$masterPlan = '.\docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$phase3Finalizer = '.\tool\finalize_dispatch_phase3_browser_acceptance.mjs'
$directoryIntegrator = '.\tool\integrate_dispatch_phase4_directory.mjs'

foreach ($required in @(
  $directorySource,
  $dispatchPage,
  $directoryTest,
  $credentialTest,
  $credentialPrivacyTest,
  $profileTest,
  $equipmentTest,
  $geographyTest,
  $serviceAreaTest,
  $taxonomyTest,
  $navigationTest,
  $authTest,
  $firestoreRules,
  $masterPlan,
  $phase3Finalizer,
  $directoryIntegrator
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Phase 4 Directory file is missing: $required"
  }
}

Write-Step 'Recording accepted Phase 3 browser completion at 52 percent'
node $phase3Finalizer
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 browser acceptance finalizer failed.'
}

Write-Step 'Wiring the new Directory page into Dispatch'
node $directoryIntegrator
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 4 Directory integration failed.'
}

$lockPath = '.\pubspec.lock'
$packageConfig = '.\.dart_tool\package_config.json'
if (-not (Test-Path -LiteralPath $packageConfig)) {
  if (-not (Test-Path -LiteralPath $lockPath)) {
    throw 'pubspec.lock is missing.'
  }
  $lockHashBefore = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash
  Write-Step 'Resolving Flutter dependencies because package_config.json is missing'
  flutter pub get
  if ($LASTEXITCODE -ne 0) {
    throw 'flutter pub get failed.'
  }
  if (-not (Test-Path -LiteralPath $packageConfig)) {
    throw 'flutter pub get did not create .dart_tool/package_config.json.'
  }
  $lockHashAfter = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash
  if ($lockHashAfter -ne $lockHashBefore) {
    throw 'SAFETY STOP: dependency bootstrap changed pubspec.lock.'
  }
}

Write-Step 'Formatting Phase 4 Directory source, integration, and tests'
dart format `
  $directorySource `
  $dispatchPage `
  $directoryTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 4 Directory formatting failed.'
}

Write-Step 'Confirming formatter stability'
dart format --output=none --set-exit-if-changed `
  $directorySource `
  $dispatchPage `
  $directoryTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 4 Directory files are not formatter stable.'
}

Write-Step 'Running strict analyzer'
foreach ($target in @($directorySource, $dispatchPage, $directoryTest)) {
  dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 4 Directory strict analyzer failed for $target"
  }
}

Write-Step 'Running Phase 4 Directory model and widget tests'
flutter test $directoryTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 4 Directory tests failed.'
}

Write-Step 'Re-running Phase 3 profile, equipment, geography, and credential regressions'
foreach ($target in @(
  $credentialTest,
  $credentialPrivacyTest,
  $profileTest,
  $equipmentTest,
  $geographyTest,
  $serviceAreaTest
)) {
  flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 regression failed for $target"
  }
}

Write-Step 'Re-running Phase 2, Phase 1, and auth regressions'
foreach ($target in @($taxonomyTest, $navigationTest, $authTest)) {
  flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch regression failed for $target"
  }
}

Write-Step 'Checking bounded public Directory privacy contracts'
$directoryText = Get-Content -LiteralPath $directorySource -Raw
foreach ($requiredText in @(
  "collection('public_business_profiles')",
  'loadFirestoreDocumentPage(',
  'pageSize = 60',
  'serviceCodes',
  'serviceAreaLabel',
  'availabilityCode',
  'emergencyCallout',
  'remoteSiteCapable'
)) {
  if (-not $directoryText.Contains($requiredText)) {
    throw "Directory source contract is missing: $requiredText"
  }
}

foreach ($forbiddenText in @(
  "collection('business_private')",
  'dispatchCredentials',
  'documentStoragePath',
  'referenceNumber'
)) {
  if ($directoryText.Contains($forbiddenText)) {
    throw "Directory source crossed a private data boundary: $forbiddenText"
  }
}

$dispatchText = Get-Content -LiteralPath $dispatchPage -Raw
foreach ($requiredText in @(
  "import 'marketplace_dispatch_directory.dart';",
  'DispatchSection.directory => MarketplaceDispatchDirectoryPage('
)) {
  if (-not $dispatchText.Contains($requiredText)) {
    throw "Dispatch Directory integration contract is missing: $requiredText"
  }
}

$rulesText = Get-Content -LiteralPath $firestoreRules -Raw
if (-not $rulesText.Contains('match /public_business_profiles/{businessId}')) {
  throw 'Public business profile Firestore rule is missing.'
}
if (-not $rulesText.Contains('allow read: if true;')) {
  throw 'The current Firestore rules do not expose the public business profile read path required by the Directory.'
}

$planText = Get-Content -LiteralPath $masterPlan -Raw
foreach ($requiredText in @(
  '**Current verified completion:** **52%**',
  '| 3 | Provider/company profile system | 15 | 15 | GREEN |',
  '| 4 | Dispatch Service Directory + map | 20 | 0 | IN PROGRESS |',
  '**Current verified:** 15/15',
  'Overall: 52/100 = 52%'
)) {
  if (-not $planText.Contains($requiredText)) {
    throw "Master plan Phase 4 entry state is missing: $requiredText"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 4 DIRECTORY FOUNDATION GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Phase 3 browser completion recorded at 52 percent: PASS' -ForegroundColor Green
Write-Host 'Bounded public Directory query: PASS' -ForegroundColor Green
Write-Host 'Structured service filter: PASS' -ForegroundColor Green
Write-Host 'Availability and business-type filters: PASS' -ForegroundColor Green
Write-Host 'Emergency and remote-site filters: PASS' -ForegroundColor Green
Write-Host 'Directory list cards: PASS' -ForegroundColor Green
Write-Host 'Loading/error/empty states: PASS' -ForegroundColor Green
Write-Host 'Private credential data excluded: PASS' -ForegroundColor Green
Write-Host 'Phase 3 regressions: PASS' -ForegroundColor Green
Write-Host 'Phase 2 taxonomy regression: PASS' -ForegroundColor Green
Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch auth reactivity regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Official Dispatch progress remains 52 percent until this Phase 4 slice receives browser acceptance.' -ForegroundColor Yellow
Write-Host 'Next after browser acceptance: pagination/index strategy and geography/radius filtering, then open-map synchronization.' -ForegroundColor Yellow
