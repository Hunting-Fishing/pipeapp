$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

Write-Step 'Checking Pipe Buyer sandbox branch'
$branch = (git branch --show-current).Trim()
if ($branch -ne 'pipebuyer-premium-ui') {
  throw "This patch is only for pipebuyer-premium-ui. Current branch: $branch"
}

$target = 'lib/marketplace/oil_gas_marketplace.dart'
$targetStatus = git status --porcelain -- $target
if ($targetStatus) {
  throw "$target has local changes. Commit/stash them before applying the Make Offer V4 patch."
}

$backup = Join-Path $env:TEMP 'pipebuyer_oil_gas_marketplace_offer_v4.dart.bak'
Copy-Item -LiteralPath $target -Destination $backup -Force

try {
  Write-Step 'Applying static listing + live offer + analytics redesign'
  & node '.\tool\apply_offer_summary_v4.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'The Make Offer patcher failed.' }

  Write-Step 'Formatting changed Dart files'
  & dart format `
    '.\lib\marketplace\oil_gas_marketplace.dart' `
    '.\lib\marketplace\marketplace_offer_analysis.dart' `
    '.\lib\marketplace\marketplace_offer_commerce_summary.dart'
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }

  Write-Step 'Analyzing the Flutter application'
  & flutter analyze lib
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze found an issue.' }

  Write-Step 'Testing offer calculations'
  & flutter test '.\test\marketplace_offer_analysis_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'Marketplace offer analysis tests failed.' }

  & flutter test '.\test\marketplace_offer_commerce_summary_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'Marketplace offer commerce tests failed.' }

  Write-Step 'Committing the validated live-screen wiring'
  git add -- $target
  $staged = git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) {
    Write-Host 'The Make Offer V4 patch was already present; nothing new to commit.' -ForegroundColor Yellow
  } else {
    git commit -m 'Wire static listing and live offer summary'
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
    git push origin pipebuyer-premium-ui
    if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
  }

  Write-Host ''
  Write-Host 'Make Offer V4 validated successfully.' -ForegroundColor Green
  Write-Host 'Original listing values now stay static while buyer values and analytics update live.' -ForegroundColor Green
}
catch {
  Write-Host ''
  Write-Host 'Validation failed. Restoring the Marketplace screen from its backup...' -ForegroundColor Red
  Copy-Item -LiteralPath $backup -Destination $target -Force
  git reset -- $target | Out-Null
  throw
}
finally {
  Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
}
