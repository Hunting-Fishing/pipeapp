$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess([string]$Operation) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

if ((git branch --show-current).Trim() -ne 'main') {
  throw 'Run this final release repair only from the main branch.'
}

$generatedFiles = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugin_registrant.h',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugin_registrant.h',
  'windows/flutter/generated_plugins.cmake'
)

$targets = @(
  'lib/marketplace/marketplace_auth_page.dart',
  'lib/marketplace/marketplace_offer_schedule.dart',
  'lib/marketplace/marketplace_tax_profile_page.dart',
  'lib/marketplace/marketplace_vip_access.dart',
  'lib/marketplace/regional_phone_field.dart',
  'test/marketplace_dispatch_onboarding_test.dart',
  'test/marketplace_grid_density_test.dart',
  'test/marketplace_offer_schedule_test.dart',
  'test/pipe_accessibility_acceptance_test.dart'
)

Write-Host '==> Cleaning only Flutter-generated plugin churn' -ForegroundColor Cyan
foreach ($file in $generatedFiles) {
  git restore -- $file 2>$null
}

$allowed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in $targets) { [void]$allowed.Add($file) }
$unexpected = @()
foreach ($line in @(git status --porcelain)) {
  if ($line.Length -lt 4) { continue }
  $file = $line.Substring(3).Trim().Replace('\', '/')
  if (-not $allowed.Contains($file)) { $unexpected += $line }
}
if ($unexpected.Count -gt 0) {
  Write-Host 'Unexpected local changes were found:' -ForegroundColor Red
  $unexpected | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw 'Only the existing validated release-repair files may be dirty before running V4.'
}

$backupRoot = "${workspace}_release_fix_v4_backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force $backupRoot | Out-Null
foreach ($file in $targets) {
  if (Test-Path $file) {
    $dest = Join-Path $backupRoot $file
    New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
    Copy-Item $file $dest
  }
}
Write-Host "Backups: $backupRoot" -ForegroundColor DarkGray

Write-Host '==> Applying stable grid-density semantic selection repair' -ForegroundColor Cyan
node .\tool\fix_release_failures_v4.mjs
Assert-NativeSuccess 'Grid density release test patcher'

dart format test/marketplace_grid_density_test.dart
Assert-NativeSuccess 'Dart formatting'

git diff --check
Assert-NativeSuccess 'Git whitespace validation'

dart analyze lib test
Assert-NativeSuccess 'Dart analysis'

$releaseSha = (git rev-parse HEAD).Trim()
$defines = @(
  '--dart-define=PIPE_ENV=local-verification',
  "--dart-define=PIPE_RELEASE_SHA=$releaseSha"
)

Write-Host '==> Running grid-density test first' -ForegroundColor Cyan
flutter test test/marketplace_grid_density_test.dart --reporter expanded @defines
Assert-NativeSuccess 'Grid density test'

$focusedTests = @(
  'test/marketplace_dispatch_onboarding_test.dart',
  'test/marketplace_grid_density_test.dart',
  'test/marketplace_listing_media_test.dart',
  'test/marketplace_offer_schedule_test.dart',
  'test/marketplace_tax_compliance_contract_test.dart',
  'test/pipe_accessibility_acceptance_test.dart'
)
Write-Host '==> Running repaired release test groups' -ForegroundColor Cyan
flutter test @focusedTests --reporter expanded --concurrency=1 @defines
Assert-NativeSuccess 'Focused release tests'

Write-Host '==> Running complete Flutter suite' -ForegroundColor Cyan
flutter test --concurrency=1 @defines
Assert-NativeSuccess 'Complete Flutter tests'

Write-Host '==> Removing generated plugin churn after tests' -ForegroundColor Cyan
foreach ($file in $generatedFiles) {
  git restore -- $file 2>$null
}

$unexpected = @()
foreach ($line in @(git status --porcelain)) {
  if ($line.Length -lt 4) { continue }
  $file = $line.Substring(3).Trim().Replace('\', '/')
  if (-not $allowed.Contains($file)) { $unexpected += $line }
}
if ($unexpected.Count -gt 0) {
  Write-Host 'Unexpected files changed during validation:' -ForegroundColor Red
  $unexpected | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw 'Unexpected working-tree changes detected. Nothing was committed.'
}

Write-Host '==> Staging validated V2 + V3 + V4 repairs' -ForegroundColor Cyan
git add -- @targets
$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) {
  Write-Host 'No release-repair changes remain to commit.' -ForegroundColor Green
  exit 0
}
$staged | ForEach-Object { Write-Host $_ }

git commit -m 'Fix release accessibility and test blockers'
Assert-NativeSuccess 'Release repair commit'

git push origin main
Assert-NativeSuccess 'Release repair push'

Write-Host ''
Write-Host 'All Flutter release tests passed and repairs were pushed to main.' -ForegroundColor Green
Write-Host 'Next: run tool\verify.ps1 for the complete Firebase release gate.' -ForegroundColor Green
