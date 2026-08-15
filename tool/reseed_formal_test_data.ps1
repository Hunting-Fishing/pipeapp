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

function Get-CollectionCount([string]$Collection) {
  $uri = "http://127.0.0.1:18080/v1/projects/flutter-flow-pipe/databases/(default)/documents/$Collection?pageSize=100"
  $response = Invoke-RestMethod -Method Get -Uri $uri
  return @($response.documents).Count
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
}

Write-Step 'Verifying seeded Firestore fixtures'
$counts = [ordered]@{
  public_listings = Get-CollectionCount 'public_listings'
  users = Get-CollectionCount 'users'
  conversations = Get-CollectionCount 'conversations'
  offers = Get-CollectionCount 'offers'
  dispatch_jobs = Get-CollectionCount 'dispatch_jobs'
  dispatch_carriers = Get-CollectionCount 'dispatch_carriers'
}

$counts.GetEnumerator() | ForEach-Object {
  Write-Host ("  {0,-20} {1}" -f $_.Key, $_.Value) -ForegroundColor White
}

if ($counts.public_listings -lt 11) {
  throw "Expected at least 11 public listings, found $($counts.public_listings)."
}
if ($counts.users -lt 4) {
  throw "Expected at least 4 users, found $($counts.users)."
}
if ($counts.conversations -lt 2) {
  throw "Expected at least 2 conversations, found $($counts.conversations)."
}
if ($counts.offers -lt 2) {
  throw "Expected at least 2 offers, found $($counts.offers)."
}
if ($counts.dispatch_jobs -lt 2) {
  throw "Expected at least 2 Dispatch jobs, found $($counts.dispatch_jobs)."
}
if ($counts.dispatch_carriers -lt 1) {
  throw "Expected at least 1 Dispatch carrier, found $($counts.dispatch_carriers)."
}

$vipListingUri = 'http://127.0.0.1:18080/v1/projects/flutter-flow-pipe/databases/(default)/documents/public_listings/visual-vip-early-tubing'
$vipListing = Invoke-RestMethod -Method Get -Uri $vipListingUri
if ([string]::IsNullOrWhiteSpace($vipListing.name)) {
  throw 'VIP early-access listing fixture is missing.'
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
Write-Host 'Hard-refresh the Flutter Chrome tab after reseeding (Ctrl+Shift+R).' -ForegroundColor Green
