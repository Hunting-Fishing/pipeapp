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

Write-Host 'Timed Buying trust + participant experience: v1-20260816' -ForegroundColor Green
Write-Host 'Safety: exact TEMP backups are used for every product/backend file edited by this pass.' -ForegroundColor DarkGray
Write-Host 'The professional Asset Overview and unrelated marketplace screens are not restored from git HEAD.' -ForegroundColor DarkGray

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
$attentionPatcher = Join-Path $PSScriptRoot 'apply_timed_buying_attention_v2.mjs'
$attentionCompileFix = Join-Path $PSScriptRoot 'fix_timed_buying_engagement_compile_v1.mjs'
$trustPatcher = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v1.mjs'

$required = @(
  $page, $engagement, $trust, $presentation,
  $trustTest, $engagementTest, $presentationTest, $compactTest,
  $backend, $seed, $attentionPatcher, $attentionCompileFix, $trustPatcher
)
foreach ($path in $required) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required Timed Buying trust file is missing: $path. Fetch the latest trust files first."
  }
}

$pageSource = Get-Content -LiteralPath $page -Raw
if (-not $pageSource.Contains('Review & submit timed offer')) {
  throw 'Verified Timed Buying offer submission is missing. Do not apply the trust pass to an older page.'
}
if (-not $pageSource.Contains('Asset overview')) {
  throw 'Professional compact Asset Overview is missing. Preserve the verified compact-detail pass before continuing.'
}

Write-Step 'Current local work before Timed Buying trust enhancement'
git status --short

$backupRoot = Join-Path $env:TEMP "pipebuyer-timed-trust-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$editedFiles = @($page, $engagement, $trust, $trustTest, $backend, $seed)
$backups = @{}
foreach ($source in $editedFiles) {
  $backup = Join-Path $backupRoot ((Split-Path -Leaf $source) + '.' + $backups.Count + '.bak')
  Copy-Item -LiteralPath $source -Destination $backup -Force
  $backups[$source] = $backup
}
Write-Host "Exact pre-run backups: $backupRoot" -ForegroundColor DarkGray

$completed = $false
try {
  Write-Step 'Syntax-checking attention + trust migration helpers'
  foreach ($script in @($attentionPatcher, $attentionCompileFix, $trustPatcher)) {
    & node --check $script
    if ($LASTEXITCODE -ne 0) { throw "JavaScript syntax check failed: $script" }
  }

  $pageSource = Get-Content -LiteralPath $page -Raw
  if (-not $pageSource.Contains('TimedBuyingAttentionFrame(') -and
      -not $pageSource.Contains('TimedBuyingTrustFrame(')) {
    Write-Step 'Applying the stronger Timed Buying urgency/position foundation first'
    & node $attentionCompileFix
    if ($LASTEXITCODE -ne 0) { throw 'Timed Buying attention compile correction failed.' }
    & node $attentionPatcher
    if ($LASTEXITCODE -ne 0) { throw 'Timed Buying attention foundation failed.' }
  }
  else {
    Write-Host 'Timed Buying attention foundation is already present; preserving it.' -ForegroundColor Green
  }

  Write-Step 'Applying participant identity, gold participation frame and trust activity'
  & node $trustPatcher
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying participant trust migration failed.' }

  Write-Step 'Formatting only Timed Buying trust surfaces'
  & dart format $page $engagement $trust $trustTest $engagementTest
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed for Timed Buying trust surfaces.' }

  Write-Step 'Analyzing Timed Buying board, detail, trust and compact specifications'
  & dart analyze $page $engagement $trust $presentation $trustTest $engagementTest $presentationTest $compactTest
  if ($LASTEXITCODE -ne 0) { throw 'Dart analyzer failed for Timed Buying trust changes.' }

  Write-Step 'Running Timed Buying participant/trust widget contracts'
  & flutter test $trustTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying trust widget tests failed.' }

  Write-Step 'Running Timed Buying urgency/position regression contracts'
  & flutter test $engagementTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying engagement regression tests failed.' }

  Write-Step 'Running Timed Buying action regression contracts'
  & flutter test $presentationTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying presentation regression tests failed.' }

  Write-Step 'Rechecking professional compact Asset Overview contracts'
  & flutter test $compactTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust
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

  $emulatorPorts = @(19099, 18080)
  $emulatorsReady = (@($emulatorPorts | Where-Object { Test-LocalPort $_ }).Count -eq $emulatorPorts.Count)
  if ($emulatorsReady) {
    Write-Step 'Reseeding authenticated multi-participant Timed Buying activity'
    $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
    $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
    $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
    $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
    & node $seed
    if ($LASTEXITCODE -ne 0) { throw 'Visual sandbox reseed failed after Timed Buying trust enhancement.' }
  }
  else {
    Write-Host 'Auth/Firestore emulators are not both running; deterministic trust fixture reseed skipped.' -ForegroundColor Yellow
  }

  & git restore -- $generatedFlutterFiles 2>$null

  Write-Step 'Timed Buying trust enhancement verification passed'
  Write-Host 'Expected buyer fixture: Alex Buyer has participated but is outbid by one verified carrier offer.' -ForegroundColor Green
  Write-Host 'Expected carrier fixture: Northline Heavy Haul is the current verified leading participant.' -ForegroundColor Green
  Write-Host 'Cards with viewer participation receive a second animated gold trust/participation border.' -ForegroundColor Green
  Write-Host 'Timed Offer Activity now identifies You, verified participant display names, status and offer sequence.' -ForegroundColor Green
  Write-Host 'No anonymous timed offers: bidderUid remains server-written and authoritative.' -ForegroundColor Green
  Write-Host ''
  git diff --stat
  git status --short
  $completed = $true
}
finally {
  if (-not $completed) {
    Write-Host "`nTimed Buying trust enhancement failed; restoring exact pre-run files from TEMP." -ForegroundColor Red
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
