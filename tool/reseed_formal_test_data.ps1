param(
  [switch]$SkipSeed
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Require-Port([int]$Port, [string]$Label) {
  $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $listener) {
    throw "$Label is not listening on port $Port. Start tool/start_formal_test_sandbox.ps1 first."
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This helper is for design/formal-beautification-foundation. Current branch: $branch"
}

Write-Step 'Checking full Pipe Buyer emulator suite'
Require-Port 19099 'Auth emulator'
Require-Port 18080 'Firestore emulator'
Require-Port 15001 'Functions emulator'
Require-Port 19199 'Storage emulator'
Require-Port 14000 'Emulator UI'

$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
$env:FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:19199'
$env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:15001'
$env:GCLOUD_PROJECT = 'flutter-flow-pipe'
$env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'

$functionsDir = Join-Path $repoRoot 'firebase\functions'

if (-not $SkipSeed) {
  Write-Step 'Reseeding deterministic Pipe Buyer test fixtures'
  & node (Join-Path $functionsDir 'scripts\seed_visual_sandbox.js')
  if ($LASTEXITCODE -ne 0) { throw 'Visual sandbox seed failed.' }

  & node (Join-Path $functionsDir 'scripts\seed_live_test_memberships.js')
  if ($LASTEXITCODE -ne 0) { throw 'VIP/standard membership seed failed.' }

  & node (Join-Path $functionsDir 'scripts\seed_live_test_dispatch_access.js')
  if ($LASTEXITCODE -ne 0) { throw 'Dispatch access seed failed.' }

  & node (Join-Path $functionsDir 'scripts\seed_live_test_weight_catalog.js')
  if ($LASTEXITCODE -ne 0) { throw 'Dispatch weight/spec catalog seed failed.' }

  & node (Join-Path $functionsDir 'scripts\seed_live_test_listing_analytics.js')
  if ($LASTEXITCODE -ne 0) { throw 'Listing analytics seed failed.' }

  & node (Join-Path $functionsDir 'scripts\seed_live_test_timed_buying_labels.js')
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying public-label seed failed.' }
}

Write-Step 'Verifying seeded Firestore and Auth fixtures'
$verifier = Join-Path $functionsDir 'scripts\verify_visual_sandbox.js'
if (-not (Test-Path -LiteralPath $verifier)) {
  throw 'firebase/functions/scripts/verify_visual_sandbox.js is missing. Pull the latest formal branch.'
}

& node $verifier
if ($LASTEXITCODE -ne 0) {
  throw 'Formal test-data verification failed.'
}

Write-Step 'Pipe Buyer formal test data is ready'
Write-Host 'Emulator UI: http://127.0.0.1:14000' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Test accounts (LOCAL EMULATORS ONLY)' -ForegroundColor Yellow
Write-Host '  VIP buyer : buyer.visual@pipebuyer.test' -ForegroundColor White
Write-Host '  Standard  : standard.visual@pipebuyer.test' -ForegroundColor White
Write-Host '  Seller    : seller.visual@pipebuyer.test' -ForegroundColor White
Write-Host '  Carrier   : carrier.visual@pipebuyer.test' -ForegroundColor White
Write-Host '  Password  : PipeBuyerDemo!2026' -ForegroundColor White
Write-Host ''
Write-Host 'Listing analytics fixtures are seeded for the seller inventory.' -ForegroundColor Green
Write-Host 'Dispatch Spec Assist references are seeded for Caterpillar 320 and Bobcat S160.' -ForegroundColor Green
Write-Host 'Timed Buying public labels and closing-time fixtures are seeded.' -ForegroundColor Green
Write-Host 'Hard-refresh the Flutter Chrome tab after reseeding (Ctrl+Shift+R).' -ForegroundColor Green
