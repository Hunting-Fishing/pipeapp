$ErrorActionPreference = 'Stop'

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Operation,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  Write-Host "==> $Operation" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

$branch = (git branch --show-current).Trim()
if ($branch -ne 'listing-lifecycle-nav-v1') {
  throw "Run this only from listing-lifecycle-nav-v1. Current branch: $branch"
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

# These are the only source files this controlled batch is allowed to modify.
$batchTargets = @(
  'firebase/firestore.indexes.json',
  'firebase/functions/index.js',
  'firebase/functions/marketplace_commands.js',
  'lib/marketplace/marketplace_account_hub.dart',
  'lib/marketplace/marketplace_adaptive_shell.dart',
  'lib/marketplace/marketplace_account_menu.dart',
  'lib/marketplace/marketplace_grouped_navigation.dart',
  'lib/marketplace/marketplace_home_welcome.dart',
  'lib/marketplace/marketplace_listing_insights.dart',
  'lib/marketplace/marketplace_listing_lifecycle.dart',
  'lib/marketplace/marketplace_listing_status.dart',
  'lib/marketplace/oil_gas_marketplace.dart',
  'test/marketplace_listing_lifecycle_test.dart'
)

function Get-DirtyPaths {
  return @(git status --porcelain | ForEach-Object {
    if ($_.Length -gt 3) { $_.Substring(3).Trim() }
  } | Where-Object { $_ })
}

Write-Host '==> Cleaning only Flutter-generated plugin churn' -ForegroundColor Cyan
foreach ($generated in $generatedFiles) {
  git restore -- $generated 2>$null
}

$dirtyPaths = Get-DirtyPaths
$unrelated = @($dirtyPaths | Where-Object { $_ -notin $batchTargets })
if ($unrelated.Count -gt 0) {
  Write-Host 'Unrelated local changes detected:' -ForegroundColor Red
  $unrelated | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  throw 'Commit/stash unrelated changes before applying the listing lifecycle batch.'
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path (Split-Path $workspace -Parent) "pipeapp_listing_lifecycle_v2_backup_$timestamp"
New-Item -ItemType Directory -Force $backup | Out-Null

if ($dirtyPaths.Count -gt 0) {
  Write-Host '==> Preserving partial lifecycle changes before clean reapply' -ForegroundColor Cyan
  foreach ($target in $dirtyPaths) {
    $source = Join-Path $workspace $target
    if (Test-Path $source) {
      $destination = Join-Path $backup $target
      New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
      Copy-Item $source $destination -Force
    }
  }
  Write-Host "Partial-change backup: $backup" -ForegroundColor DarkGray

  # Restore ONLY the known lifecycle/nav target files. This does not touch any
  # unrelated working files, and the backup above preserves the interrupted run.
  foreach ($target in $dirtyPaths) {
    $tracked = @(git ls-files -- $target)
    if ($tracked.Count -gt 0) {
      git restore --source=HEAD --staged --worktree -- $target
      if ($LASTEXITCODE -ne 0) {
        throw "Could not restore lifecycle target $target to the branch baseline."
      }
    } elseif (Test-Path (Join-Path $workspace $target)) {
      Remove-Item (Join-Path $workspace $target) -Force
    }
  }
} else {
  Write-Host "Backup directory reserved: $backup" -ForegroundColor DarkGray
}

$remainingDirty = Get-DirtyPaths
if ($remainingDirty.Count -gt 0) {
  Write-Host 'Working tree is still dirty after controlled reset:' -ForegroundColor Red
  $remainingDirty | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  throw 'Controlled lifecycle reset did not produce a clean working tree.'
}

try {
  Invoke-Checked 'Applying 30-day lifecycle, Home, account menu, and navigation wiring' {
    node .\tool\apply_listing_lifecycle_nav_v1.mjs
  }

  Invoke-Checked 'Hardening listing publication and expiry presentation' {
    node .\tool\apply_listing_lifecycle_nav_v1_extra.mjs
  }

  Invoke-Checked 'Formatting changed Dart files' {
    dart format `
      lib/marketplace/marketplace_adaptive_shell.dart `
      lib/marketplace/oil_gas_marketplace.dart `
      lib/marketplace/marketplace_account_hub.dart `
      lib/marketplace/marketplace_listing_lifecycle.dart `
      lib/marketplace/marketplace_listing_insights.dart `
      lib/marketplace/marketplace_listing_status.dart `
      lib/marketplace/marketplace_home_welcome.dart `
      lib/marketplace/marketplace_account_menu.dart `
      lib/marketplace/marketplace_grouped_navigation.dart `
      test/marketplace_listing_lifecycle_test.dart
  }

  Push-Location .\firebase\functions
  try {
    Invoke-Checked 'Checking new Functions modules' {
      node --check marketplace_listing_lifecycle.js
      if ($LASTEXITCODE -ne 0) { throw 'marketplace_listing_lifecycle.js syntax failed.' }
      node --check marketplace_listing_insights.js
      if ($LASTEXITCODE -ne 0) { throw 'marketplace_listing_insights.js syntax failed.' }
      node --check marketplace_commands.js
      if ($LASTEXITCODE -ne 0) { throw 'marketplace_commands.js syntax failed.' }
      node --check index.js
    }
    Invoke-Checked 'Running focused listing lifecycle Functions tests' {
      node --test `
        test/marketplace_listing_lifecycle.test.js `
        test/marketplace_listing_insights.test.js
    }
    Invoke-Checked 'Running complete Functions tests' { npm test }
    Invoke-Checked 'Running Functions lint' { npm run lint }
  }
  finally {
    Pop-Location
  }

  Invoke-Checked 'Analyzing Flutter application and tests' {
    dart analyze lib test
  }

  Invoke-Checked 'Running focused Flutter lifecycle and shell tests' {
    flutter test `
      test/marketplace_listing_lifecycle_test.dart `
      test/marketplace_adaptive_shell_test.dart `
      test/marketplace_listing_status_test.dart `
      --reporter expanded
  }

  Invoke-Checked 'Running complete Flutter test suite' {
    flutter test --reporter compact
  }

  Invoke-Checked 'Checking patch whitespace' { git diff --check }

  foreach ($generated in $generatedFiles) {
    git restore -- $generated 2>$null
  }

  $changed = Get-DirtyPaths
  $unexpected = @($changed | Where-Object { $_ -notin $batchTargets })
  if ($unexpected.Count -gt 0) {
    Write-Host 'Unexpected files changed:' -ForegroundColor Red
    $unexpected | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw 'Validation passed but the working tree contains unexpected changes.'
  }

  if ($changed.Count -eq 0) {
    Write-Host 'Lifecycle/navigation wiring is already applied and validated.' -ForegroundColor Green
    exit 0
  }

  git add -- $batchTargets
  if ($LASTEXITCODE -ne 0) {
    throw 'Validated lifecycle files could not be staged.'
  }
  git commit -m 'Wire 30-day listing lifecycle and grouped marketplace navigation'
  if ($LASTEXITCODE -ne 0) {
    throw 'Validated changes could not be committed.'
  }
  git push origin listing-lifecycle-nav-v1
  if ($LASTEXITCODE -ne 0) {
    throw 'Validated commit could not be pushed.'
  }

  Write-Host ''
  Write-Host 'Listing lifecycle/navigation batch validated and pushed.' -ForegroundColor Green
  Write-Host 'The branch is ready for browser/emulator review before merging to main.' -ForegroundColor Green
}
catch {
  Write-Host ''
  Write-Host "Batch stopped. Backup remains at: $backup" -ForegroundColor Yellow
  throw
}
