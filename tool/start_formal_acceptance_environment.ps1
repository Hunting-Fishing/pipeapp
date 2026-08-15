$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This helper is for design/formal-beautification-foundation. Current branch: $branch"
}

$formalLauncher = Join-Path $PSScriptRoot 'start_formal_test_sandbox.ps1'
$reseedHelper = Join-Path $PSScriptRoot 'reseed_formal_test_data.ps1'
$clientLauncher = Join-Path $PSScriptRoot 'launch_formal_flutter_client.ps1'
$analyticsTest = Join-Path $repoRoot 'firebase\functions\test\marketplace_listing_insights.test.js'
$timedBuyingSmoke = Join-Path $repoRoot 'firebase\functions\integration\timed_buying_sandbox.mjs'
if (-not (Test-Path $formalLauncher)) {
  throw 'tool/start_formal_test_sandbox.ps1 is missing.'
}
if (-not (Test-Path $reseedHelper)) {
  throw 'tool/reseed_formal_test_data.ps1 is missing.'
}
if (-not (Test-Path $clientLauncher)) {
  throw 'tool/launch_formal_flutter_client.ps1 is missing.'
}
if (-not (Test-Path $analyticsTest)) {
  throw 'Marketplace listing analytics test is missing.'
}
if (-not (Test-Path $timedBuyingSmoke)) {
  throw 'Timed Buying sandbox callable smoke test is missing.'
}

Write-Step 'Starting Pipe Buyer emulators, deterministic fixtures and smoke tests'
& powershell -ExecutionPolicy Bypass -File $formalLauncher -SeedOnly
if ($LASTEXITCODE -ne 0) {
  throw 'Formal sandbox seed/smoke phase failed.'
}

Write-Step 'Refreshing and verifying the complete acceptance dataset including analytics'
& powershell -ExecutionPolicy Bypass -File $reseedHelper
if ($LASTEXITCODE -ne 0) {
  throw 'Formal test-data verification failed.'
}

Write-Step 'Proving Timed Buying offer submission through Auth + Functions + Firestore'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
$env:FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:19199'
$env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:15001'
$env:GCLOUD_PROJECT = 'flutter-flow-pipe'
$env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
& node $timedBuyingSmoke
if ($LASTEXITCODE -ne 0) {
  throw 'Timed Buying callable smoke test failed. Read the error above before opening Flutter.'
}

Write-Step 'Confirming deterministic fixtures after Timed Buying smoke cleanup'
& powershell -ExecutionPolicy Bypass -File $reseedHelper -SkipSeed
if ($LASTEXITCODE -ne 0) {
  throw 'Formal test-data verification failed after Timed Buying smoke cleanup.'
}

Write-Step 'Running seller listing analytics function contracts'
& node --test $analyticsTest
if ($LASTEXITCODE -ne 0) {
  throw 'Marketplace listing analytics function test failed.'
}

Write-Step 'Launching Flutter against the already-running verified sandbox'
Write-Host 'Keep the Firebase Emulator window open. Do not press Ctrl+C while testing.' -ForegroundColor Yellow
Write-Host 'Pipe Buyer local app will use http://127.0.0.1:5050' -ForegroundColor Green
& powershell -ExecutionPolicy Bypass -File $clientLauncher
exit $LASTEXITCODE
