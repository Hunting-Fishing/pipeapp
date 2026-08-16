$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found on PATH."
  }
}

function Test-LocalPort([int]$Port) {
  return $null -ne (
    Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
      Select-Object -First 1
  )
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

foreach ($command in @('git', 'node', 'dart', 'flutter')) {
  Require-Command $command
}

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This helper is for design/formal-beautification-foundation. Current branch: $branch"
}

Write-Host 'Timed Buying trust + participant experience: v2-compact-layout-20260816' -ForegroundColor Green
Write-Host 'Repair record: v1 failed because an old patcher required one exact card indentation.' -ForegroundColor DarkGray
Write-Host 'v2 uses structural/whitespace-tolerant anchors and exact TEMP rollback.' -ForegroundColor DarkGray

$generatedFlutterFiles = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugin_registrant.h',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugin_registrant.h',
  'windows/flutter/generated_plugins.cmake'
)
& git restore -- $generatedFlutterFiles 2>$null

$page = Join-Path $repoRoot 'lib\marketplace\marketplace_auctions_page.dart'
$engagement = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_engagement.dart'
$trust = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_trust.dart'
$presentation = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_presentation.dart'
$trustTest = Join-Path $repoRoot 'test\marketplace_timed_buying_trust_test.dart'
$engagementTest = Join-Path $repoRoot 'test\marketplace_timed_buying_engagement_test.dart'
$presentationTest = Join-Path $repoRoot 'test\marketplace_timed_buying_presentation_test.dart'
$compactTest = Join-Path $repoRoot 'test\marketplace_listing_specs_compact_test.dart'
$backend = Join-Path $repoRoot 'firebase\functions\marketplace_commands.js'
$seed = Join-Path $repoRoot 'firebase\functions\scripts\seed_visual_sandbox.js'
$loadCheck = Join-Path $repoRoot 'firebase\functions\load_check.js'
$patcherV2 = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v2.mjs'
$patcherV3 = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v3.mjs'

$required = @(
  $page, $engagement, $trust, $presentation,
  $trustTest, $engagementTest, $presentationTest, $compactTest,
  $backend, $seed, $patcherV2, $patcherV3
)
foreach ($path in $required) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required Timed Buying trust v2 file is missing: $path"
  }
}

$pageSource = Get-Content -LiteralPath $page -Raw
if (-not $pageSource.Contains('Review & submit timed offer')) {
  throw 'Verified Timed Buying offer submission is missing. Stop rather than replacing the local page.'
}
if (-not $pageSource.Contains('Asset overview')) {
  throw 'Professional compact Asset Overview is missing. Stop rather than replacing the local page.'
}

Write-Step 'Current local work before trust v2'
git status --short

$backupRoot = Join-Path $env:TEMP "pipebuyer-timed-trust-v2-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$editedFiles = @($page, $backend, $seed)
$backups = @{}
foreach ($source in $editedFiles) {
  $backup = Join-Path $backupRoot ((Split-Path -Leaf $source) + '.' + $backups.Count + '.bak')
  Copy-Item -LiteralPath $source -Destination $backup -Force
  $backups[$source] = $backup
}
Write-Host "Exact pre-run backups: $backupRoot" -ForegroundColor DarkGray

$completed = $false
try {
  Write-Step 'Syntax-checking the indentation-tolerant trust migration'
  & node --check $patcherV2
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying trust v2 patcher syntax check failed.' }
  & node --check $patcherV3
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying trust v3 bridge syntax check failed.' }

  Write-Step 'Applying viewer participation, gold trust frame and authenticated activity'
  & node $patcherV3
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying trust v2 structural migration failed.' }

  Write-Step 'Verifying required product markers before formatting'
  $after = Get-Content -LiteralPath $page -Raw
  foreach ($marker in @(
    'TimedBuyingTrustFrame(',
    'TimedBuyingParticipationBadge(',
    'TimedBuyingOfferActivityHeader(',
    'TimedBuyingTrustStrip()',
    '_TimedBuyingBuyerTrustPosition(',
    'TimedBuyingAttentionStrip('
  )) {
    if (-not $after.Contains($marker)) {
      throw "Missing required Timed Buying trust marker after migration: $marker"
    }
  }
  Write-Host 'All trust/participation markers are present.' -ForegroundColor Green

  Write-Step 'Formatting only the Timed Buying surfaces changed by this pass'
  & dart format $page $engagement $trust $trustTest $engagementTest
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed for Timed Buying trust v2.' }

  Write-Step 'Analyzing Timed Buying board, detail, trust and compact specifications'
  & dart analyze $page $engagement $trust $presentation $trustTest $engagementTest $presentationTest $compactTest
  if ($LASTEXITCODE -ne 0) { throw 'Dart analyzer failed for Timed Buying trust v2.' }

  Write-Step 'Running Timed Buying participant/trust contracts'
  & flutter test $trustTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v2
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying trust widget tests failed.' }

  Write-Step 'Running Timed Buying urgency/position regression contracts'
  & flutter test $engagementTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v2
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying engagement regression tests failed.' }

  Write-Step 'Running Timed Buying action regression contracts'
  & flutter test $presentationTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v2
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying presentation regression tests failed.' }

  Write-Step 'Rechecking professional compact Asset Overview contracts'
  & flutter test $compactTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v2
  if ($LASTEXITCODE -ne 0) { throw 'Professional compact Asset Overview regression test failed.' }

  Write-Step 'Checking server-side timed-offer identity snapshot code'
  & node --check $backend
  if ($LASTEXITCODE -ne 0) { throw 'marketplace_commands.js syntax check failed.' }
  & node --check $seed
  if ($LASTEXITCODE -ne 0) { throw 'visual sandbox seed syntax check failed.' }
  if (Test-Path -LiteralPath $loadCheck) {
    & node $loadCheck
    if ($LASTEXITCODE -ne 0) { throw 'Firebase Functions entrypoint load check failed.' }
  }

  $emulatorsReady = (Test-LocalPort 19099) -and (Test-LocalPort 18080)
  if ($emulatorsReady) {
    Write-Step 'Reseeding authenticated multi-participant Timed Buying activity'
    $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
    $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
    $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
    $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
    & node $seed
    if ($LASTEXITCODE -ne 0) { throw 'Visual sandbox reseed failed after Timed Buying trust v2.' }
  }
  else {
    Write-Host 'Auth/Firestore emulators are not both running; fixture reseed skipped.' -ForegroundColor Yellow
  }

  & git restore -- $generatedFlutterFiles 2>$null

  Write-Step 'Timed Buying trust v2 verification passed'
  Write-Host 'Buyer fixture: your offer is highlighted and one authenticated offer is ahead.' -ForegroundColor Green
  Write-Host 'Carrier fixture: verified carrier is the current leading participant.' -ForegroundColor Green
  Write-Host 'Participating listings receive the second animated gold trust border.' -ForegroundColor Green
  Write-Host 'Timed Offer Activity identifies You, verified participant identity and offer status.' -ForegroundColor Green
  Write-Host 'Buyer-position summary shows top offer, lead, amount behind and offers ahead.' -ForegroundColor Green
  Write-Host ''
  git diff --stat
  git status --short
  $completed = $true
}
finally {
  if (-not $completed) {
    Write-Host "`nTimed Buying trust v2 failed; restoring exact pre-run files from TEMP." -ForegroundColor Red
    foreach ($entry in $backups.GetEnumerator()) {
      if (Test-Path -LiteralPath $entry.Value) {
        Copy-Item -LiteralPath $entry.Value -Destination $entry.Key -Force
      }
    }
    Write-Host "Backup directory retained: $backupRoot" -ForegroundColor Yellow
  }
  else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
  & git restore -- $generatedFlutterFiles 2>$null
}
