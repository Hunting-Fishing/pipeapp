param(
  [switch]$SeedOnly,
  [switch]$SkipSeed,
  [switch]$SkipSmokeTest
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'listing-lifecycle-nav-v1') {
  throw "Run this review launcher only from listing-lifecycle-nav-v1. Current branch: $branch"
}

$source = Join-Path $PSScriptRoot 'start_live_test_sandbox.ps1'
if (-not (Test-Path $source)) {
  throw 'The full Pipe Buyer integration launcher is missing.'
}

$runtime = Join-Path $PSScriptRoot '.start_listing_lifecycle_review_runtime.ps1'
$text = Get-Content -LiteralPath $source -Raw
$before = @"
if (`$branch -ne 'pipebuyer-premium-ui') {
  throw "This launcher is for pipebuyer-premium-ui. Current branch: `$branch"
}
"@
$after = @"
if (`$branch -notin @('pipebuyer-premium-ui', 'listing-lifecycle-nav-v1')) {
  throw "This launcher is for approved Pipe Buyer integration-review branches. Current branch: `$branch"
}
"@

if (-not $text.Contains($before)) {
  throw 'The integration launcher branch guard has changed. Update this review wrapper before running it.'
}

$text = $text.Replace($before, $after)
Set-Content -LiteralPath $runtime -Value $text -Encoding UTF8

$arguments = @()
if ($SeedOnly) { $arguments += '-SeedOnly' }
if ($SkipSeed) { $arguments += '-SkipSeed' }
if ($SkipSmokeTest) { $arguments += '-SkipSmokeTest' }

try {
  Write-Host 'Launching the full Pipe Buyer integration sandbox for listing-lifecycle-nav-v1.' -ForegroundColor Cyan
  Write-Host 'This uses local Auth, Firestore, Functions and Storage only; production data is not read or written.' -ForegroundColor Green
  & powershell -ExecutionPolicy Bypass -File $runtime @arguments
  exit $LASTEXITCODE
}
finally {
  Remove-Item -LiteralPath $runtime -Force -ErrorAction SilentlyContinue
}
