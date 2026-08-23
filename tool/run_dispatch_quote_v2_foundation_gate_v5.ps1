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

$productionFiles = @(
  'lib\marketplace\marketplace_dispatch_page.dart',
  'lib\marketplace\marketplace_dispatch_dashboard.dart',
  'lib\marketplace\marketplace_dispatch_repository.dart',
  'firebase\functions\dispatch_command_policy.js',
  'firebase\functions\dispatch_commands.js'
)
foreach ($relative in $productionFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) {
    throw "STOP: Required Quote V2 production source is missing: $relative"
  }
}
$productionHashesBefore = @{}
foreach ($relative in $productionFiles) {
  $productionHashesBefore[$relative] =
      (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
}

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Synchronizing the Quote V2 V5 canonical-mirror support bundle'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the Quote V2 V5 support bundle.'
}
$supportFiles = @(
  'lib/marketplace/marketplace_dispatch_quote_form.dart',
  'tool/dispatch_quote_v2_foundation_transform_v2.mjs',
  'tool/dispatch_quote_v2_foundation_transform_v3.mjs',
  'tool/verify_dispatch_quote_v2_foundation_dryrun_v2.mjs',
  'tool/prepare_dispatch_quote_v2_foundation_candidate_v2.mjs',
  'tool/clean_dispatch_quote_v2_candidate_hygiene.mjs',
  'tool/promote_dispatch_quote_v2_candidate.mjs',
  'test/dispatch_quote_v2_foundation_contract_test.dart',
  'firebase/functions/test/dispatch_quote_v2_policy.test.js',
  'docs/DISPATCH_QUOTE_V2_FOUNDATION.md',
  'docs/repairs/DISPATCH_QUOTE_V2_CANDIDATE_HYGIENE.md',
  'docs/repairs/DISPATCH_QUOTE_V2_CANONICAL_MIRROR_PREFLIGHT.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Quote V2 V5 support files.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the Quote V2 V5 support files.'
}

Write-Step 'Parsing Quote V2 V5 controls before production mutation'
$nodeControls = @(
  '.\tool\dispatch_quote_v2_foundation_transform_v2.mjs',
  '.\tool\dispatch_quote_v2_foundation_transform_v3.mjs',
  '.\tool\verify_dispatch_quote_v2_foundation_dryrun_v2.mjs',
  '.\tool\prepare_dispatch_quote_v2_foundation_candidate_v2.mjs',
  '.\tool\clean_dispatch_quote_v2_candidate_hygiene.mjs',
  '.\tool\promote_dispatch_quote_v2_candidate.mjs'
)
foreach ($target in $nodeControls) {
  & node --check $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Node parse preflight failed for $target"
  }
}
$parseErrors = $null
$parseTokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$parseTokens,
  [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
  throw "STOP: Quote V2 V5 PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Quote V2 V5 control parse: PASS' -ForegroundColor Green

Write-Step 'Formatting and analyzing reusable Quote V2 support before candidate build'
$supportDart = @(
  '.\lib\marketplace\marketplace_dispatch_quote_form.dart',
  '.\test\dispatch_quote_v2_foundation_contract_test.dart'
)
& dart format $supportDart
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Quote V2 support Dart formatting failed before mutation.'
}
& dart format --output=none --set-exit-if-changed $supportDart
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Quote V2 support Dart is not formatter-stable.'
}
& flutter analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_quote_form.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Reusable Quote V2 form does not compile. Production source was not changed.'
}
Write-Host 'Reusable Quote V2 form analyzer before mutation: PASS' -ForegroundColor Green

Write-Step 'Running exact-local Quote V2 structural dry-run'
& node '.\tool\verify_dispatch_quote_v2_foundation_dryrun_v2.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Quote V2 exact-local structural dry-run failed. Production source was not changed.'
}
foreach ($relative in $productionFiles) {
  $currentHash =
      (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
  if ($currentHash -ne $productionHashesBefore[$relative]) {
    throw "STOP: Quote V2 dry-run changed production source: $relative"
  }
}
Write-Host 'Exact local dry-run production mutation: NO' -ForegroundColor Green

$candidateFiles = @(
  'lib\marketplace\pipebuyer_dispatch_repository_quote_v2_preflight.dart',
  'lib\marketplace\pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
  'lib\marketplace\pipebuyer_dispatch_page_quote_v2_preflight.dart',
  'firebase\functions\dispatch_command_policy_quote_v2_preflight.js',
  'firebase\functions\dispatch_commands_quote_v2_preflight.js'
)
$candidatePolicyTest = 'firebase\functions\test\dispatch_quote_v2_candidate_policy_preflight.test.js'
$mutationStarted = $false
$backupRoot = $null
$mirrorRoot = $null

try {
  Write-Step 'Building the exact transformed Quote V2 candidate without changing production'
  & node '.\tool\prepare_dispatch_quote_v2_foundation_candidate_v2.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Quote V2 candidate build failed. Production source was not changed.'
  }
  foreach ($relative in $candidateFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) {
      throw "STOP: Expected Quote V2 candidate file was not created: $relative"
    }
  }

  Write-Step 'Running deterministic candidate hygiene on Dashboard and Jobs'
  & node '.\tool\clean_dispatch_quote_v2_candidate_hygiene.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Quote V2 deterministic candidate hygiene failed. Production source was not changed.'
  }

  $candidateDart = @(
    '.\lib\marketplace\pipebuyer_dispatch_repository_quote_v2_preflight.dart',
    '.\lib\marketplace\pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
    '.\lib\marketplace\pipebuyer_dispatch_page_quote_v2_preflight.dart'
  )
  & dart format $candidateDart
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Quote V2 candidate Dart formatter failed. Production source was not changed.'
  }
  & node --check '.\firebase\functions\dispatch_command_policy_quote_v2_preflight.js'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Candidate Dispatch quote policy syntax failed.'
  }
  & node --check '.\firebase\functions\dispatch_commands_quote_v2_preflight.js'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Candidate Dispatch quote command syntax failed.'
  }

  Write-Step 'Building a canonical-filename mirror of the exact local package for cross-file analysis'
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $mirrorRoot = Join-Path $repoRoot "_local_preflight\dispatch-quote-v2-v5-$stamp"
  New-Item -ItemType Directory -Force -Path $mirrorRoot | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Destination $mirrorRoot -Force
  if (Test-Path -LiteralPath (Join-Path $repoRoot 'pubspec.lock')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'pubspec.lock') -Destination $mirrorRoot -Force
  }
  if (Test-Path -LiteralPath (Join-Path $repoRoot 'analysis_options.yaml')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'analysis_options.yaml') -Destination $mirrorRoot -Force
  }
  Copy-Item -LiteralPath (Join-Path $repoRoot 'lib') -Destination $mirrorRoot -Recurse -Force
  New-Item -ItemType Directory -Force -Path (Join-Path $mirrorRoot '.dart_tool') | Out-Null
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.dart_tool\package_config.json'))) {
    throw 'STOP: Local .dart_tool/package_config.json is missing; run flutter pub get before Quote V2 V5.'
  }
  Copy-Item -LiteralPath (Join-Path $repoRoot '.dart_tool\package_config.json') `
    -Destination (Join-Path $mirrorRoot '.dart_tool\package_config.json') -Force

  Copy-Item -LiteralPath (Join-Path $repoRoot 'lib\marketplace\pipebuyer_dispatch_repository_quote_v2_preflight.dart') `
    -Destination (Join-Path $mirrorRoot 'lib\marketplace\marketplace_dispatch_repository.dart') -Force
  Copy-Item -LiteralPath (Join-Path $repoRoot 'lib\marketplace\pipebuyer_dispatch_dashboard_quote_v2_preflight.dart') `
    -Destination (Join-Path $mirrorRoot 'lib\marketplace\marketplace_dispatch_dashboard.dart') -Force
  Copy-Item -LiteralPath (Join-Path $repoRoot 'lib\marketplace\pipebuyer_dispatch_page_quote_v2_preflight.dart') `
    -Destination (Join-Path $mirrorRoot 'lib\marketplace\marketplace_dispatch_page.dart') -Force

  foreach ($relative in $productionFiles) {
    $currentHash =
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
    if ($currentHash -ne $productionHashesBefore[$relative]) {
      throw "STOP: Canonical mirror preparation changed production source: $relative"
    }
  }
  Write-Host 'Canonical mirror production mutation: NO' -ForegroundColor Green

  Write-Step 'Strictly analyzing the Quote V2 candidate as one coherent package graph'
  Push-Location $mirrorRoot
  try {
    $mirrorTargets = @(
      '.\lib\marketplace\marketplace_dispatch_repository.dart',
      '.\lib\marketplace\marketplace_dispatch_dashboard.dart',
      '.\lib\marketplace\marketplace_dispatch_page.dart'
    )
    foreach ($target in $mirrorTargets) {
      & flutter analyze --fatal-infos --fatal-warnings $target
      if ($LASTEXITCODE -ne 0) {
        throw "STOP: Quote V2 canonical-mirror candidate does not compile cleanly: $target"
      }
    }
  }
  finally {
    Pop-Location
  }
  Write-Host 'Canonical mirror repository/dashboard/page analyzer before mutation: PASS' -ForegroundColor Green

  Write-Step 'Running server-total verification against the exact candidate quote policy'
  $policyTestSource = Get-Content -Raw -LiteralPath `
    (Join-Path $repoRoot 'firebase\functions\test\dispatch_quote_v2_policy.test.js')
  $policyTestSource = $policyTestSource.Replace(
    'require("../dispatch_command_policy")',
    'require("../dispatch_command_policy_quote_v2_preflight")'
  )
  Set-Content -LiteralPath (Join-Path $repoRoot $candidatePolicyTest) `
    -Value $policyTestSource -Encoding ASCII
  & node --test (Join-Path $repoRoot $candidatePolicyTest)
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Candidate Quote V2 server calculation proof failed. Production source was not changed.'
  }
  Write-Host 'Candidate server-calculated quote proof: PASS' -ForegroundColor Green

  foreach ($relative in $productionFiles) {
    $currentHash =
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
    if ($currentHash -ne $productionHashesBefore[$relative]) {
      throw "STOP: Quote V2 V5 preflight modified production source: $relative"
    }
  }
  Write-Host 'Candidate production mutation: NO' -ForegroundColor Green

  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backupRoot = Join-Path $repoRoot "_local_backups\dispatch-quote-v2-v5-$stamp"
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  foreach ($relative in $productionFiles) {
    Copy-RelativeFile -Root $repoRoot -RelativePath $relative -DestinationRoot $backupRoot
  }
  Write-Host "Gate rollback backup: $backupRoot" -ForegroundColor DarkGray

  Write-Step 'Promoting the exact candidate proven inside the canonical mirror'
  $mutationStarted = $true
  & node '.\tool\promote_dispatch_quote_v2_candidate.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Quote V2 candidate promotion failed. The gate will restore its backup.'
  }

  Write-Step 'Formatting and strictly analyzing promoted production before regressions'
  $productionDart = @(
    '.\lib\marketplace\marketplace_dispatch_quote_form.dart',
    '.\lib\marketplace\marketplace_dispatch_repository.dart',
    '.\lib\marketplace\marketplace_dispatch_dashboard.dart',
    '.\lib\marketplace\marketplace_dispatch_page.dart'
  )
  & dart format $productionDart
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Promoted Quote V2 Dart formatting failed.'
  }
  & dart format --output=none --set-exit-if-changed $productionDart
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Promoted Quote V2 Dart is not formatter-stable.'
  }
  foreach ($target in $productionDart) {
    & flutter analyze --fatal-infos --fatal-warnings $target
    if ($LASTEXITCODE -ne 0) {
      throw "STOP: Promoted Quote V2 analyzer failed for $target"
    }
  }
  Write-Host 'Promoted production Quote V2 analyzer before tests: PASS' -ForegroundColor Green

  Write-Step 'Checking promoted Dispatch Functions syntax before tests'
  & node --check '.\firebase\functions\dispatch_command_policy.js'
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Dispatch quote policy syntax failed.' }
  & node --check '.\firebase\functions\dispatch_commands.js'
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Dispatch quote command syntax failed.' }
  Write-Host 'Promoted production Functions syntax: PASS' -ForegroundColor Green

  Write-Step 'Running Quote V2 and existing Dispatch policy regressions'
  & node --test '.\firebase\functions\test\dispatch_quote_v2_policy.test.js'
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Quote V2 server calculation regression failed.' }
  & node --test '.\firebase\functions\test\dispatch_command_policy.test.js'
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Existing Dispatch command policy regression failed.' }

  Write-Step 'Running Quote V2 Flutter integration contract'
  & flutter test '.\test\dispatch_quote_v2_foundation_contract_test.dart' --reporter expanded
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Quote V2 Flutter integration contract failed.' }

  $trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
  if ($trackerHashAfter -ne $trackerHashBefore) {
    throw 'STOP: Quote V2 V5 gate modified the Dispatch tracker.'
  }
}
catch {
  $failure = $_
  if ($mutationStarted -and $backupRoot) {
    Write-Host ''
    Write-Host 'Quote V2 post-promotion gate failed. Restoring all pre-existing production sources...' -ForegroundColor Yellow
    Restore-RelativeFiles -Root $repoRoot -BackupRoot $backupRoot -RelativePaths $productionFiles
    Write-Host 'Quote V2 production rollback: COMPLETE' -ForegroundColor Green
  }
  throw $failure
}
finally {
  foreach ($relative in $candidateFiles + @($candidatePolicyTest)) {
    Remove-Item -LiteralPath (Join-Path $repoRoot $relative) -Force -ErrorAction SilentlyContinue
  }
  if ($mirrorRoot -and (Test-Path -LiteralPath $mirrorRoot)) {
    Remove-Item -LiteralPath $mirrorRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH QUOTE V2 V5 CANONICAL-MIRROR GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Reusable detailed quote form analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Exact local structural dry-run: PASS' -ForegroundColor Green
Write-Host 'Deterministic Dashboard + Jobs candidate hygiene: PASS' -ForegroundColor Green
Write-Host 'Canonical mirror production mutation: NO' -ForegroundColor Green
Write-Host 'Canonical mirror repository/dashboard/page analyzer: PASS' -ForegroundColor Green
Write-Host 'Candidate server-calculated total proof: PASS' -ForegroundColor Green
Write-Host 'Candidate production mutation: NO' -ForegroundColor Green
Write-Host 'Exact mirror-proven candidate promoted to production: PASS' -ForegroundColor Green
Write-Host 'Legacy Jobs all-in quote dialog removed: PASS' -ForegroundColor Green
Write-Host 'Retired Dashboard Quote V1 editor removed: PASS' -ForegroundColor Green
Write-Host 'Jobs + Dashboard shared Quote V2 form: PASS' -ForegroundColor Green
Write-Host 'Full versionable quote breakdown persistence: PASS' -ForegroundColor Green
Write-Host 'Server recalculation / client-total mismatch rejection: PASS' -ForegroundColor Green
Write-Host 'Existing immutable quote revisions preserved: PASS' -ForegroundColor Green
Write-Host 'Stable quote reference + version metadata: PASS' -ForegroundColor Green
Write-Host 'Existing Dispatch command policy regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by gate: NO' -ForegroundColor Green
Write-Host 'Ready for Quote V2 B1 browser acceptance: YES' -ForegroundColor Green
Write-Host 'Next after browser acceptance: B2 cancellation + invalid-watermark viewer.' -ForegroundColor Cyan
