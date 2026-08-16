$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Test-LocalPort([int]$Port) {
  return $null -ne (
    Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
      Select-Object -First 1
  )
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "Dispatch Phase 1 verification requires design/formal-beautification-foundation. Current branch: $branch"
}

$target = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_page.dart'
$navigation = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_navigation.dart'
$patcher = Join-Path $repoRoot 'tool\apply_dispatch_phase1_navigation.mjs'
$phase0Integration = Join-Path $repoRoot 'firebase\functions\integration\dispatch_phase0_baseline.mjs'
$formalSandbox = Join-Path $repoRoot 'tool\start_formal_test_sandbox.ps1'
$reseed = Join-Path $repoRoot 'tool\reseed_formal_test_data.ps1'

foreach ($required in @(
  $target,
  $navigation,
  $patcher,
  $phase0Integration,
  $formalSandbox,
  $reseed
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Dispatch Phase 1 file is missing: $required"
  }
}

$backupDir = Join-Path $repoRoot ("_local_backups\dispatch_phase1_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$targetBackup = Join-Path $backupDir 'marketplace_dispatch_page.dart'
Copy-Item -LiteralPath $target -Destination $targetBackup -Force

try {
  Write-Step 'Checking Phase 1 integrator syntax before product mutation'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch Phase 1 integrator syntax check failed.'
  }

  Write-Step 'Applying role-aware Dispatch navigation against the verified Phase 0 file only'
  & node $patcher
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch Phase 1 navigation integration failed.'
  }

  Write-Step 'Formatting Phase 1 Dispatch files'
  & dart format `
    '.\lib\marketplace\marketplace_dispatch_page.dart' `
    '.\lib\marketplace\marketplace_dispatch_navigation.dart' `
    '.\test\marketplace_dispatch_navigation_test.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch Phase 1 Dart format failed.'
  }

  Write-Step 'Running strict analyzer for Phase 1 and preserved Dispatch behavior'
  $analyzeTargets = @(
    '.\lib\marketplace\marketplace_dispatch_page.dart',
    '.\lib\marketplace\marketplace_dispatch_navigation.dart',
    '.\lib\marketplace\marketplace_dispatch_dashboard.dart',
    '.\lib\marketplace\marketplace_dispatch_repository.dart',
    '.\lib\marketplace\marketplace_dispatch_onboarding.dart'
  )
  foreach ($analyzeTarget in $analyzeTargets) {
    Write-Host "Analyzing $analyzeTarget" -ForegroundColor DarkGray
    & dart analyze --fatal-infos --fatal-warnings $analyzeTarget
    if ($LASTEXITCODE -ne 0) {
      throw "Dispatch Phase 1 strict analyzer failed for $analyzeTarget"
    }
  }

  Write-Step 'Running Phase 1 role and navigation widget tests'
  & flutter test '.\test\marketplace_dispatch_navigation_test.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch Phase 1 navigation widget tests failed.'
  }

  Write-Step 'Re-running preserved Dispatch Phase 0 Flutter contracts'
  $preservedFlutterTests = @(
    '.\test\marketplace_dispatch_onboarding_test.dart',
    '.\test\marketplace_dispatch_distance_test.dart',
    '.\test\dispatch_route_privacy_contract_test.dart'
  )
  foreach ($testFile in $preservedFlutterTests) {
    Write-Host "Testing $testFile" -ForegroundColor DarkGray
    & flutter test $testFile
    if ($LASTEXITCODE -ne 0) {
      throw "Preserved Dispatch regression failed for $testFile"
    }
  }

  Write-Step 'Re-running Dispatch command and query-index contracts'
  $nodeTests = @(
    '.\firebase\functions\test\dispatch_command_policy.test.js',
    '.\firebase\functions\test\dispatch_query_index.test.js'
  )
  foreach ($testFile in $nodeTests) {
    Write-Host "Testing $testFile" -ForegroundColor DarkGray
    & node --test $testFile
    if ($LASTEXITCODE -ne 0) {
      throw "Dispatch server regression failed for $testFile"
    }
  }

  Write-Step 'Checking the integrated page exposes only the four core sections'
  $pageSource = Get-Content -LiteralPath $target -Raw
  foreach ($requiredText in @(
    "label: Text('Dashboard')",
    "label: Text('Request Service')",
    "label: Text('Directory')",
    "label: Text('Jobs')",
    'MarketplaceDispatchCustomerHome',
    'MarketplaceDispatchDirectoryFoundation',
    'Company Profile',
    'List your business'
  )) {
    if (-not $pageSource.Contains($requiredText) -and
        -not (Get-Content -LiteralPath $navigation -Raw).Contains($requiredText)) {
      throw "Dispatch Phase 1 source contract missing: $requiredText"
    }
  }
  if ($pageSource.Contains("label: Text('Signup')") -or
      $pageSource.Contains("label: Text('Pilot')")) {
    throw 'Legacy Signup or Pilot top-level navigation is still present.'
  }

  $requiredPorts = @(19099, 18080, 15001, 19199, 14000)
  $missingPorts = @($requiredPorts | Where-Object { -not (Test-LocalPort $_) })
  if ($missingPorts.Count -gt 0) {
    Write-Step 'Starting the verified formal Firebase sandbox for the Phase 1 preservation gate'
    & powershell -ExecutionPolicy Bypass -File $formalSandbox -SeedOnly
    if ($LASTEXITCODE -ne 0) {
      throw 'Formal Firebase sandbox did not pass its seed/smoke gate.'
    }
  }
  else {
    Write-Step 'Using the already-running verified formal Firebase sandbox'
  }

  $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
  $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
  $env:FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:19199'
  $env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:15001'
  $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
  $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'

  Write-Step 'Proving Phase 0 provider, job, quote, award and route privacy behavior still works'
  & node $phase0Integration
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch Phase 1 changed preserved Phase 0 emulator behavior.'
  }

  Write-Step 'Confirming deterministic formal fixtures after the isolated journey'
  & powershell -ExecutionPolicy Bypass -File $reseed -SkipSeed
  if ($LASTEXITCODE -ne 0) {
    throw 'Formal emulator fixtures changed during the Dispatch Phase 1 verification.'
  }

  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'DISPATCH PHASE 1 ENGINEERING GATE PASSED' -ForegroundColor Green
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'Role-aware account state: PASS' -ForegroundColor Green
  Write-Host 'Registered-provider Dashboard entry: PASS' -ForegroundColor Green
  Write-Host 'Customer first-entry actions: PASS' -ForegroundColor Green
  Write-Host 'Four-section navigation: PASS' -ForegroundColor Green
  Write-Host 'Signup removed from primary navigation: PASS' -ForegroundColor Green
  Write-Host 'Pilot removed from primary navigation: PASS' -ForegroundColor Green
  Write-Host 'Company Profile / List your business action: PASS' -ForegroundColor Green
  Write-Host 'Desktop/mobile widget contracts: PASS' -ForegroundColor Green
  Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
  Write-Host 'Phase 0 behavior preservation: PASS' -ForegroundColor Green
  Write-Host 'Emulator provider/job/quote/award journey: PASS' -ForegroundColor Green
  Write-Host ''
  Write-Host 'Official Dispatch progress remains 26% until browser visual acceptance.' -ForegroundColor Yellow
  Write-Host 'After visual acceptance, Phase 1 becomes 10/10 and overall becomes 33%.' -ForegroundColor Yellow
  Write-Host "Backup retained at: $backupDir" -ForegroundColor DarkGray
}
catch {
  Write-Host ''
  Write-Host 'PHASE 1 FAILED - RESTORING EXACT PRE-RUN DISPATCH PAGE' -ForegroundColor Red
  Copy-Item -LiteralPath $targetBackup -Destination $target -Force
  Write-Host 'marketplace_dispatch_page.dart restored.' -ForegroundColor Yellow
  throw
}
