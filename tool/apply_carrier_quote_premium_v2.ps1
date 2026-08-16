$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function FileHash([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Port-In-Use([int]$Port) {
  return $null -ne (
    Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
      Select-Object -First 1
  )
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

if ((git branch --show-current).Trim() -ne 'design/formal-beautification-foundation') {
  throw 'Run this only on design/formal-beautification-foundation.'
}

$patcher = Join-Path $PSScriptRoot 'apply_carrier_quote_premium_v1.mjs'
$finalizer = Join-Path $PSScriptRoot 'finalize_carrier_quote_deferred_weight_v1.mjs'
$freight = Join-Path $repoRoot 'lib\marketplace\marketplace_freight_quote.dart'
$assist = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_spec_assist.dart'
$weightCatalog = Join-Path $repoRoot 'lib\marketplace\marketplace_weight_catalog.dart'
$repository = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_repository.dart'
$test = Join-Path $repoRoot 'test\marketplace_dispatch_spec_assist_test.dart'
$seed = Join-Path $repoRoot 'firebase\functions\scripts\seed_live_test_weight_catalog.js'

foreach ($file in @($patcher, $finalizer, $freight, $assist, $weightCatalog, $repository, $test, $seed)) {
  if (-not (Test-Path -LiteralPath $file)) { throw "Missing required file: $file" }
}

$backupRoot = Join-Path $env:TEMP "pipebuyer-carrier-quote-v2-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$freightBackup = Join-Path $backupRoot 'marketplace_freight_quote.dart.bak'
Copy-Item -LiteralPath $freight -Destination $freightBackup -Force
$freightHash = FileHash $freight
$complete = $false

try {
  Step 'Syntax-checking premium carrier quote migrations'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Carrier quote migration syntax check failed.' }
  & node --check $finalizer
  if ($LASTEXITCODE -ne 0) { throw 'Deferred-weight finalizer syntax check failed.' }
  & node --check $seed
  if ($LASTEXITCODE -ne 0) { throw 'Dispatch spec reference seed syntax check failed.' }

  Step 'Applying Request Carrier Quotes premium + Spec Assist upgrade'
  & node $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Carrier quote premium migration failed.' }

  Step 'Making explicit unknown weight truly nonbinding'
  & node $finalizer
  if ($LASTEXITCODE -ne 0) { throw 'Deferred-weight finalizer failed.' }

  Step 'Formatting only the focused carrier quote files'
  & dart format $freight $assist $test
  if ($LASTEXITCODE -ne 0) { throw 'Dart format failed.' }

  Step 'Running strict analyzer on carrier quote + Spec Assist contracts'
  & dart analyze --fatal-infos --fatal-warnings `
    $freight `
    $assist `
    $weightCatalog `
    $repository `
    $test
  if ($LASTEXITCODE -ne 0) { throw 'Strict carrier quote analyzer gate failed.' }

  Step 'Running Spec Assist contract tests'
  & flutter test $test
  if ($LASTEXITCODE -ne 0) { throw 'Spec Assist tests failed.' }

  Step 'Checking deferred-weight and premium form markers'
  $text = Get-Content -LiteralPath $freight -Raw
  foreach ($marker in @(
    'PIPEBUYER_CARRIER_QUOTE_PREMIUM_V1',
    'MarketplaceDispatchSpecAssistPanel(',
    "I don't know — add later",
    'weightUnknown: _weightUnknown',
    'weightSource: draft.weightSource',
    'draft.weightUnknown ? null : estimate.kg',
    'TO CONFIRM — add before final dispatch planning',
    'marketplaceWeightDisclaimer'
  )) {
    if (-not $text.Contains($marker)) {
      throw "Carrier quote contract marker missing: $marker"
    }
  }
  if ($text.Contains('weightKg: _enteredWeight!')) {
    throw 'Deferred weight is still force-unwrapped.'
  }

  if (Port-In-Use 18080) {
    Step 'Seeding approved Spec Assist references into the running local Firestore emulator'
    $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
    $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
    $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
    & node $seed
    if ($LASTEXITCODE -ne 0) { throw 'Dispatch spec reference seed failed.' }
  } else {
    Write-Host 'Firestore emulator is not running; code validation passed but local Spec Assist references were not seeded.' -ForegroundColor Yellow
  }

  Step 'CARRIER QUOTE PREMIUM V2 PASSED'
  Write-Host 'Request Carrier Quotes now uses Pipe Buyer black/orange premium presentation.' -ForegroundColor Green
  Write-Host 'Weight can be suggested, manually adjusted, or explicitly deferred until later.' -ForegroundColor Green
  Write-Host 'Choosing I do not know sends no weight into carrier payload suitability checks until the shipper confirms it.' -ForegroundColor Green
  Write-Host 'Spec Assist accepts make/model/year/details plus approximate transport dimensions and reviewed planning weights.' -ForegroundColor Green
  Write-Host 'The integration seam is AI-ready without presenting unverified AI guesses as manufacturer facts.' -ForegroundColor Green
  $complete = $true
}
finally {
  if (-not $complete) {
    if ((FileHash $freight) -ne $freightHash) {
      Copy-Item -LiteralPath $freightBackup -Destination $freight -Force
    }
    Write-Host "Carrier quote V2 failed; original freight form restored from $backupRoot" -ForegroundColor Yellow
  } else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
