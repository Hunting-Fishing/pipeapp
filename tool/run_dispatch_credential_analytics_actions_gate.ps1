# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

$repoRoot = $script:PipeBuyerRepoRoot
$applyScript = Join-Path $PSScriptRoot 'apply_dispatch_credential_analytics_actions_v3.ps1'
$sourcePath = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$analyticsTest = Join-Path $repoRoot 'test\marketplace_dispatch_credential_analytics_actions_test.dart'
$persistenceTest = Join-Path $repoRoot 'test\marketplace_dispatch_credential_persistence_discoverability_test.dart'

foreach ($required in @($applyScript, $sourcePath, $analyticsTest, $persistenceTest)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required credential analytics action file is missing: $required"
  }
}

Write-Host "`n==> Parsing the focused credential analytics controls before mutation" -ForegroundColor Cyan
foreach ($target in @($applyScript, $MyInvocation.MyCommand.Path)) {
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $target,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors.Count -gt 0) {
    $details = ($parseErrors | ForEach-Object {
      "line $($_.Extent.StartLineNumber): $($_.Message)"
    }) -join '; '
    throw "STOP: PowerShell parse preflight failed for $target - $details"
  }
}
Write-Host 'Focused PowerShell parse preflight: PASS' -ForegroundColor Green

Write-Host "`n==> Applying bounded credential analytics interaction repair" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File $applyScript
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics interaction repair failed.'
}

Write-Host "`n==> Running credential analytics interaction contract" -ForegroundColor Cyan
& flutter test $analyticsTest
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics interaction contract failed.'
}

Write-Host "`n==> Re-running credential persistence/discoverability contract" -ForegroundColor Cyan
& flutter test $persistenceTest
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential persistence/discoverability regression failed.'
}

Write-Host "`n==> Proving formatter stability" -ForegroundColor Cyan
& dart format --output=none --set-exit-if-changed $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics source is not formatter stable.'
}

Write-Host "`n==> Running strict analyzer on credential analytics source" -ForegroundColor Cyan
& dart analyze --fatal-infos --fatal-warnings $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics strict analyzer failed.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER CREDENTIAL ANALYTICS ACTIONS GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Duplicate Analytics shortcut cards removed: PASS' -ForegroundColor Green
Write-Host 'Top Records / Analytics & alerts tabs retained: PASS' -ForegroundColor Green
Write-Host 'Current / Expired / Not provided drill-down: PASS' -ForegroundColor Green
Write-Host 'Evidence-file drill-down and management actions: PASS' -ForegroundColor Green
Write-Host 'Insurance-limit drill-down: PASS' -ForegroundColor Green
Write-Host 'Credential persistence regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by this gate: NO' -ForegroundColor Green
Write-Host 'Ready for browser acceptance: YES' -ForegroundColor Green
