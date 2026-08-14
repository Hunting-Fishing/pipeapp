param(
  [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'pipebuyer-premium-ui') {
  throw "Switch to pipebuyer-premium-ui before applying this correction batch. Current branch: $branch"
}

$dirty = git status --porcelain
if ($dirty) {
  Write-Host $dirty -ForegroundColor Yellow
  throw 'Working tree is not clean. Preserve the files shown above before running the correction batch.'
}

$patchedFiles = @(
  'lib/marketplace/oil_gas_marketplace.dart',
  'lib/marketplace/marketplace_messages_page.dart',
  'lib/marketplace/marketplace_vip_access.dart',
  'firebase/functions/marketplace_commands.js',
  'firebase/functions/communication_commands.js'
)

try {
  Step 'Applying the requested Listing / Offer / Messages / VIP corrections'
  & node '.\tool\apply_web_corrections_v3.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Web correction patch failed.' }

  Step 'Formatting modified Dart screens'
  & dart format `
    '.\lib\marketplace\oil_gas_marketplace.dart' `
    '.\lib\marketplace\marketplace_messages_page.dart' `
    '.\lib\marketplace\marketplace_vip_access.dart'
  if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }

  Step 'Checking modified Firebase command syntax'
  & node --check '.\firebase\functions\marketplace_commands.js'
  if ($LASTEXITCODE -ne 0) { throw 'Marketplace command syntax check failed.' }
  & node --check '.\firebase\functions\communication_commands.js'
  if ($LASTEXITCODE -ne 0) { throw 'Communication command syntax check failed.' }
  & node --check '.\firebase\functions\marketplace_vip_access_policy.js'
  if ($LASTEXITCODE -ne 0) { throw 'VIP access policy syntax check failed.' }

  Step 'Running full Flutter analysis'
  & flutter analyze lib
  if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }

  Step 'Running focused marketplace UI regression tests'
  & flutter test `
    '.\test\marketplace_offer_analysis_test.dart' `
    '.\test\marketplace_vip_access_test.dart' `
    '.\test\marketplace_listing_media_test.dart' `
    '.\test\marketplace_listing_status_test.dart' `
    '.\test\marketplace_adaptive_layout_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'Focused Flutter tests failed.' }

  Step 'Running VIP server-policy regression test'
  & node --test '.\firebase\functions\test\marketplace_vip_access_policy.test.js'
  if ($LASTEXITCODE -ne 0) { throw 'VIP server-policy test failed.' }

  Step 'Correction batch validated locally'
  git status --short

  if ($NoPush) {
    Write-Host 'NoPush selected. Validated changes remain local for inspection.' -ForegroundColor Yellow
    exit 0
  }

  Step 'Creating one validated sandbox commit'
  git add -- @patchedFiles
  git commit -m 'Complete web offer UX messages and VIP access wiring'
  if ($LASTEXITCODE -ne 0) { throw 'Local commit failed.' }

  Step 'Pushing one validated sandbox commit'
  git push origin pipebuyer-premium-ui
  if ($LASTEXITCODE -ne 0) {
    throw 'Push failed. The validated commit remains safely on this PC.'
  }

  Write-Host "`nWeb corrections V3 pushed successfully." -ForegroundColor Green
} catch {
  Write-Host "`nCorrection batch failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'Restoring only files modified by this batch.' -ForegroundColor Yellow
  git restore -- @patchedFiles
  throw
}
