# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "STOP: Wrong branch. Expected design/formal-beautification-foundation, found $branch"
}

$remote = 'origin/design/formal-beautification-foundation'
Write-Host "`n==> Fetching read-only Phase 4 continuation controls" -ForegroundColor Cyan
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal Phase 4 continuation controls.'
}

$supportFiles = @(
  'tool/pipebuyer_firebase_cli.ps1',
  'firebase/functions/test/dispatch_directory_projection.test.js',
  'firebase/functions/test/dispatch_directory_security_contract.test.js',
  'firebase/rules-tests/dispatch_directory_rules.test.js',
  'firebase/rules-tests/package.json',
  'docs/repairs/FIREBASE_CLI_WINDOWS_FALLBACK.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize read-only Phase 4 support controls.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage read-only Phase 4 support controls.'
}

Write-Host "`n==> Preflighting the previously proven Firebase CLI fallback" -ForegroundColor Cyan
$firebaseHelperPath = Join-Path $repoRoot 'tool\pipebuyer_firebase_cli.ps1'
$parseTokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
  $firebaseHelperPath,
  [ref]$parseTokens,
  [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
  throw "STOP: Firebase CLI helper PowerShell parse failed: $($parseErrors[0].Message)"
}
. $firebaseHelperPath
Assert-PipeBuyerFirebaseCli

$productionFiles = @(
  'firebase/functions/dispatch_directory_projection.js',
  'firebase/functions/index.js',
  'firebase/functions/package.json',
  'firebase/firestore.rules'
)
foreach ($target in $productionFiles) {
  if (-not (Test-Path -LiteralPath $target)) {
    throw "STOP: Required already-applied Phase 4 production file is missing: $target"
  }
}

Write-Host "`n==> Confirming the already-applied Phase 4 source before read-only continuation" -ForegroundColor Cyan
$module = Get-Content -LiteralPath 'firebase/functions/dispatch_directory_projection.js' -Raw
$index = Get-Content -LiteralPath 'firebase/functions/index.js' -Raw
$rules = Get-Content -LiteralPath 'firebase/firestore.rules' -Raw
$package = Get-Content -LiteralPath 'firebase/functions/package.json' -Raw
foreach ($marker in @(
  'function createDispatchDirectoryProjection',
  'dispatch_directory_entries',
  'verified: false',
  'geohash'
)) {
  if (-not $module.Contains($marker)) {
    throw "STOP: Already-applied Directory projection module is missing marker: $marker"
  }
}
foreach ($marker in @(
  'createDispatchDirectoryProjection',
  'public_business_profiles/{companyId}',
  'dispatch_carriers/{companyId}',
  'dispatchDirectoryProjection.syncCompany(event.params.companyId)'
)) {
  if (-not $index.Contains($marker)) {
    throw "STOP: Already-applied Functions wiring is missing marker: $marker"
  }
}
foreach ($marker in @(
  'match /dispatch_directory_entries/{companyId}',
  "allow read: if phase1FeatureEnabled('dispatch') && signedIn();",
  'allow create, update, delete: if false;'
)) {
  if (-not $rules.Contains($marker)) {
    throw "STOP: Already-applied Firestore Directory rule is missing marker: $marker"
  }
}
if (-not $package.Contains('node --check dispatch_directory_projection.js')) {
  throw 'STOP: Functions package syntax gate does not include the Directory projection module.'
}
Write-Host 'Already-applied Directory production source: PASS' -ForegroundColor Green

$hashBefore = @{}
foreach ($target in $productionFiles) {
  $hashBefore[$target] = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
}

Write-Host "`n==> Re-running read-only Directory projection/privacy contracts" -ForegroundColor Cyan
& node --test `
  '.\firebase\functions\test\dispatch_directory_projection.test.js' `
  '.\firebase\functions\test\dispatch_directory_security_contract.test.js'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory projection/privacy contracts failed.'
}

Write-Host "`n==> Checking Functions syntax without mutation" -ForegroundColor Cyan
& node --check '.\firebase\functions\index.js'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: firebase/functions/index.js syntax check failed.'
}
& node --check '.\firebase\functions\dispatch_directory_projection.js'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory projection module syntax check failed.'
}

$rulesModules = Join-Path $repoRoot 'firebase\rules-tests\node_modules\@firebase\rules-unit-testing'
if (-not (Test-Path -LiteralPath $rulesModules)) {
  Write-Host "`n==> Installing pinned rules-test dependencies" -ForegroundColor Cyan
  & npm ci --prefix '.\firebase\rules-tests'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Firestore rules-test dependencies could not be installed.'
  }
}

$port8080 = Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($port8080) {
  throw "STOP: Dedicated rules-test port 8080 is already in use by PID $($port8080.OwningProcess). The formal Firestore emulator on 18080 should remain untouched."
}

Write-Host "`n==> Continuing at the exact failed stage: Firestore Rules emulator proof" -ForegroundColor Cyan
Invoke-PipeBuyerFirebaseCli `
  -Arguments @(
    'emulators:exec',
    '--only', 'firestore',
    '--project', 'demo-pipe-buyer-dispatch-directory-rules',
    'node --test firebase/rules-tests/dispatch_directory_rules.test.js'
  ) `
  -FailureMessage 'Dispatch Directory Firestore Rules emulator proof failed.'

Write-Host "`n==> Confirming Dispatch phase state" -ForegroundColor Cyan
$plan = Get-Content -LiteralPath 'docs/DISPATCH_NETWORK_MASTER_PLAN.md' -Raw
foreach ($marker in @(
  '**Current verified completion:** **52%**',
  '| 3 | Provider/company profile system | 15 | 15 | GREEN |',
  '| 4 | Dispatch Service Directory + map | 20 | 0 | IN PROGRESS |'
)) {
  if (-not $plan.Contains($marker)) {
    throw "STOP: Dispatch master plan is missing accepted Phase 3 / active Phase 4 marker: $marker"
  }
}

foreach ($target in $productionFiles) {
  $after = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
  if ($after -ne $hashBefore[$target]) {
    throw "STOP: Read-only Phase 4 continuation modified production source: $target"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER PHASE 4 DIRECTORY PROJECTION CONTINUATION PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Previously applied Directory source: PASS' -ForegroundColor Green
Write-Host 'Projection/privacy contracts: PASS' -ForegroundColor Green
Write-Host 'Functions syntax: PASS' -ForegroundColor Green
Write-Host 'Firebase CLI global-or-npx fallback: PASS' -ForegroundColor Green
Write-Host 'Firestore Rules emulator proof: PASS' -ForegroundColor Green
Write-Host 'Phase 3: 15/15 GREEN' -ForegroundColor Green
Write-Host 'Phase 4: IN PROGRESS' -ForegroundColor Green
Write-Host 'Production source modified by continuation: NO' -ForegroundColor Green
Write-Host 'Ready for next Phase 4 slice: YES' -ForegroundColor Green
