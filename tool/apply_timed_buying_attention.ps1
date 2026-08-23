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
$presentation = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_presentation.dart'
$engagementTest = Join-Path $repoRoot 'test\marketplace_timed_buying_engagement_test.dart'
$presentationTest = Join-Path $repoRoot 'test\marketplace_timed_buying_presentation_test.dart'
$seed = Join-Path $repoRoot 'firebase\functions\scripts\seed_visual_sandbox.js'
$smoke = Join-Path $repoRoot 'firebase\functions\integration\timed_buying_sandbox.mjs'
$patcher = Join-Path $PSScriptRoot 'apply_timed_buying_attention_v2.mjs'
$compileFix = Join-Path $PSScriptRoot 'fix_timed_buying_engagement_compile_v1.mjs'

foreach ($required in @(
  $page,
  $engagement,
  $presentation,
  $engagementTest,
  $presentationTest,
  $seed,
  $patcher,
  $compileFix
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Timed Buying attention file is missing: $required. Pull the latest formal branch first."
  }
}

$pageSource = Get-Content -LiteralPath $page -Raw
if (-not $pageSource.Contains('Review & submit timed offer') -or
    -not $pageSource.Contains('TimedBuyingUrgencyFrame(')) {
  throw 'The verified local Timed Buying migration is not present. Apply it before this attention pass.'
}

Write-Step 'Current reviewed local work before Timed Buying attention pass'
git status --short

$backupRoot = Join-Path $env:TEMP "pipebuyer-timed-attention-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot | Out-Null
$backupPage = Join-Path $backupRoot 'marketplace_auctions_page.dart'
$backupEngagement = Join-Path $backupRoot 'marketplace_timed_buying_engagement.dart'
$backupSeed = Join-Path $backupRoot 'seed_visual_sandbox.js'
Copy-Item -LiteralPath $page -Destination $backupPage -Force
Copy-Item -LiteralPath $engagement -Destination $backupEngagement -Force
Copy-Item -LiteralPath $seed -Destination $backupSeed -Force
$completed = $false

try {
  Write-Step 'Syntax-checking Timed Buying attention migration'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying attention migration helper has a JavaScript syntax error.' }
  & node --check $compileFix
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying attention compile-fix helper has a JavaScript syntax error.' }

  Write-Step 'Correcting Timed Buying attention painter and applying engagement pass'
  & node $compileFix
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying attention painter correction failed.' }
  & node $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying attention migration failed.' }

  Write-Step 'Formatting Timed Buying attention sources'
  & dart format $page $engagement $engagementTest
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed for Timed Buying attention sources.' }

  Write-Step 'Analyzing Timed Buying board, detail and engagement visuals'
  & dart analyze $page $engagement $presentation $engagementTest $presentationTest
  if ($LASTEXITCODE -ne 0) { throw 'Dart analyzer failed for Timed Buying attention changes.' }

  Write-Step 'Running Timed Buying attention/participant widget contracts'
  & flutter test $engagementTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-timed-attention
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying engagement widget tests failed.' }

  Write-Step 'Re-running Timed Buying timing/action contracts'
  & flutter test $presentationTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-timed-attention
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying presentation regression tests failed.' }

  Write-Step 'Syntax-checking updated local visual fixture'
  & node --check $seed
  if ($LASTEXITCODE -ne 0) { throw 'Updated Timed Buying visual sandbox seed has a syntax error.' }

  $emulatorPorts = @(19099, 18080, 15001)
  $emulatorsReady = (@($emulatorPorts | Where-Object { Test-LocalPort $_ }).Count -eq $emulatorPorts.Count)
  if ($emulatorsReady -and (Test-Path -LiteralPath $smoke)) {
    Write-Step 'Re-running Timed Buying Auth + Functions + Firestore smoke test'
    $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
    $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
    $env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:15001'
    $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
    $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
    & node $smoke
    if ($LASTEXITCODE -ne 0) {
      throw 'Timed Buying sandbox callable smoke test failed after attention changes.'
    }
  }
  else {
    Write-Host 'Firebase emulators are not all running; callable smoke test skipped.' -ForegroundColor Yellow
  }

  & git restore -- $generatedFlutterFiles 2>$null

  Write-Step 'Timed Buying attention verification passed'
  git diff --stat
  git status --short
  Write-Host ''
  Write-Host 'Next: reseed the local sandbox, then hot-reload/reopen http://127.0.0.1:5050.' -ForegroundColor Green
  Write-Host 'Expect a moving Final Day border at ~5 hours, stronger Final Hour treatment under 60 minutes, and viewer-position highlights.' -ForegroundColor Green
  Write-Host 'The reviewed source remains uncommitted until visual acceptance.' -ForegroundColor DarkGray
  $completed = $true
}
finally {
  if (-not $completed) {
    Write-Host "`nTimed Buying attention verification failed; restoring only files edited by this pass." -ForegroundColor Red
    if (Test-Path -LiteralPath $backupPage) {
      Copy-Item -LiteralPath $backupPage -Destination $page -Force
    }
    if (Test-Path -LiteralPath $backupEngagement) {
      Copy-Item -LiteralPath $backupEngagement -Destination $engagement -Force
    }
    if (Test-Path -LiteralPath $backupSeed) {
      Copy-Item -LiteralPath $backupSeed -Destination $seed -Force
    }
  }
  Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  & git restore -- $generatedFlutterFiles 2>$null
}
