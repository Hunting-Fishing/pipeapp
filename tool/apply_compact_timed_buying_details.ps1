$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

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

# Flutter test/pub tooling rewrites these generated files on Windows. These are
# the only files this helper may git-restore automatically. Product source and
# professional listing/test files are never restored from HEAD by this runner.
& git restore -- $generatedFlutterFiles 2>$null

$page = Join-Path $repoRoot 'lib\marketplace\marketplace_auctions_page.dart'
$specs = Join-Path $repoRoot 'lib\marketplace\marketplace_listing_specs.dart'
$specTest = Join-Path $repoRoot 'test\marketplace_listing_specs_compact_test.dart'
$timedBuyingTest = Join-Path $repoRoot 'test\marketplace_timed_buying_presentation_test.dart'
$patcher = Join-Path $PSScriptRoot 'apply_compact_timed_buying_details_v1.mjs'

foreach ($required in @($page, $specs, $specTest, $timedBuyingTest, $patcher)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required compact-detail file is missing: $required. Pull the latest formal branch first."
  }
}

Write-Step 'Verifying professional Asset Overview source without replacing local work'
$specsSource = Get-Content -LiteralPath $specs -Raw
if (-not $specsSource.Contains('class _ListingSpecsDisclosure extends StatefulWidget')) {
  throw 'Professional Asset Overview disclosure is missing. Pull the latest formal branch and stop here.'
}
if ($specsSource.Contains('ExpansionTile(') -or $specsSource.Contains('AnimatedCrossFade(')) {
  throw 'Professional Asset Overview is on an older disclosure implementation. Pull the latest branch; expected InkWell + AnimatedSize.'
}
if (-not $specsSource.Contains('AnimatedSize(')) {
  throw 'Professional Asset Overview AnimatedSize disclosure is missing. Refusing to replace product source automatically.'
}
Write-Host 'Professional Asset Overview verified: local source preserved; InkWell + AnimatedSize disclosure active.' -ForegroundColor Green

$pageSource = Get-Content -LiteralPath $page -Raw
if (-not $pageSource.Contains('Review & submit timed offer') -or
    -not $pageSource.Contains('Timed Buying')) {
  throw 'The verified local Timed Buying migration is not present. Do not apply the compact-detail pass yet.'
}

Write-Step 'Current reviewed Timed Buying changes before compact-detail pass'
git status --short

# Back up every source file this helper can format/edit. On failure we restore
# these exact pre-run bytes from TEMP, never from git HEAD, so professional work
# cannot be silently removed by a verification failure.
$backupRoot = Join-Path $env:TEMP "pipebuyer-compact-details-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$backups = @{
  $page = Join-Path $backupRoot 'marketplace_auctions_page.dart'
  $specs = Join-Path $backupRoot 'marketplace_listing_specs.dart'
  $specTest = Join-Path $backupRoot 'marketplace_listing_specs_compact_test.dart'
}
foreach ($entry in $backups.GetEnumerator()) {
  Copy-Item -LiteralPath $entry.Key -Destination $entry.Value -Force
}
$completed = $false

try {
  Write-Step 'Syntax-checking compact-detail migration'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Compact-detail migration helper has a JavaScript syntax error.' }

  Write-Step 'Applying denser professional asset-detail layout'
  & node $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Compact Timed Buying detail migration failed.' }

  Write-Step 'Formatting compact detail sources'
  & dart format $page $specs $specTest
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed for compact Timed Buying detail sources.' }

  $specsSource = Get-Content -LiteralPath $specs -Raw
  if ($specsSource.Contains('ExpansionTile(') -or $specsSource.Contains('AnimatedCrossFade(')) {
    throw 'An obsolete listing-spec disclosure reappeared before widget tests.'
  }

  Write-Step 'Analyzing compact Timed Buying detail surface'
  & dart analyze $page $specs $specTest $timedBuyingTest
  if ($LASTEXITCODE -ne 0) { throw 'Dart analyzer failed for compact Timed Buying details.' }

  Write-Step 'Running compact industrial listing-detail contracts'
  & flutter test $specTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-compact-details
  if ($LASTEXITCODE -ne 0) { throw 'Compact listing-detail widget tests failed.' }

  Write-Step 'Re-running Timed Buying urgency/action widget contracts'
  & flutter test $timedBuyingTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=local-compact-details
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying widget regression test failed.' }

  & git restore -- $generatedFlutterFiles 2>$null

  Write-Step 'Compact Timed Buying detail verification passed'
  git diff --stat
  git status --short
  Write-Host ''
  Write-Host 'Visual review next: refresh http://127.0.0.1:5050 and inspect the Timed Buying detail page.' -ForegroundColor Green
  Write-Host 'Professional Asset Overview and Timed Buying source changes remain in your working tree for review.' -ForegroundColor DarkGray
  $completed = $true
}
finally {
  if (-not $completed) {
    Write-Host "`nCompact-detail verification failed; restoring only exact pre-run TEMP backups (never git HEAD)." -ForegroundColor Red
    foreach ($entry in $backups.GetEnumerator()) {
      if (Test-Path -LiteralPath $entry.Value) {
        Copy-Item -LiteralPath $entry.Value -Destination $entry.Key -Force
      }
    }
  }
  Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  & git restore -- $generatedFlutterFiles 2>$null
}
