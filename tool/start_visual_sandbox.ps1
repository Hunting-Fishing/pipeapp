param(
  [switch]$SeedOnly,
  [switch]$SkipSeed,
  [switch]$WithFunctions
)

$fullLauncher = Join-Path $PSScriptRoot 'start_live_test_sandbox.ps1'
if (-not (Test-Path $fullLauncher)) {
  throw 'The full Pipe Buyer integration launcher is missing. Pull the latest pipebuyer-premium-ui branch.'
}

Write-Host 'The old visual-only sandbox has been replaced by the full Pipe Buyer integration sandbox.' -ForegroundColor Yellow
Write-Host 'Auth, Firestore, Functions and Storage will all run locally on dedicated PipeBuyer ports.' -ForegroundColor Cyan

$arguments = @()
if ($SeedOnly) { $arguments += '-SeedOnly' }
if ($SkipSeed) { $arguments += '-SkipSeed' }

& powershell -ExecutionPolicy Bypass -File $fullLauncher @arguments
exit $LASTEXITCODE
