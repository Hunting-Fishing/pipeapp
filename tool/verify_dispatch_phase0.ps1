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
  throw "Dispatch Phase 0 verification requires design/formal-beautification-foundation. Current branch: $branch"
}

$inventory = Join-Path $repoRoot 'docs\DISPATCH_PHASE0_FOUNDATION_INVENTORY.md'
$integration = Join-Path $repoRoot 'firebase\functions\integration\dispatch_phase0_baseline.mjs'
$reseed = Join-Path $repoRoot 'tool\reseed_formal_test_data.ps1'
$formalSandbox = Join-Path $repoRoot 'tool\start_formal_test_sandbox.ps1'

foreach ($required in @($inventory, $integration, $reseed, $formalSandbox)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Dispatch Phase 0 file is missing: $required"
  }
}

Write-Step 'Checking focused Dispatch baseline JavaScript syntax'
& node --check $integration
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 0 integration syntax check failed.'
}

Write-Step 'Running strict Dart analyzer for the existing Dispatch foundation'
$dispatchAnalyzeTargets = @(
  '.\lib\marketplace\marketplace_dispatch_page.dart',
  '.\lib\marketplace\marketplace_dispatch_dashboard.dart',
  '.\lib\marketplace\marketplace_dispatch_repository.dart',
  '.\lib\marketplace\marketplace_dispatch_onboarding.dart',
  '.\lib\marketplace\marketplace_dispatch_transaction.dart',
  '.\lib\marketplace\marketplace_dispatch_distance.dart'
)
foreach ($target in $dispatchAnalyzeTargets) {
  Write-Host "Analyzing $target" -ForegroundColor DarkGray
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch Phase 0 strict analyzer failed for $target"
  }
}

Write-Step 'Running focused Flutter Dispatch regression tests'
& flutter test `
  '.\test\marketplace_dispatch_onboarding_test.dart' `
  '.\test\marketplace_dispatch_distance_test.dart' `
  '.\test\dispatch_route_privacy_contract_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 0 Flutter regression tests failed.'
}

Write-Step 'Running Dispatch server policy and query-index contracts'
& node --test `
  '.\firebase\functions\test\dispatch_command_policy.test.js' `
  '.\firebase\functions\test\dispatch_query_index.test.js'
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 0 server contract tests failed.'
}

$requiredPorts = @(19099, 18080, 15001, 19199, 14000)
$missingPorts = @($requiredPorts | Where-Object { -not (Test-LocalPort $_) })
if ($missingPorts.Count -gt 0) {
  Write-Step 'Starting the verified formal Firebase sandbox for the emulator gate'
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

Write-Step 'Running isolated Auth + Rules + Functions + Firestore Dispatch journey'
& node $integration
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 0 emulator baseline failed.'
}

Write-Step 'Confirming deterministic formal fixtures after isolated cleanup'
& powershell -ExecutionPolicy Bypass -File $reseed -SkipSeed
if ($LASTEXITCODE -ne 0) {
  throw 'Formal emulator fixtures changed during the Dispatch Phase 0 baseline.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 0 BASELINE GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host 'Flutter Dispatch regression tests: PASS' -ForegroundColor Green
Write-Host 'Server policy/index contracts: PASS' -ForegroundColor Green
Write-Host 'Provider signup/approval: PASS' -ForegroundColor Green
Write-Host 'Authenticated provider-profile rules: PASS' -ForegroundColor Green
Write-Host 'Manual job create + idempotent retry: PASS' -ForegroundColor Green
Write-Host 'Carrier quote + idempotent retry: PASS' -ForegroundColor Green
Write-Host 'Customer award + transaction: PASS' -ForegroundColor Green
Write-Host 'Private route before/after award rules: PASS' -ForegroundColor Green
Write-Host 'Formal fixture cleanup verification: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Phase 0 may be marked 10/10 only after this complete block is observed locally.' -ForegroundColor Yellow
