param(
  [switch]$SeedOnly,
  [switch]$SkipSeed,
  [switch]$SkipSmokeTest
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This launcher tests the formal Pipe Buyer UI branch. Current branch: $branch"
}

$baseLauncher = Join-Path $PSScriptRoot 'start_live_test_sandbox.ps1'
if (-not (Test-Path $baseLauncher)) {
  throw 'tool/start_live_test_sandbox.ps1 is missing. Pull the latest branch first.'
}

# The established integration sandbox predates the formal UI branch and has a
# branch-name guard for pipebuyer-premium-ui. Reuse the exact tested launcher
# rather than duplicating emulator ports, seeds, smoke checks or Flutter flags.
$source = Get-Content -LiteralPath $baseLauncher -Raw
$oldGuard = "if (`$branch -ne 'pipebuyer-premium-ui') {"
$newGuard = "if (`$branch -notin @('pipebuyer-premium-ui', 'design/formal-beautification-foundation')) {"
if (-not $source.Contains($oldGuard)) {
  throw 'The integration sandbox launcher guard changed. Review it before running the formal wrapper.'
}

$generatedLauncher = Join-Path $PSScriptRoot '.start_live_test_sandbox.formal.generated.ps1'
$source = $source.Replace($oldGuard, $newGuard)
Set-Content -LiteralPath $generatedLauncher -Value $source -Encoding UTF8

$arguments = @()
if ($SeedOnly) { $arguments += '-SeedOnly' }
if ($SkipSeed) { $arguments += '-SkipSeed' }
if ($SkipSmokeTest) { $arguments += '-SkipSmokeTest' }

try {
  Write-Host 'Starting the established Pipe Buyer Auth/Firestore/Functions/Storage sandbox against the formal UI branch.' -ForegroundColor Cyan
  & powershell -ExecutionPolicy Bypass -File $generatedLauncher @arguments
  $exitCode = $LASTEXITCODE
  if ($null -eq $exitCode) { $exitCode = 0 }
  exit $exitCode
}
finally {
  Remove-Item -LiteralPath $generatedLauncher -Force -ErrorAction SilentlyContinue
}
