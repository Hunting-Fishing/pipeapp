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

# Flutter test/pub tooling rewrites these generated files on Windows. They are
# not product work and can be restored without touching the verified Timed
# Buying source modifications currently under review.
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

$pageSource = Get-Content -LiteralPath $page -Raw
if (-not $pageSource.Contains('Review & submit timed offer') -or
    -not $pageSource.Contains('Timed Buying')) {
  throw 'The verified local Timed Buying migration is not present. Do not apply the compact-detail pass yet.'
}

Write-Step 'Current reviewed Timed Buying changes before compact-detail pass'
git status --short

$backup = Join-Path $env:TEMP "pipebuyer-auction-detail-$([guid]::NewGuid().ToString('N')).dart"
Copy-Item -LiteralPath $page -Destination $backup -Force
$completed = $false

try {
  Write-Step 'Syntax-checking compact-detail migration'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Compact-detail migration helper has a JavaScript syntax error.' }

  Write-Step 'Applying denser professional asset-detail layout'
  & node $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Compact Timed Buying detail migration failed.' }

  Write-Step 'Formatting the locally modified Timed Buying detail page'
  & dart format $page
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed for the Timed Buying detail page.' }

  Write-Step 'Checking committed compact-spec component formatting'
  & dart format --output=none --set-exit-if-changed $specs $specTest
  if ($LASTEXITCODE -ne 0) {
    throw 'The compact listing-spec component/test needs formatting. Send this output before proceeding.'
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
  Write-Host 'The Timed Buying source changes remain uncommitted until visual acceptance.' -ForegroundColor DarkGray
  $completed = $true
}
finally {
  if (-not $completed -and (Test-Path -LiteralPath $backup)) {
    Write-Host "`nCompact-detail verification failed; restoring the Timed Buying page to exactly the pre-run local version." -ForegroundColor Red
    Copy-Item -LiteralPath $backup -Destination $page -Force
  }
  Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
  & git restore -- $generatedFlutterFiles 2>$null
}
