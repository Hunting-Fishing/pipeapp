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
Write-Host "`n==> Fetching Phase 4 controls without merging" -ForegroundColor Cyan
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal Phase 4 controls.'
}

$supportFiles = @(
  'tool/pipebuyer_firebase_cli.ps1',
  'tool/finalize_dispatch_phase3_browser_acceptance.mjs',
  'tool/apply_dispatch_phase4_directory_projection.mjs',
  'firebase/functions/test/dispatch_directory_projection.test.js',
  'firebase/functions/test/dispatch_directory_security_contract.test.js',
  'firebase/rules-tests/dispatch_directory_rules.test.js',
  'firebase/rules-tests/package.json',
  'docs/DISPATCH_PHASE4_DIRECTORY_PROJECTION.md',
  'docs/repairs/FIREBASE_CLI_WINDOWS_FALLBACK.md'
)

Write-Host "`n==> Synchronizing Phase 4 support/test controls" -ForegroundColor Cyan
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize Phase 4 support/test controls.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage Phase 4 support/test controls.'
}

Write-Host "`n==> Preflighting Windows Firebase CLI before any Phase 4 mutation" -ForegroundColor Cyan
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

$productionModule = 'firebase/functions/dispatch_directory_projection.js'
$productionModulePath = Join-Path $repoRoot ($productionModule.Replace('/', '\'))
if (Test-Path -LiteralPath $productionModulePath) {
  $localText = Get-Content -LiteralPath $productionModulePath -Raw
  if (-not $localText.Contains('function createDispatchDirectoryProjection')) {
    throw "STOP: Existing $productionModule is not the recognized Pipe Buyer Directory module. It was not overwritten."
  }
  $remoteText = & git show "$remote`:$productionModule"
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Could not read the formal $productionModule for comparison."
  }
  $localNormalized = $localText.Replace("`r`n", "`n").TrimEnd()
  $remoteNormalized = (($remoteText -join "`n").Replace("`r`n", "`n")).TrimEnd()
  if ($localNormalized -ne $remoteNormalized) {
    throw "STOP: Local $productionModule differs from the reviewed formal module. It was not overwritten."
  }
  Write-Host 'Recognized existing reviewed Directory projection module.' -ForegroundColor DarkGray
} else {
  & git checkout $remote -- $productionModule
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Could not install new production module $productionModule."
  }
  & git reset -q HEAD -- $productionModule
  Write-Host 'Installed new bounded Directory projection module.' -ForegroundColor Green
}

Write-Host "`n==> Preflighting every declared control before mutation" -ForegroundColor Cyan
$nodeControls = @(
  'tool/finalize_dispatch_phase3_browser_acceptance.mjs',
  'tool/apply_dispatch_phase4_directory_projection.mjs',
  'firebase/functions/dispatch_directory_projection.js',
  'firebase/functions/test/dispatch_directory_projection.test.js',
  'firebase/functions/test/dispatch_directory_security_contract.test.js',
  'firebase/rules-tests/dispatch_directory_rules.test.js'
)
foreach ($target in $nodeControls) {
  & node --check $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Node parse preflight failed for $target"
  }
}
Write-Host 'Declared Phase 4 Node controls parse preflight: PASS' -ForegroundColor Green

Write-Host "`n==> Recording accepted Phase 3 browser completion" -ForegroundColor Cyan
& node '.\tool\finalize_dispatch_phase3_browser_acceptance.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Phase 3 browser acceptance finalization failed.'
}

Write-Host "`n==> Applying atomic Phase 4 Directory projection/schema + rules" -ForegroundColor Cyan
& node '.\tool\apply_dispatch_phase4_directory_projection.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Phase 4 Directory projection installer failed.'
}

Write-Host "`n==> Running focused Directory projection and privacy tests" -ForegroundColor Cyan
& node --test `
  '.\firebase\functions\test\dispatch_directory_projection.test.js' `
  '.\firebase\functions\test\dispatch_directory_security_contract.test.js'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory projection/privacy contracts failed.'
}

Write-Host "`n==> Checking Functions syntax after projection wiring" -ForegroundColor Cyan
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
  Write-Host "`n==> Installing the pinned Firestore rules-test dependencies" -ForegroundColor Cyan
  & npm ci --prefix '.\firebase\rules-tests'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Firestore rules-test dependencies could not be installed.'
  }
}

$port8080 = Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($port8080) {
  throw "STOP: Dedicated rules-test port 8080 is already in use by PID $($port8080.OwningProcess). The formal Firestore emulator on 18080 should remain untouched."
}

Write-Host "`n==> Running dedicated Firestore Rules emulator proof on port 8080" -ForegroundColor Cyan
Invoke-PipeBuyerFirebaseCli `
  -Arguments @(
    'emulators:exec',
    '--only', 'firestore',
    '--project', 'demo-pipe-buyer-dispatch-directory-rules',
    'node --test firebase/rules-tests/dispatch_directory_rules.test.js'
  ) `
  -FailureMessage 'Dispatch Directory Firestore Rules emulator proof failed.'

Write-Host "`n==> Confirming Phase 3 completion and Phase 4 gate state" -ForegroundColor Cyan
$plan = Get-Content -LiteralPath '.\docs\DISPATCH_NETWORK_MASTER_PLAN.md' -Raw
foreach ($marker in @(
  '**Current verified completion:** **52%**',
  '| 3 | Provider/company profile system | 15 | 15 | GREEN |',
  '| 4 | Dispatch Service Directory + map | 20 | 0 | IN PROGRESS |',
  'Next permitted task: build server-owned Directory projection/schema + security rules'
)) {
  if (-not $plan.Contains($marker)) {
    throw "STOP: Dispatch master plan is missing finalized Phase 3 / Phase 4 marker: $marker"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH PHASE 4 DIRECTORY PROJECTION GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Phase 3 browser acceptance finalization: PASS' -ForegroundColor Green
Write-Host 'Overall Dispatch completion: 52/100 = 52%' -ForegroundColor Green
Write-Host 'Phase 3: 15/15 GREEN' -ForegroundColor Green
Write-Host 'Phase 4: 0/20 IN PROGRESS' -ForegroundColor Green
Write-Host 'Server-owned Directory projection/schema: PASS' -ForegroundColor Green
Write-Host 'Active-provider publication/removal logic: PASS' -ForegroundColor Green
Write-Host 'Private identifier/contact/credential exclusion: PASS' -ForegroundColor Green
Write-Host 'Unsupported verification claims blocked: PASS' -ForegroundColor Green
Write-Host 'Approximate map point + geohash projection: PASS' -ForegroundColor Green
Write-Host 'Client Directory writes blocked by rules: PASS' -ForegroundColor Green
Write-Host 'Signed-in Directory reads with Dispatch gate: PASS' -ForegroundColor Green
Write-Host 'Functions syntax: PASS' -ForegroundColor Green
Write-Host 'Firebase CLI global-or-npx fallback: PASS' -ForegroundColor Green
Write-Host 'Phase 4 points awarded by this engineering gate: 0' -ForegroundColor Green
Write-Host 'Next permitted task: Directory repository/query layer' -ForegroundColor Green
