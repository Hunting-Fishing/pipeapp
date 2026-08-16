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

$page = Join-Path $repoRoot 'lib\marketplace\oil_gas_marketplace.dart'
$presentation = Join-Path $repoRoot 'lib\marketplace\marketplace_listing_form_presentation.dart'
$presentationTest = Join-Path $repoRoot 'test\marketplace_listing_form_presentation_test.dart'
$specs = Join-Path $repoRoot 'lib\marketplace\marketplace_listing_specs.dart'
$specsTest = Join-Path $repoRoot 'test\marketplace_listing_specs_compact_test.dart'
$timedBuyingTest = Join-Path $repoRoot 'test\marketplace_timed_buying_presentation_test.dart'
$backendTest = Join-Path $repoRoot 'firebase\functions\test\marketplace_listing_form_contract.test.js'
$timedBuyingSmoke = Join-Path $repoRoot 'firebase\functions\integration\timed_buying_sandbox.mjs'
$patcher = Join-Path $PSScriptRoot 'apply_professional_listing_form_v1.mjs'

foreach ($required in @(
  $page,
  $presentation,
  $presentationTest,
  $specs,
  $specsTest,
  $timedBuyingTest,
  $backendTest,
  $patcher
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required professional listing-form file is missing: $required. Pull the latest formal branch first."
  }
}

Write-Step 'Current local marketplace work before listing-form pass'
git status --short

$backup = Join-Path $env:TEMP "pipebuyer-listing-form-$([guid]::NewGuid().ToString('N')).dart"
Copy-Item -LiteralPath $page -Destination $backup -Force
$completed = $false

try {
  Write-Step 'Syntax-checking professional listing-form migration'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) {
    throw 'Professional listing-form migration helper has a JavaScript syntax error.'
  }

  Write-Step 'Applying professional category-aware listing form + Timed Buying terms'
  & node $patcher
  if ($LASTEXITCODE -ne 0) {
    throw 'Professional listing-form migration failed.'
  }

  Write-Step 'Formatting listing-form sources'
  & dart format $page $presentation $presentationTest
  if ($LASTEXITCODE -ne 0) {
    throw 'dart format failed for professional listing-form sources.'
  }

  Write-Step 'Analyzing listing form, compact asset overview and Timed Buying presentation'
  & dart analyze `
    $page `
    $presentation `
    $presentationTest `
    $specs `
    $specsTest `
    'lib/marketplace/marketplace_timed_buying_presentation.dart' `
    $timedBuyingTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Dart analyzer failed for the professional listing-form pass.'
  }

  Write-Step 'Running professional listing-form widget contracts'
  & flutter test $presentationTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-listing-form
  if ($LASTEXITCODE -ne 0) {
    throw 'Professional listing-form widget tests failed.'
  }

  Write-Step 'Running compact public asset-detail contracts'
  & flutter test $specsTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-listing-form
  if ($LASTEXITCODE -ne 0) {
    throw 'Compact listing-detail regression tests failed.'
  }

  Write-Step 'Re-running Timed Buying presentation contracts'
  & flutter test $timedBuyingTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-listing-form
  if ($LASTEXITCODE -ne 0) {
    throw 'Timed Buying presentation regression tests failed.'
  }

  Write-Step 'Testing backend compatibility for structured Marketplace + Timed Buying listings'
  & node --test $backendTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Marketplace listing-form backend contract test failed.'
  }

  $emulatorPorts = @(19099, 18080, 15001)
  $emulatorsReady = (@($emulatorPorts | Where-Object { Test-LocalPort $_ }).Count -eq $emulatorPorts.Count)
  if ($emulatorsReady -and (Test-Path -LiteralPath $timedBuyingSmoke)) {
    Write-Step 'Re-running real Timed Buying Auth + Functions + Firestore smoke test'
    $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
    $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
    $env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:15001'
    $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
    $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
    & node $timedBuyingSmoke
    if ($LASTEXITCODE -ne 0) {
      throw 'Timed Buying sandbox callable smoke test failed after listing-form changes.'
    }
  }
  else {
    Write-Host 'Firebase emulators are not all running; real Timed Buying callable smoke test skipped.' -ForegroundColor Yellow
  }

  & git restore -- $generatedFlutterFiles 2>$null

  Write-Step 'Professional listing-form verification passed'
  git diff --stat
  git status --short
  Write-Host ''
  Write-Host 'Visual review next: hot-reload or reopen http://127.0.0.1:5050 and open Create Listing.' -ForegroundColor Green
  Write-Host 'Test Marketplace, Timed Buying and Wanted placements before committing local source changes.' -ForegroundColor DarkGray
  $completed = $true
}
finally {
  if (-not $completed -and (Test-Path -LiteralPath $backup)) {
    Write-Host "`nProfessional listing-form verification failed; restoring oil_gas_marketplace.dart to the exact pre-run local version." -ForegroundColor Red
    Copy-Item -LiteralPath $backup -Destination $page -Force
  }
  Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
  & git restore -- $generatedFlutterFiles 2>$null
}
