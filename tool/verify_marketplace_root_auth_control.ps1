$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranch = ((git branch --show-current | Out-String).Trim())
if ($currentBranch -ne $expectedBranch) {
  throw "Marketplace auth control verification requires $expectedBranch. Current branch: $currentBranch"
}

$repair = '.\tool\repair_marketplace_root_auth_control.mjs'
$source = '.\lib\marketplace\oil_gas_marketplace.dart'
$contract = '.\test\marketplace_root_auth_control_contract_test.dart'
$dispatchAuth = '.\test\dispatch_auth_reactivity_contract_test.dart'
$navigation = '.\test\marketplace_dispatch_navigation_test.dart'

foreach ($required in @($repair, $source, $contract, $dispatchAuth, $navigation)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required auth control file is missing: $required"
  }
}

Write-Step 'Applying the idempotent root auth control repair'
node $repair
if ($LASTEXITCODE -ne 0) {
  throw 'Marketplace root auth control repair failed.'
}

Write-Step 'Formatting repaired marketplace source and contract test'
dart format $source $contract
if ($LASTEXITCODE -ne 0) {
  throw 'Marketplace auth control formatting failed.'
}

Write-Step 'Confirming formatter stability'
dart format --output=none --set-exit-if-changed $source $contract
if ($LASTEXITCODE -ne 0) {
  throw 'Marketplace auth control files are not formatter stable.'
}

Write-Step 'Running strict analyzer'
foreach ($target in @($source, $contract)) {
  dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Marketplace auth control strict analyzer failed for $target"
  }
}

Write-Step 'Running root auth control contract'
flutter test $contract
if ($LASTEXITCODE -ne 0) {
  throw 'Marketplace root auth control contract failed.'
}

Write-Step 'Re-running Dispatch auth and navigation regressions'
foreach ($target in @($dispatchAuth, $navigation)) {
  flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Marketplace auth control regression failed for $target"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'MARKETPLACE ROOT AUTH CONTROL GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Signed-out shell blocked: PASS' -ForegroundColor Green
Write-Host 'Auth page auto-open: PASS' -ForegroundColor Green
Write-Host 'Dismissed auth page reopens while signed out: PASS' -ForegroundColor Green
Write-Host 'Existing sign-in/signup flow preserved: PASS' -ForegroundColor Green
Write-Host 'Dispatch auth reactivity regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch navigation regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
