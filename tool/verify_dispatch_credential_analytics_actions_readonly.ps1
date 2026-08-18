# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

$repoRoot = $script:PipeBuyerRepoRoot
$sourcePath = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$analyticsTest = Join-Path $repoRoot 'test\marketplace_dispatch_credential_analytics_actions_test.dart'
$persistenceTest = Join-Path $repoRoot 'test\marketplace_dispatch_credential_persistence_discoverability_test.dart'

foreach ($required in @($sourcePath, $analyticsTest, $persistenceTest)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required read-only credential analytics verification file is missing: $required"
  }
}

Write-Host "`n==> Confirming the already-applied credential analytics source contract" -ForegroundColor Cyan
$source = Get-Content -LiteralPath $sourcePath -Raw
$requiredMarkers = @(
  "text: 'Analytics & alerts'",
  "title: 'Credential readiness'",
  'Select any status tile below',
  'Future<void> _showCredentialMetricDetails',
  'Future<void> _showCredentialQuickActions',
  "'View details'",
  'button: true',
  'records: current',
  'records: expired',
  'records: missing',
  'records: evidenceRecords',
  'records: insuranceWithLimits',
  "pop('edit')",
  "pop('evidence')",
  "pop('remove_evidence')"
)
foreach ($marker in $requiredMarkers) {
  if (-not $source.Contains($marker)) {
    throw "STOP: Already-applied credential analytics source is missing semantic marker: $marker"
  }
}
if ($source.Contains('Open analytics & alerts')) {
  throw 'STOP: Duplicate Records-view Analytics shortcut is still present.'
}
Write-Host 'Already-applied analytics interaction source: PASS' -ForegroundColor Green

$sourceHashBefore = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash

Write-Host "`n==> Running semantic credential analytics interaction contract" -ForegroundColor Cyan
& flutter test $analyticsTest
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics interaction contract failed.'
}

Write-Host "`n==> Re-running credential persistence regression" -ForegroundColor Cyan
& flutter test $persistenceTest
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential persistence regression failed.'
}

Write-Host "`n==> Proving formatter stability without changing source" -ForegroundColor Cyan
& dart format --output=none --set-exit-if-changed $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics source is not formatter stable.'
}

Write-Host "`n==> Running strict analyzer" -ForegroundColor Cyan
& dart analyze --fatal-infos --fatal-warnings $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics strict analyzer failed.'
}

$sourceHashAfter = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
  throw 'STOP: Read-only credential analytics verifier modified production source.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER CREDENTIAL ANALYTICS READ-ONLY VERIFIER PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Already-applied analytics interaction source: PASS' -ForegroundColor Green
Write-Host 'Semantic action contract: PASS' -ForegroundColor Green
Write-Host 'Credential persistence regression: PASS' -ForegroundColor Green
Write-Host 'Formatter stability: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host 'Production source modified by verifier: NO' -ForegroundColor Green
Write-Host 'Ready for browser acceptance: YES' -ForegroundColor Green
