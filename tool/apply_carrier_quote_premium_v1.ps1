$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function FileHash([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

if ((git branch --show-current).Trim() -ne 'design/formal-beautification-foundation') {
  throw 'Run this only on design/formal-beautification-foundation.'
}

$patcher = Join-Path $PSScriptRoot 'apply_carrier_quote_premium_v1.mjs'
$freight = Join-Path $repoRoot 'lib\marketplace\marketplace_freight_quote.dart'
$assist = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_spec_assist.dart'
$weightCatalog = Join-Path $repoRoot 'lib\marketplace\marketplace_weight_catalog.dart'
$repository = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_repository.dart'
$test = Join-Path $repoRoot 'test\marketplace_dispatch_spec_assist_test.dart'

foreach ($file in @($patcher, $freight, $assist, $weightCatalog, $repository, $test)) {
  if (-not (Test-Path -LiteralPath $file)) { throw "Missing required file: $file" }
}

$backupRoot = Join-Path $env:TEMP "pipebuyer-carrier-quote-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$freightBackup = Join-Path $backupRoot 'marketplace_freight_quote.dart.bak'
Copy-Item -LiteralPath $freight -Destination $freightBackup -Force
$freightHash = FileHash $freight
$complete = $false

try {
  Step 'Syntax-checking premium carrier quote migration'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Carrier quote migration syntax check failed.' }

  Step 'Applying Request Carrier Quotes premium + deferred-weight upgrade'
  & node $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Carrier quote migration failed.' }

  Step 'Formatting only the focused carrier quote files'
  & dart format $freight $assist $test
  if ($LASTEXITCODE -ne 0) { throw 'Dart format failed.' }

  Step 'Running strict analyzer on carrier quote, Spec Assist and Dispatch contracts'
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

  Step 'CARRIER QUOTE PREMIUM V1 PASSED'
  Write-Host 'Request Carrier Quotes now uses the Pipe Buyer black/orange premium presentation.' -ForegroundColor Green
  Write-Host 'Weight can be suggested, manually adjusted, or explicitly deferred until later.' -ForegroundColor Green
  Write-Host 'Spec Assist accepts make/model/year/details and approved-catalog dimensions/weight while keeping a clean AI integration seam.' -ForegroundColor Green
  $complete = $true
}
finally {
  if (-not $complete) {
    if ((FileHash $freight) -ne $freightHash) {
      Copy-Item -LiteralPath $freightBackup -Destination $freight -Force
    }
    Write-Host "Carrier quote upgrade failed; original freight form restored from $backupRoot" -ForegroundColor Yellow
  } else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
