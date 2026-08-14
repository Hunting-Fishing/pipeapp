$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

Write-Step 'Checking Pipe Buyer sandbox branch'
$branch = (git branch --show-current).Trim()
if ($branch -ne 'pipebuyer-premium-ui') {
  throw "This batch is only for pipebuyer-premium-ui. Current branch: $branch"
}
foreach ($command in @('git', 'node', 'dart', 'flutter')) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "$command was not found on PATH."
  }
}

$targets = @(
  'firebase/functions/marketplace_listing_policy.js',
  'firebase/functions/index.js',
  'firebase/functions/communication_command_policy.js',
  'firebase/storage.rules',
  'tool/start_live_test_sandbox.ps1',
  'lib/marketplace/oil_gas_marketplace.dart',
  'lib/marketplace/marketplace_freight_quote.dart',
  'lib/marketplace/marketplace_messages_page.dart',
  'lib/marketplace/marketplace_weight_catalog_admin.dart'
)

$backupDir = Join-Path $repoRoot ('_local_backups\weight_chat_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $backupDir | Out-Null
foreach ($relative in $targets) {
  $sourcePath = Join-Path $repoRoot $relative
  if (Test-Path $sourcePath) {
    $safeName = $relative.Replace('/', '__').Replace('\', '__')
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $backupDir $safeName) -Force
  }
}

function Restore-TargetBackups {
  foreach ($relative in $targets) {
    $safeName = $relative.Replace('/', '__').Replace('\', '__')
    $saved = Join-Path $backupDir $safeName
    if (Test-Path $saved) {
      Copy-Item -LiteralPath $saved -Destination (Join-Path $repoRoot $relative) -Force
    }
  }
}

$committed = $false
try {
  Write-Step 'Applying stable server-side listing weight snapshots'
  & node '.\tool\patch_weight_server_v2.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Server weight patch failed.' }

  Write-Step 'Applying listing-time weight capture'
  & node '.\tool\patch_listing_weight_ui_v1.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Listing weight UI patch failed.' }

  Write-Step 'Applying Dispatch unknown-weight workflow'
  & node '.\tool\patch_freight_unknown_weight_v1.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Dispatch weight patch failed.' }

  Write-Step 'Applying Messages composer/media UX'
  & node '.\tool\patch_chat_media_ux_v1.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Chat media UX patch failed.' }

  Write-Step 'Aligning Storage media limits'
  & node '.\tool\patch_storage_chat_video_v1.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Storage chat-video patch failed.' }

  & node '.\tool\patch_weight_admin_cleanup_v1.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Weight admin cleanup failed.' }
  & node '.\tool\patch_weight_batch_cleanup_v1.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Weight batch cleanup failed.' }

  Write-Step 'Formatting Flutter files'
  & dart format `
    '.\lib\marketplace\marketplace_weight_catalog.dart' `
    '.\lib\marketplace\marketplace_weight_catalog_admin.dart' `
    '.\lib\marketplace\marketplace_admin_transaction_portal.dart' `
    '.\lib\marketplace\marketplace_freight_quote.dart' `
    '.\lib\marketplace\marketplace_messages_page.dart' `
    '.\lib\marketplace\oil_gas_marketplace.dart' `
    '.\test\marketplace_weight_catalog_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }

  Write-Step 'Checking JavaScript syntax'
  foreach ($file in @(
    '.\firebase\functions\marketplace_weight_policy.js',
    '.\firebase\functions\marketplace_listing_policy.js',
    '.\firebase\functions\communication_command_policy.js',
    '.\firebase\functions\index.js',
    '.\firebase\functions\scripts\seed_live_test_weight_catalog.js'
  )) {
    & node --check $file
    if ($LASTEXITCODE -ne 0) { throw "JavaScript syntax check failed: $file" }
  }

  Write-Step 'Running server weight/media regression tests'
  & node --test `
    '.\firebase\functions\test\marketplace_weight_policy.test.js' `
    '.\firebase\functions\test\communication_media_policy.test.js'
  if ($LASTEXITCODE -ne 0) { throw 'Server weight/media policy tests failed.' }

  Write-Step 'Analyzing Flutter application'
  & flutter analyze lib
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze found an issue.' }

  Write-Step 'Running Flutter weight regression tests'
  & flutter test '.\test\marketplace_weight_catalog_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'Marketplace weight catalog Flutter tests failed.' }

  Write-Step 'Checking patch whitespace'
  git diff --check -- @targets
  if ($LASTEXITCODE -ne 0) { throw 'git diff --check found a patch problem.' }

  Write-Step 'Showing targeted batch diff'
  git diff --stat -- @targets

  Write-Step 'Staging only the weight/chat batch'
  git add -- @targets
  git diff --cached --quiet
  $hasChanges = $LASTEXITCODE -ne 0
  if ($hasChanges) {
    git commit -m 'Wire listing weights into Dispatch and improve chat media UX'
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
    $committed = $true

    git push origin pipebuyer-premium-ui
    if ($LASTEXITCODE -ne 0) {
      throw 'The local commit succeeded but git push failed. Your validated commit is safe locally; do not reset it.'
    }
  } else {
    Write-Host 'No new local batch changes needed committing.' -ForegroundColor Yellow
  }

  Write-Host ''
  Write-Host 'Weight catalog + Dispatch + chat media batch validated successfully.' -ForegroundColor Green
  Write-Host "Backup retained at: $backupDir" -ForegroundColor DarkGray
  Write-Host 'Generated Flutter plugin files and unrelated local files were not staged.' -ForegroundColor Green
}
catch {
  Write-Host ''
  if (-not $committed) {
    Write-Host 'Batch validation failed. Restoring only this batch''s target files to their pre-run state...' -ForegroundColor Red
    Restore-TargetBackups
    Write-Host "Pre-run files restored. Backup retained at: $backupDir" -ForegroundColor Yellow
  } else {
    Write-Host 'The validated changes were already committed locally, so no files were restored.' -ForegroundColor Yellow
    Write-Host 'If push failed, the commit remains safe in your local pipebuyer-premium-ui branch.' -ForegroundColor Yellow
  }
  throw
}
