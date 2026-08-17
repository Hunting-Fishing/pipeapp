$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranch = ((git branch --show-current | Out-String).Trim())
if ($currentBranch -ne $expectedBranch) {
  throw "Startup/auth verification requires $expectedBranch. Current branch: $currentBranch"
}

$rootAuthVerifier = '.\tool\verify_marketplace_root_auth_control.ps1'
$startupRepair = '.\tool\repair_startup_service_route.mjs'
$startupContract = '.\test\startup_auth_loading_surface_contract_test.dart'
$singleSurfaceContract = '.\test\startup_single_surface_test.dart'
$navSource = '.\lib\flutter_flow\nav\nav.dart'
$webSource = '.\web\index.html'

foreach ($required in @(
  $rootAuthVerifier,
  $startupRepair,
  $startupContract,
  $singleSurfaceContract,
  $navSource,
  $webSource
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required startup/auth repair file is missing: $required"
  }
}

Write-Step 'Re-applying and verifying the recorded marketplace root auth control repair'
& powershell -ExecutionPolicy Bypass -File $rootAuthVerifier
if ($LASTEXITCODE -ne 0) {
  throw 'Marketplace root auth control verification failed.'
}

Write-Step 'Applying the single service-truck startup surface repair'
node $startupRepair
if ($LASTEXITCODE -ne 0) {
  throw 'Service-truck startup surface repair failed.'
}

Write-Step 'Formatting Dart sources touched by startup/auth control'
dart format $navSource $startupContract $singleSurfaceContract
if ($LASTEXITCODE -ne 0) {
  throw 'Startup/auth Dart formatting failed.'
}

Write-Step 'Running strict analyzer on navigation and startup contract'
foreach ($target in @($navSource, $startupContract)) {
  dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Strict analyzer failed for $target"
  }
}

Write-Step 'Running startup/auth loading-surface contracts'
foreach ($target in @($singleSurfaceContract, $startupContract)) {
  flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Startup/auth contract failed for $target"
  }
}

Write-Step 'Checking required web startup markers'
$web = Get-Content -LiteralPath $webSource -Raw
foreach ($marker in @(
  'id="pipe-service-truck"',
  'id="pipe-pumpjack"',
  'pipe-pumpjack-rock',
  'window.setTimeout(removePipeStartup, 1400);'
)) {
  if (-not $web.Contains($marker)) {
    throw "Web startup marker missing after repair: $marker"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER STARTUP + AUTH CONTROL PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Current branch lock: PASS' -ForegroundColor Green
Write-Host 'Signed-out marketplace shell blocked: PASS' -ForegroundColor Green
Write-Host 'Existing sign-in/signup flow preserved: PASS' -ForegroundColor Green
Write-Host 'Single visible branded startup surface: PASS' -ForegroundColor Green
Write-Host 'Service truck progress animation: PASS' -ForegroundColor Green
Write-Host 'Pumpjack destination animation: PASS' -ForegroundColor Green
Write-Host 'Startup/auth regression tests: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
