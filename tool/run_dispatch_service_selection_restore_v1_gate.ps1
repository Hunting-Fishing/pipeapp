# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Copy-RelativeFile([string]$Root, [string]$RelativePath, [string]$DestinationRoot) {
  $source = Join-Path $Root $RelativePath
  $destination = Join-Path $DestinationRoot $RelativePath
  $destinationParent = Split-Path -Parent $destination
  New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Restore-RelativeFiles([string]$Root, [string]$BackupRoot, [string[]]$RelativePaths) {
  foreach ($relative in $RelativePaths) {
    $source = Join-Path $BackupRoot $relative
    $destination = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $source)) {
      throw "STOP: Rollback backup is missing: $source"
    }
    Copy-Item -LiteralPath $source -Destination $destination -Force
  }
}

function Copy-AssetDirectoryShape([string]$SourceRoot, [string]$DestinationRoot) {
  $sourceAssets = Join-Path $SourceRoot 'assets'
  if (-not (Test-Path -LiteralPath $sourceAssets)) {
    throw 'STOP: The production assets directory is missing.'
  }
  $destinationAssets = Join-Path $DestinationRoot 'assets'
  New-Item -ItemType Directory -Force -Path $destinationAssets | Out-Null
  Get-ChildItem -LiteralPath $sourceAssets -Directory -Recurse | ForEach-Object {
    $relative = $_.FullName.Substring($sourceAssets.Length).TrimStart('\')
    if ($relative) {
      New-Item -ItemType Directory -Force -Path (Join-Path $destinationAssets $relative) | Out-Null
    }
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$branch = (git branch --show-current).Trim()
if ($branch -ne $expectedBranch) {
  throw "STOP: Wrong branch. Expected $expectedBranch, found $branch"
}

$trackerRelative = 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$trackerPath = Join-Path $repoRoot $trackerRelative
if (-not (Test-Path -LiteralPath $trackerPath)) {
  throw 'STOP: Dispatch master plan is missing.'
}
$trackerHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash

$existingProductionFiles = @(
  'lib\marketplace\marketplace_dispatch_page.dart',
  'lib\marketplace\marketplace_dispatch_directory.dart',
  'lib\marketplace\marketplace_dispatch_directory_actions.dart'
)
$selectorRelative = 'lib\marketplace\marketplace_dispatch_multi_service_selector.dart'
foreach ($relative in $existingProductionFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) {
    throw "STOP: Required production source is missing: $relative"
  }
}
$productionHashesBefore = @{}
foreach ($relative in $existingProductionFiles) {
  $productionHashesBefore[$relative] =
      (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
}
$selectorExistedBefore = Test-Path -LiteralPath (Join-Path $repoRoot $selectorRelative)
$selectorHashBefore = $null
if ($selectorExistedBefore) {
  $selectorHashBefore =
      (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $selectorRelative)).Hash
}

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Synchronizing only the Request Service restoration support bundle'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the Request Service restoration support bundle.'
}
$supportFiles = @(
  'tool/templates/marketplace_dispatch_multi_service_selector_v1.dart',
  'tool/templates/marketplace_dispatch_directory_actions_v2.dart',
  'tool/dispatch_service_selection_restore_transform_v1.mjs',
  'test/dispatch_service_selection_restore_contract_test.dart',
  'docs/DISPATCH_REQUEST_SERVICE_RESTORE_AND_MULTI_QUOTE.md',
  'docs/repairs/DISPATCH_SERVICE_RESTORE_MIRROR_CONTRACT.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Request Service restoration support files.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the Request Service restoration support files.'
}

Write-Step 'Parsing restoration controls before production mutation'
& node --check '.\tool\dispatch_service_selection_restore_transform_v1.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Service-selection transform does not parse.'
}
$parseErrors = $null
$parseTokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$parseTokens,
  [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
  throw "STOP: Restoration gate PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Restoration control parse: PASS' -ForegroundColor Green

Write-Step 'Formatting support templates and contract only'
$supportDart = @(
  '.\tool\templates\marketplace_dispatch_multi_service_selector_v1.dart',
  '.\tool\templates\marketplace_dispatch_directory_actions_v2.dart',
  '.\test\dispatch_service_selection_restore_contract_test.dart'
)
& dart format $supportDart
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Restoration support Dart formatting failed.'
}
& dart format --output=none --set-exit-if-changed $supportDart
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Restoration support Dart is not formatter-stable.'
}

Write-Step 'Running exact-local structural dry-run before any source write'
& node '.\tool\dispatch_service_selection_restore_transform_v1.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Request Service restoration dry-run failed. Production source was not changed.'
}
foreach ($relative in $existingProductionFiles) {
  $currentHash =
      (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
  if ($currentHash -ne $productionHashesBefore[$relative]) {
    throw "STOP: Dry-run changed production source: $relative"
  }
}
if ($selectorExistedBefore) {
  $currentSelectorHash =
      (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $selectorRelative)).Hash
  if ($currentSelectorHash -ne $selectorHashBefore) {
    throw 'STOP: Dry-run changed the existing selector source.'
  }
} elseif (Test-Path -LiteralPath (Join-Path $repoRoot $selectorRelative)) {
  throw 'STOP: Dry-run created the production selector file.'
}
Write-Host 'Exact local dry-run production mutation: NO' -ForegroundColor Green

$mirrorRoot = $null
$backupRoot = $null
$mutationStarted = $false
try {
  Write-Step 'Building a canonical-filename mirror of the exact current local lib tree'
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $mirrorRoot = Join-Path $repoRoot "_local_preflight\dispatch-service-restore-v1-$stamp"
  New-Item -ItemType Directory -Force -Path $mirrorRoot | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Destination $mirrorRoot -Force
  if (Test-Path -LiteralPath (Join-Path $repoRoot 'pubspec.lock')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'pubspec.lock') -Destination $mirrorRoot -Force
  }
  if (Test-Path -LiteralPath (Join-Path $repoRoot 'analysis_options.yaml')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'analysis_options.yaml') -Destination $mirrorRoot -Force
  }
  Copy-Item -LiteralPath (Join-Path $repoRoot 'lib') -Destination $mirrorRoot -Recurse -Force
  Copy-AssetDirectoryShape -SourceRoot $repoRoot -DestinationRoot $mirrorRoot
  Write-Host 'Canonical mirror pubspec asset directory topology: PASS' -ForegroundColor Green
  New-Item -ItemType Directory -Force -Path (Join-Path $mirrorRoot '.dart_tool') | Out-Null
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.dart_tool\package_config.json'))) {
    throw 'STOP: .dart_tool/package_config.json is missing. Run flutter pub get first.'
  }
  Copy-Item -LiteralPath (Join-Path $repoRoot '.dart_tool\package_config.json') `
    -Destination (Join-Path $mirrorRoot '.dart_tool\package_config.json') -Force
  New-Item -ItemType Directory -Force -Path (Join-Path $mirrorRoot 'test') | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot 'test\dispatch_service_selection_restore_contract_test.dart') `
    -Destination (Join-Path $mirrorRoot 'test\dispatch_service_selection_restore_contract_test.dart') -Force

  Copy-Item -LiteralPath (Join-Path $repoRoot 'tool\templates\marketplace_dispatch_multi_service_selector_v1.dart') `
    -Destination (Join-Path $mirrorRoot $selectorRelative) -Force
  Copy-Item -LiteralPath (Join-Path $repoRoot 'tool\templates\marketplace_dispatch_directory_actions_v2.dart') `
    -Destination (Join-Path $mirrorRoot 'lib\marketplace\marketplace_dispatch_directory_actions.dart') -Force

  Write-Step 'Applying restoration only inside the canonical mirror'
  $oldRoot = $env:PIPEBUYER_ROOT
  $env:PIPEBUYER_ROOT = $mirrorRoot
  try {
    & node '.\tool\dispatch_service_selection_restore_transform_v1.mjs' --apply
    if ($LASTEXITCODE -ne 0) {
      throw 'STOP: Canonical-mirror Request Service restoration failed.'
    }
  }
  finally {
    $env:PIPEBUYER_ROOT = $oldRoot
  }

  foreach ($relative in $existingProductionFiles) {
    $currentHash =
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
    if ($currentHash -ne $productionHashesBefore[$relative]) {
      throw "STOP: Canonical mirror preparation changed production source: $relative"
    }
  }
  if (-not $selectorExistedBefore -and
      (Test-Path -LiteralPath (Join-Path $repoRoot $selectorRelative))) {
    throw 'STOP: Canonical mirror preparation created the production selector.'
  }
  Write-Host 'Canonical mirror production mutation: NO' -ForegroundColor Green

  Write-Step 'Formatting and strictly analyzing the complete restored candidate graph'
  Push-Location $mirrorRoot
  try {
    $mirrorDart = @(
      '.\lib\marketplace\marketplace_dispatch_multi_service_selector.dart',
      '.\lib\marketplace\marketplace_dispatch_directory_actions.dart',
      '.\lib\marketplace\marketplace_dispatch_directory.dart',
      '.\lib\marketplace\marketplace_dispatch_page.dart'
    )
    & dart format $mirrorDart
    if ($LASTEXITCODE -ne 0) {
      throw 'STOP: Canonical-mirror restoration formatting failed.'
    }
    & dart format --output=none --set-exit-if-changed $mirrorDart
    if ($LASTEXITCODE -ne 0) {
      throw 'STOP: Canonical-mirror restoration is not formatter-stable.'
    }
    foreach ($target in $mirrorDart) {
      & flutter analyze --fatal-infos --fatal-warnings $target
      if ($LASTEXITCODE -ne 0) {
        throw "STOP: Restored canonical-mirror candidate does not compile cleanly: $target"
      }
    }
    & flutter test '.\test\dispatch_service_selection_restore_contract_test.dart'
    if ($LASTEXITCODE -ne 0) {
      throw 'STOP: Restored canonical-mirror contract failed before production mutation.'
    }
  }
  finally {
    Pop-Location
  }
  Write-Host 'Canonical mirror selector/actions/directory/request-service analyzer: PASS' -ForegroundColor Green
  Write-Host 'Canonical mirror restoration contract: PASS' -ForegroundColor Green

  foreach ($relative in $existingProductionFiles) {
    $currentHash =
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
    if ($currentHash -ne $productionHashesBefore[$relative]) {
      throw "STOP: Candidate preflight modified production source: $relative"
    }
  }
  Write-Host 'Candidate production mutation: NO' -ForegroundColor Green

  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backupRoot = Join-Path $repoRoot "_local_backups\dispatch-service-restore-v1-$stamp"
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  foreach ($relative in $existingProductionFiles) {
    Copy-RelativeFile -Root $repoRoot -RelativePath $relative -DestinationRoot $backupRoot
  }
  if ($selectorExistedBefore) {
    Copy-RelativeFile -Root $repoRoot -RelativePath $selectorRelative -DestinationRoot $backupRoot
  }
  Write-Host "Gate rollback backup: $backupRoot" -ForegroundColor DarkGray

  Write-Step 'Promoting only the mirror-proven Request Service and Directory changes'
  $mutationStarted = $true
  & node '.\tool\dispatch_service_selection_restore_transform_v1.mjs' --apply
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Production Request Service restoration transform failed.'
  }
  Copy-Item -LiteralPath (Join-Path $repoRoot 'tool\templates\marketplace_dispatch_multi_service_selector_v1.dart') `
    -Destination (Join-Path $repoRoot $selectorRelative) -Force
  Copy-Item -LiteralPath (Join-Path $repoRoot 'tool\templates\marketplace_dispatch_directory_actions_v2.dart') `
    -Destination (Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_directory_actions.dart') -Force

  Write-Step 'Formatting and strictly analyzing promoted production before tests'
  $productionDart = @(
    '.\lib\marketplace\marketplace_dispatch_multi_service_selector.dart',
    '.\lib\marketplace\marketplace_dispatch_directory_actions.dart',
    '.\lib\marketplace\marketplace_dispatch_directory.dart',
    '.\lib\marketplace\marketplace_dispatch_page.dart'
  )
  & dart format $productionDart
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Promoted service-selection formatting failed.'
  }
  & dart format --output=none --set-exit-if-changed $productionDart
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Promoted service-selection source is not formatter-stable.'
  }
  foreach ($target in $productionDart) {
    & flutter analyze --fatal-infos --fatal-warnings $target
    if ($LASTEXITCODE -ne 0) {
      throw "STOP: Promoted service-selection analyzer failed for $target"
    }
  }
  Write-Host 'Promoted production analyzer before tests: PASS' -ForegroundColor Green

  Write-Step 'Running focused service-selection restoration contract'
  & flutter test '.\test\dispatch_service_selection_restore_contract_test.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Promoted service-selection restoration contract failed.'
  }

  $trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
  if ($trackerHashAfter -ne $trackerHashBefore) {
    throw 'STOP: Dispatch tracker changed during the service-selection restoration gate.'
  }

  Write-Host "`n============================================================" -ForegroundColor Green
  Write-Host 'PIPE BUYER DISPATCH SERVICE SELECTION RESTORE V1 PASSED' -ForegroundColor Green
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'Exact local structural dry-run: PASS' -ForegroundColor Green
  Write-Host 'Canonical mirror pubspec asset topology: PASS' -ForegroundColor Green
  Write-Host 'Canonical mirror production mutation: NO' -ForegroundColor Green
  Write-Host 'Canonical mirror full candidate analyzer: PASS' -ForegroundColor Green
  Write-Host 'Canonical mirror restoration contract: PASS' -ForegroundColor Green
  Write-Host 'Existing listing-to-trucking workflow preserved: PASS' -ForegroundColor Green
  Write-Host 'Request Service taxonomy menu restored: PASS' -ForegroundColor Green
  Write-Host 'Directory Get Quote provider-only service dropdown: PASS' -ForegroundColor Green
  Write-Host 'Multiple service items + Add Service: PASS' -ForegroundColor Green
  Write-Host 'Requested date + priority + scope form: PASS' -ForegroundColor Green
  Write-Host 'Dispatch tracker modified by gate: NO' -ForegroundColor Green
  Write-Host 'Ready for browser acceptance: YES' -ForegroundColor Green
}
catch {
  if ($mutationStarted -and $backupRoot) {
    Write-Host "`nPost-promotion gate failed. Restoring pre-existing production source..." -ForegroundColor Yellow
    try {
      Restore-RelativeFiles -Root $repoRoot -BackupRoot $backupRoot -RelativePaths $existingProductionFiles
      if ($selectorExistedBefore) {
        Restore-RelativeFiles -Root $repoRoot -BackupRoot $backupRoot -RelativePaths @($selectorRelative)
      }
      elseif (Test-Path -LiteralPath (Join-Path $repoRoot $selectorRelative)) {
        Remove-Item -LiteralPath (Join-Path $repoRoot $selectorRelative) -Force
      }
      Write-Host 'Service-selection production rollback: COMPLETE' -ForegroundColor Yellow
    }
    catch {
      Write-Host "STOP: Automatic rollback also failed: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
  throw
}
finally {
  if ($mirrorRoot -and (Test-Path -LiteralPath $mirrorRoot)) {
    Remove-Item -LiteralPath $mirrorRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
