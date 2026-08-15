param(
  [switch]$CommitAndPush
)

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

Require-Command 'git'
Require-Command 'node'
Require-Command 'dart'
Require-Command 'flutter'

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This helper is for design/formal-beautification-foundation. Current branch: $branch"
}

# Flutter tooling can rewrite these tracked registrant files after dependency
# restoration even when there is no intentional source change. They are safe to
# restore to the branch version before this migration. Any other local change is
# treated as user work and blocks the migration.
$generatedFlutterFiles = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugin_registrant.h',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugin_registrant.h',
  'windows/flutter/generated_plugins.cmake'
)

$statusLines = @(git status --porcelain)
if ($statusLines.Count -gt 0) {
  $localPaths = @(
    $statusLines | ForEach-Object {
      if ($_.Length -ge 4) { $_.Substring(3).Trim().Trim('"') }
    }
  )
  $nonGeneratedChanges = @(
    $localPaths | Where-Object { $_ -and $_ -notin $generatedFlutterFiles }
  )
  if ($nonGeneratedChanges.Count -gt 0) {
    git status --short
    throw 'Local source changes detected. Commit/stash them before applying the Timed Buying migration.'
  }

  Write-Step 'Restoring Flutter-generated plugin registrant noise'
  & git restore -- $generatedFlutterFiles
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not restore Flutter-generated registrant files.'
  }
}

if (git status --porcelain) {
  git status --short
  throw 'Local changes remain after generated-file cleanup. Commit/stash them before applying the Timed Buying migration.'
}

$patcher = Join-Path $PSScriptRoot 'apply_timed_buying_experience_v1.mjs'
if (-not (Test-Path $patcher)) {
  throw 'tool/apply_timed_buying_experience_v1.mjs is missing. Pull the latest formal branch.'
}

$targets = @(
  'lib/marketplace/marketplace_auctions_page.dart',
  'lib/marketplace/marketplace_account_hub.dart',
  'lib/marketplace/marketplace_auth_page.dart',
  'lib/marketplace/oil_gas_marketplace.dart',
  'lib/marketplace/marketplace_auction_settlement.dart',
  'lib/marketplace/marketplace_freight_quote.dart',
  'lib/marketplace/marketplace_public_profile_page.dart',
  'lib/marketplace/marketplace_dispatch_page.dart'
) | Where-Object { Test-Path $_ }

$restoreTargets = @(
  $targets
  'lib/marketplace/marketplace_timed_buying_presentation.dart'
  'test/marketplace_timed_buying_presentation_test.dart'
) | Select-Object -Unique

try {
  Write-Step 'Syntax-checking the Timed Buying migration helper'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying migration helper has a JavaScript syntax error.' }

  Write-Step 'Applying Timed Buying public-language, countdown and urgency experience'
  & node $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying migration helper failed.' }

  # The language migration intentionally changes visible "bids" copy, but the
  # account hub also has a local Dart variable named `bids`. A broad text
  # replacement can turn `final bids =` into invalid `final timed offers =`.
  # Repair that code identifier before formatting/analyzing while preserving the
  # new customer-facing Timed Buying wording.
  $accountHubPath = Join-Path $repoRoot 'lib\marketplace\marketplace_account_hub.dart'
  if (Test-Path -LiteralPath $accountHubPath) {
    $accountHubSource = Get-Content -LiteralPath $accountHubPath -Raw
    $accountHubSource = $accountHubSource.Replace('final timed offers =', 'final bids =')
    Set-Content -LiteralPath $accountHubPath -Value $accountHubSource -Encoding UTF8
  }

  # _auctionTimeLabel now delegates to the shared Timed Buying presentation
  # helper, so the old private _duration formatter is dead code. Remove it to
  # keep the focused analyzer pass clean.
  $timedBuyingPagePath = Join-Path $repoRoot 'lib\marketplace\marketplace_auctions_page.dart'
  if (Test-Path -LiteralPath $timedBuyingPagePath) {
    $timedBuyingPageSource = Get-Content -LiteralPath $timedBuyingPagePath -Raw
    $timedBuyingPageSource = [regex]::Replace(
      $timedBuyingPageSource,
      '(?ms)\r?\nString _duration\(Duration value\) \{.*?\r?\n\}\s*$',
      "`r`n"
    )
    Set-Content -LiteralPath $timedBuyingPagePath -Value $timedBuyingPageSource -Encoding UTF8
  }

  Write-Step 'Formatting changed Flutter sources'
  & dart format @targets 'lib/marketplace/marketplace_timed_buying_presentation.dart' 'test/marketplace_timed_buying_presentation_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed for Timed Buying sources.' }

  Write-Step 'Analyzing Timed Buying Flutter surface'
  & dart analyze `
    'lib/marketplace/marketplace_auctions_page.dart' `
    'lib/marketplace/marketplace_timed_buying_presentation.dart' `
    'lib/marketplace/marketplace_grouped_navigation.dart' `
    'lib/marketplace/marketplace_account_hub.dart' `
    'lib/marketplace/marketplace_auth_page.dart' `
    'lib/marketplace/oil_gas_marketplace.dart' `
    'test/marketplace_timed_buying_presentation_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'Dart analyzer failed for Timed Buying changes.' }

  Write-Step 'Running Timed Buying widget and urgency contracts'
  & flutter test 'test/marketplace_timed_buying_presentation_test.dart' `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-timed-buying
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying Flutter tests failed.' }

  Write-Step 'Syntax-checking Timed Buying emulator callable test'
  & node --check 'firebase/functions/integration/timed_buying_sandbox.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying sandbox callable test has a syntax error.' }

  $emulatorPorts = @(19099, 18080, 15001)
  $emulatorsReady = (@($emulatorPorts | Where-Object { Test-LocalPort $_ }).Count -eq $emulatorPorts.Count)
  if ($emulatorsReady) {
    Write-Step 'Running Timed Buying Auth + Functions + Firestore sandbox smoke test'
    $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
    $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
    $env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:15001'
    $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
    $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
    & node 'firebase/functions/integration/timed_buying_sandbox.mjs'
    if ($LASTEXITCODE -ne 0) { throw 'Timed Buying sandbox callable smoke test failed.' }
  }
  else {
    Write-Host 'Firebase emulators are not all running; callable smoke test skipped for this pass.' -ForegroundColor Yellow
    Write-Host 'The full acceptance launcher will run it before opening Flutter.' -ForegroundColor DarkGray
  }

  Write-Step 'Timed Buying migration verification passed'
  git diff --stat
  git status --short

  if ($CommitAndPush) {
    Write-Step 'Committing verified Timed Buying source changes'
    git add -- $targets
    git diff --cached --quiet
    $hasStagedChanges = $LASTEXITCODE -ne 0
    if ($hasStagedChanges) {
      git commit -m 'Rebrand auction UI as Timed Buying'
      if ($LASTEXITCODE -ne 0) { throw 'Git commit failed.' }
      git push origin design/formal-beautification-foundation
      if ($LASTEXITCODE -ne 0) { throw 'Git push failed.' }
      Write-Host 'Verified Timed Buying source changes pushed.' -ForegroundColor Green
    }
    else {
      Write-Host 'No uncommitted Timed Buying source changes remained to commit.' -ForegroundColor Green
    }
  }
  else {
    Write-Host ''
    Write-Host 'Changes are verified locally but not committed by this helper.' -ForegroundColor Green
    Write-Host 'Re-run with -CommitAndPush after reviewing the app if you want the helper to push them.' -ForegroundColor DarkGray
  }
}
catch {
  Write-Host "`nTimed Buying migration failed; restoring only the files this helper may format or edit." -ForegroundColor Red
  & git restore -- $restoreTargets
  throw
}
