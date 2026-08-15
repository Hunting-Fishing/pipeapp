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
$analyticsTest = Join-Path $repoRoot 'firebase\functions\test\marketplace_listing_insights.test.js'
if (-not (Test-Path $formalLauncher)) {
  throw 'tool/start_formal_test_sandbox.ps1 is missing.'
}
if (-not (Test-Path $reseedHelper)) {
  throw 'tool/reseed_formal_test_data.ps1 is missing.'
}
if (-not (Test-Path $analyticsTest)) {
  throw 'Marketplace listing analytics test is missing.'
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

Write-Step 'Running seller listing analytics function contracts'
& node --test $analyticsTest
if ($LASTEXITCODE -ne 0) {
  throw 'Marketplace listing analytics function test failed.'
}

Write-Step 'Launching Flutter against the already-running verified sandbox'
Write-Host 'Keep the Firebase Emulator window open. Do not press Ctrl+C while testing.' -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File $formalLauncher -SkipSeed
exit $LASTEXITCODE
