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

$dispatchPage = '.\lib\marketplace\marketplace_dispatch_page.dart'
$profileModel = '.\lib\marketplace\marketplace_dispatch_company_profile.dart'
$profileRepository = '.\lib\marketplace\marketplace_dispatch_company_profile_repository.dart'
$profilePage = '.\lib\marketplace\marketplace_dispatch_company_profile_page.dart'
$profileTest = '.\test\marketplace_dispatch_company_profile_test.dart'
$persistenceTest = '.\test\marketplace_dispatch_company_profile_persistence_contract_test.dart'
$taxonomyTest = '.\test\marketplace_dispatch_service_taxonomy_test.dart'
$navigationTest = '.\test\marketplace_dispatch_navigation_test.dart'
$authTest = '.\test\dispatch_auth_reactivity_contract_test.dart'
$integrator = '.\tool\apply_dispatch_phase3_profile_persistence.mjs'
$planFinalizer = '.\tool\finalize_dispatch_phase3_foundation_plan.mjs'
$rulesFile = '.\firebase\firestore.rules'

foreach ($required in @(
  $dispatchPage,
  $profileModel,
  $profileRepository,
  $profilePage,
  $profileTest,
  $persistenceTest,
  $taxonomyTest,
  $navigationTest,
  $authTest,
  $integrator,
  $planFinalizer,
  $rulesFile
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Phase 3 persistence file is missing: $required"
  }
}

Write-Step 'Recording the verified Phase 3 foundation progress'
& node $planFinalizer
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch master plan progress finalizer failed.'
}

$backupDir = Join-Path $repoRoot ('.\_local_backups\dispatch_phase3_profile_persistence_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$dispatchBackup = Join-Path $backupDir 'marketplace_dispatch_page.dart'
Copy-Item -LiteralPath $dispatchPage -Destination $dispatchBackup -Force

try {
  Write-Step 'Wiring registered providers to the live company profile editor'
  & node $integrator
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 3 profile wiring integrator failed.'
  }

  Write-Step 'Formatting Phase 3 persistence files'
  & dart format $profileModel $profileRepository $profilePage $persistenceTest $dispatchPage
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 3 persistence formatting failed.'
  }

  Write-Step 'Confirming formatter stability'
  & dart format --output=none --set-exit-if-changed $profileModel $profileRepository $profilePage $persistenceTest $dispatchPage
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 3 persistence files are not formatter stable.'
  }

  Write-Step 'Running strict analyzer'
  foreach ($target in @($profileModel, $profileRepository, $profilePage, $dispatchPage)) {
    & dart analyze --fatal-infos --fatal-warnings $target
    if ($LASTEXITCODE -ne 0) {
      throw "Phase 3 persistence analyzer failed for $target"
    }
  }

  Write-Step 'Running company profile foundation regression'
  & flutter test $profileTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 3 company profile foundation regression failed.'
  }

  Write-Step 'Running persistence and privacy contracts'
  & flutter test $persistenceTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 3 company profile persistence contract failed.'
  }

  Write-Step 'Re-running Phase 2 taxonomy regression'
  & flutter test $taxonomyTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 2 taxonomy regression failed during Phase 3 persistence.'
  }

  Write-Step 'Re-running Phase 1 navigation regression'
  & flutter test $navigationTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 1 navigation regression failed during Phase 3 persistence.'
  }

  Write-Step 'Re-running Dispatch auth reactivity contract'
  & flutter test $authTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch auth reactivity regression failed during Phase 3 persistence.'
  }

  Write-Step 'Checking existing Firestore ownership boundaries'
  $rules = Get-Content -LiteralPath $rulesFile -Raw
  foreach ($requiredRule in @(
    'match /public_business_profiles/{businessId}',
    'allow create, update, delete: if owns(businessId) || isAdmin();',
    'match /business_private/{businessId}',
    'allow create, read, update, delete: if owns(businessId);',
    'match /dispatch_carriers/{carrierId}'
  )) {
    if (-not $rules.Contains($requiredRule)) {
      throw "Required Firestore ownership contract is missing: $requiredRule"
    }
  }

  Write-Step 'Checking live Dispatch wiring contract'
  $dispatchSource = Get-Content -LiteralPath $dispatchPage -Raw
  foreach ($requiredText in @(
    'FirebaseAuth.instance.authStateChanges()',
    "import 'marketplace_dispatch_company_profile_page.dart';",
    'accountState.providerRegistered',
    'MarketplaceDispatchCompanyProfilePage()',
    '_CarrierEnrollment(repo: repo)'
  )) {
    if (-not $dispatchSource.Contains($requiredText)) {
      throw "Dispatch live profile wiring is missing: $requiredText"
    }
  }

  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'DISPATCH PHASE 3 PROFILE PERSISTENCE GATE PASSED' -ForegroundColor Green
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'Master plan foundation progress: 45% PASS' -ForegroundColor Green
  Write-Host 'Registered provider Company Profile wiring: PASS' -ForegroundColor Green
  Write-Host 'Owner-scoped public profile persistence: PASS' -ForegroundColor Green
  Write-Host 'Owner-scoped private legal identity persistence: PASS' -ForegroundColor Green
  Write-Host 'Public/private field separation contract: PASS' -ForegroundColor Green
  Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
  Write-Host 'Phase 3 foundation regression: PASS' -ForegroundColor Green
  Write-Host 'Phase 2 taxonomy regression: PASS' -ForegroundColor Green
  Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
  Write-Host 'Dispatch auth reactivity regression: PASS' -ForegroundColor Green
  Write-Host ''
  Write-Host 'Browser acceptance is still required before awarding persistence/edit points.' -ForegroundColor Yellow
  Write-Host "Backup retained at: $backupDir" -ForegroundColor DarkGray
}
catch {
  Write-Host ''
  Write-Host 'PHASE 3 PROFILE PERSISTENCE FAILED - RESTORING DISPATCH PAGE' -ForegroundColor Red
  Copy-Item -LiteralPath $dispatchBackup -Destination $dispatchPage -Force
  Write-Host 'Exact pre-run Dispatch page restored.' -ForegroundColor Yellow
  throw
}
