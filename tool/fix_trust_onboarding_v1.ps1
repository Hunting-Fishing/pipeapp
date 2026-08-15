$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess([string]$Operation) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

if ((git branch --show-current).Trim() -ne 'main') {
  throw 'Run the trust onboarding repair from the main branch.'
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

Write-Host '==> Cleaning Flutter-generated plugin churn' -ForegroundColor Cyan
foreach ($file in $generatedFiles) {
  git restore -- $file 2>$null
}

$dirty = @(git status --porcelain)
if ($dirty.Count -gt 0) {
  Write-Host 'Working tree contains local changes:' -ForegroundColor Red
  $dirty | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw 'Commit/stash unrelated source changes before running this repair.'
}

$existingTargets = @(
  'lib/marketplace/marketplace_account_security_page.dart',
  'lib/marketplace/marketplace_auth_page.dart',
  'lib/marketplace/marketplace_command_client.dart'
)
$newTargets = @(
  'lib/marketplace/marketplace_trust_readiness.dart',
  'test/marketplace_trust_readiness_test.dart'
)
$targets = @($existingTargets + $newTargets)

$backupRoot = "${workspace}_trust_onboarding_backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force $backupRoot | Out-Null
foreach ($file in $existingTargets) {
  $dest = Join-Path $backupRoot $file
  New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
  Copy-Item $file $dest
}
Write-Host "Backups: $backupRoot" -ForegroundColor DarkGray

Write-Host '==> Applying Trust Readiness / onboarding UX repair' -ForegroundColor Cyan
node .\tool\fix_trust_onboarding_v1.mjs
Assert-NativeSuccess 'Trust onboarding patcher'

Write-Host '==> Formatting Dart changes' -ForegroundColor Cyan
dart format @targets
Assert-NativeSuccess 'Dart formatting'

git diff --check
Assert-NativeSuccess 'Git whitespace validation'

Write-Host '==> Analyzing application and tests' -ForegroundColor Cyan
dart analyze lib test
Assert-NativeSuccess 'Dart analysis'

$releaseSha = (git rev-parse HEAD).Trim()
$defines = @(
  '--dart-define=PIPE_ENV=local-verification',
  "--dart-define=PIPE_RELEASE_SHA=$releaseSha"
)

Write-Host '==> Running trust/accessibility regression tests' -ForegroundColor Cyan
flutter test `
  test/marketplace_trust_readiness_test.dart `
  test/pipe_accessibility_acceptance_test.dart `
  --reporter expanded `
  --concurrency=1 `
  @defines
Assert-NativeSuccess 'Trust/accessibility regression tests'

Write-Host '==> Running complete Flutter suite' -ForegroundColor Cyan
flutter test --concurrency=1 @defines
Assert-NativeSuccess 'Complete Flutter tests'

Write-Host '==> Removing generated plugin churn after tests' -ForegroundColor Cyan
foreach ($file in $generatedFiles) {
  git restore -- $file 2>$null
}

$allowed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in $targets) { [void]$allowed.Add($file) }
$unexpected = @()
foreach ($line in @(git status --porcelain)) {
  if ($line.Length -lt 4) { continue }
  $file = $line.Substring(3).Trim().Replace('\\', '/')
  if (-not $allowed.Contains($file)) { $unexpected += $line }
}
if ($unexpected.Count -gt 0) {
  Write-Host 'Unexpected files changed during validation:' -ForegroundColor Red
  $unexpected | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw 'Unexpected working-tree changes detected. Nothing was committed.'
}

Write-Host '==> Staging validated trust/onboarding changes' -ForegroundColor Cyan
git add -- @targets
$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) {
  Write-Host 'No trust/onboarding changes remain to commit.' -ForegroundColor Green
  exit 0
}
$staged | ForEach-Object { Write-Host $_ }

git commit -m 'Clarify trust readiness and verified onboarding access'
Assert-NativeSuccess 'Trust onboarding commit'

git push origin main
Assert-NativeSuccess 'Trust onboarding push'

Write-Host ''
Write-Host 'Trust Readiness and onboarding changes validated and pushed to main.' -ForegroundColor Green
Write-Host 'Run tool\verify.ps1 before the next production Hosting deployment.' -ForegroundColor Green
