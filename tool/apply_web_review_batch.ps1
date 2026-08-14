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
  throw "Switch to pipebuyer-premium-ui before applying the web review batch. Current branch: $branch"
}

$dirty = git status --porcelain
if ($dirty) {
  Write-Host $dirty -ForegroundColor Yellow
  throw 'Working tree is not clean. Preserve the files shown above before running this batch.'
}

$patchedFiles = @(
  'lib/marketplace/oil_gas_marketplace.dart',
  'lib/marketplace/marketplace_messages_page.dart',
  'lib/marketplace/marketplace_vip_access.dart',
  'firebase/functions/marketplace_commands.js',
  'firebase/functions/communication_commands.js'
)

try {
  Step 'Applying listing, offer, deal-room and VIP server changes'
  & node '.\tool\apply_web_marketplace_review_v2.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Core web review patch failed.' }

  Step 'Wiring VIP / Dispatch subscription artwork slots'
  & node '.\tool\apply_subscription_artwork_patch.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Subscription artwork patch failed.' }

  Step 'Running final full local Dart analysis'
  & flutter analyze lib
  if ($LASTEXITCODE -ne 0) { throw 'Full Flutter analysis failed.' }

  Step 'Running focused marketplace regression tests'
  & flutter test `
    test\marketplace_offer_analysis_test.dart `
    test\marketplace_vip_access_test.dart `
    test\marketplace_listing_media_test.dart `
    test\marketplace_listing_status_test.dart `
    test\marketplace_adaptive_layout_test.dart
  if ($LASTEXITCODE -ne 0) { throw 'Focused marketplace tests failed.' }

  Step 'Testing VIP early-access server policy'
  & node --test 'firebase\functions\test\marketplace_vip_access_policy.test.js'
  if ($LASTEXITCODE -ne 0) { throw 'VIP server policy test failed.' }

  Step 'Review batch validated locally'
  git status --short

  if ($NoPush) {
    Write-Host 'NoPush selected. Changes remain local for review.' -ForegroundColor Yellow
    exit 0
  }

  Step 'Creating one sandbox commit'
  foreach ($file in $patchedFiles) {
    git add -- $file
    if ($LASTEXITCODE -ne 0) { throw "Could not stage $file" }
  }
  git commit -m 'Refine web offers deal room and VIP early access'
  if ($LASTEXITCODE -ne 0) { throw 'Local commit failed.' }

  Step 'Pushing one validated sandbox batch'
  git push origin pipebuyer-premium-ui
  if ($LASTEXITCODE -ne 0) { throw 'Sandbox push failed. The validated commit remains safely on this PC.' }

  Write-Host '`nWeb review batch pushed successfully.' -ForegroundColor Green
} catch {
  Write-Host "`nBatch failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'The batch began from a clean working tree. Restoring only the five patched tracked files.' -ForegroundColor Yellow
  foreach ($file in $patchedFiles) {
    git restore -- $file
  }
  throw
}
