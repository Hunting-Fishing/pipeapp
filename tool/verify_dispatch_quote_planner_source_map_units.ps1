$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranch = ((git branch --show-current | Out-String).Trim())
if ($currentBranch -ne $expectedBranch) {
  throw "Dispatch quote planner verification requires $expectedBranch. Current branch: $currentBranch"
}

$preflight = '.\tool\repair_dispatch_quote_planner_matchall.mjs'
$repair = '.\tool\apply_dispatch_quote_planner_source_map_units.mjs'
$source = '.\lib\marketplace\marketplace_dispatch_dashboard.dart'
$contract = '.\test\dispatch_quote_planner_source_map_units_contract_test.dart'
$plan = '.\docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$spec = '.\docs\DISPATCH_QUOTE_PLANNER_SOURCE_MAP_UNITS.md'

foreach ($required in @($preflight, $repair, $source, $contract, $plan, $spec)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Dispatch quote planner file is missing: $required"
  }
}

Write-Step 'Repairing the quote-planner RegExp helper for Node.js 22 if required'
node $preflight
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch quote planner Node.js RegExp preflight failed.'
}

Write-Step 'Applying the idempotent quote source/map/multi-unit repair'
node $repair
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch quote planner repair failed.'
}

Write-Step 'Formatting the Dispatch dashboard and contract test'
dart format $source $contract
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch quote planner formatter failed.'
}

Write-Step 'Confirming formatter stability'
dart format --output=none --set-exit-if-changed $source $contract
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch quote planner files are not formatter stable.'
}

Write-Step 'Running strict analyzer'
dart analyze --fatal-infos --fatal-warnings $source $contract
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch quote planner strict analyzer failed.'
}

Write-Step 'Running quote planner source/map/multi-unit contract'
flutter test $contract
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch quote planner contract failed.'
}

Write-Step 'Running Dispatch navigation and auth regressions'
$regressions = @(
  '.\test\dispatch_auth_reactivity_contract_test.dart',
  '.\test\marketplace_dispatch_navigation_test.dart'
)
foreach ($target in $regressions) {
  if (Test-Path -LiteralPath $target) {
    flutter test $target
    if ($LASTEXITCODE -ne 0) {
      throw "Dispatch quote planner regression failed for $target"
    }
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH QUOTE PLANNER SOURCE + MAP + UNITS PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Current formal branch lock: PASS' -ForegroundColor Green
Write-Host 'Node.js RegExp preflight: PASS' -ForegroundColor Green
Write-Host 'Marketplace listing / standalone selector: PASS' -ForegroundColor Green
Write-Host 'Mapped origin selector: PASS' -ForegroundColor Green
Write-Host 'Mapped destination selector: PASS' -ForegroundColor Green
Write-Host 'Multiple unit requirement rows: PASS' -ForegroundColor Green
Write-Host 'Min/max quantity range validation: PASS' -ForegroundColor Green
Write-Host 'Saved quote persistence contract: PASS' -ForegroundColor Green
Write-Host 'Dispatch regressions: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Dispatch phase score remains unchanged until the current Phase 3 gate is complete.' -ForegroundColor Yellow
