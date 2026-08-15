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

$allowedFiles = @(
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
foreach ($file in $allowedFiles) { [void]$allowed.Add($file) }
$unexpected = @()
foreach ($line in @(git status --porcelain)) {
  if ($line.Length -lt 4) { continue }
  $file = $line.Substring(3).Trim().Replace('\', '/')
  if (-not $allowed.Contains($file)) { $unexpected += $line }
}
if ($unexpected.Count -gt 0) {
  Write-Host 'Unexpected local changes were found:' -ForegroundColor Red
  $unexpected | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw 'Only the existing release-repair files may be dirty before running V5.'
}

$backupRoot = "${workspace}_release_fix_v5_backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force $backupRoot | Out-Null
Copy-Item 'test/marketplace_grid_density_test.dart' (Join-Path $backupRoot 'marketplace_grid_density_test.dart')
Write-Host "Backups: $backupRoot" -ForegroundColor DarkGray

Write-Host '==> Applying robust grid-density repair' -ForegroundColor Cyan
node .\tool\fix_release_failures_v5.mjs
Assert-NativeSuccess 'Grid-density V5 patcher'

dart format test/marketplace_grid_density_test.dart
Assert-NativeSuccess 'Grid-density test formatting'

git diff --check
Assert-NativeSuccess 'Git whitespace validation'

$releaseSha = (git rev-parse HEAD).Trim()
$defines = @(
  '--dart-define=PIPE_ENV=local-verification',
  "--dart-define=PIPE_RELEASE_SHA=$releaseSha"
)

Write-Host '==> Running the remaining grid-density test first' -ForegroundColor Cyan
flutter test test/marketplace_grid_density_test.dart --reporter expanded --concurrency=1 @defines
Assert-NativeSuccess 'Grid-density focused test'

Write-Host '==> Grid-density test passed; handing off to full V3 validation/commit flow' -ForegroundColor Green
powershell -ExecutionPolicy Bypass -File .\tool\fix_release_failures_v3.ps1
Assert-NativeSuccess 'V3 full release validation'
