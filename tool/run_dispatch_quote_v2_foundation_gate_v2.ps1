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
Write-Step 'Synchronizing only the corrected Dispatch Quote V2 support bundle'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the corrected Dispatch Quote V2 support bundle.'
}

$supportFiles = @(
  'lib/marketplace/marketplace_dispatch_quote_form.dart',
  'tool/dispatch_quote_v2_foundation_transform_v2.mjs',
  'tool/dispatch_quote_v2_foundation_transform_v3.mjs',
  'tool/verify_dispatch_quote_v2_foundation_dryrun_v2.mjs',
  'tool/prepare_dispatch_quote_v2_foundation_candidate_v2.mjs',
  'tool/apply_dispatch_quote_v2_foundation_v2.mjs',
  'test/dispatch_quote_v2_foundation_contract_test.dart',
  'firebase/functions/test/dispatch_quote_v2_policy.test.js',
  'docs/DISPATCH_QUOTE_V2_FOUNDATION.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the corrected Dispatch Quote V2 support files.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the corrected Dispatch Quote V2 support files.'
}

Write-Step 'Parsing every corrected Quote V2 control before production mutation'
$nodeControls = @(
  '.\tool\dispatch_quote_v2_foundation_transform_v2.mjs',
  '.\tool\dispatch_quote_v2_foundation_transform_v3.mjs',
  '.\tool\verify_dispatch_quote_v2_foundation_dryrun_v2.mjs',
  '.\tool\prepare_dispatch_quote_v2_foundation_candidate_v2.mjs',
  '.\tool\apply_dispatch_quote_v2_foundation_v2.mjs'
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
  throw "STOP: Corrected Quote V2 PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Corrected Quote V2 control parse before mutation: PASS' -ForegroundColor Green

Write-Step 'Formatting focused support Dart files before candidate validation'
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
  throw 'STOP: Quote V2 support Dart files are not formatter-stable.'
}

Write-Step 'Strictly analyzing the reusable quote form before any existing source changes'
& flutter analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_quote_form.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Reusable Quote V2 form does not compile cleanly. Production source was not changed.'
}
Write-Host 'Reusable quote form analyzer before mutation: PASS' -ForegroundColor Green

Write-Step 'Running corrected exact-local-source Quote V2 dry-run'
& node '.\tool\verify_dispatch_quote_v2_foundation_dryrun_v2.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Corrected Quote V2 exact-local dry-run failed. Production source was not changed.'
}
foreach ($relative in $productionFiles) {
  $currentHash =
      (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot $relative)).Hash
  if ($currentHash -ne $productionHashesBefore[$relative]) {
    throw "STOP: Corrected Quote V2 dry-run changed production source: $relative"
  }
}
Write-Host 'Corrected exact local dry-run production mutation: NO' -ForegroundColor Green

$candidateFiles = @(
  'lib\marketplace\pipebuyer_dispatch_repository_quote_v2_preflight.dart',
  'lib\marketplace\pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
  'lib\marketplace\pipebuyer_dispatch_page_quote_v2_preflight.dart',
  'firebase\functions\dispatch_command_policy_quote_v2_preflight.js',
  'firebase\functions\dispatch_commands_quote_v2_preflight.js'
)
$candidatePolicyTest =
    'firebase\functions\test\dispatch_quote_v2_candidate_policy_preflight.test.js'

try {
  Write-Step 'Building corrected Quote V2 candidate files without modifying production'
  & node '.\tool\prepare_dispatch_quote_v2_foundation_candidate_v2.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Corrected Quote V2 candidate build failed. Production source was not changed.'
  }
  foreach ($relative in $candidateFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) {
      throw "STOP: Expected Quote V2 candidate file was not created: $relative"
    }
  }

  $candidateDashboard = Join-Path $repoRoot 'lib\marketplace\pipebuyer_dispatch_dashboard_quote_v2_preflight.dart'
  $candidateDashboardSource = Get-Content -Raw -LiteralPath $candidateDashboard
  if ($candidateDashboardSource.Contains('class _DispatchQuoteDialog extends StatefulWidget')) {
    throw 'STOP: Corrected Quote V2 candidate still contains the retired Dashboard quote editor.'
  }
  Write-Host 'Retired Dashboard quote editor absent from candidate: PASS' -ForegroundColor Green

  Write-Step 'Formatting candidate Dart files and checking candidate Functions syntax'
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
    throw 'STOP: Candidate Dispatch quote policy has invalid JavaScript syntax.'
  }
  & node --check '.\firebase\functions\dispatch_commands_quote_v2_preflight.js'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Candidate Dispatch quote command has invalid JavaScript syntax.'
  }

  Write-Step 'Analyzing corrected isolated Quote V2 repository and dashboard candidate graph'
  & flutter analyze --fatal-infos --fatal-warnings `
    '.\lib\marketplace\pipebuyer_dispatch_repository_quote_v2_preflight.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Candidate Quote V2 repository does not compile. Production source was not changed.'
  }
  & flutter analyze --fatal-infos --fatal-warnings `
    '.\lib\marketplace\pipebuyer_dispatch_dashboard_quote_v2_preflight.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Candidate Quote V2 dashboard does not compile. Production source was not changed.'
  }
  Write-Host 'Corrected candidate repository/dashboard analyzer: PASS' -ForegroundColor Green

  Write-Step 'Running server-total verification against the candidate quote policy'
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
      throw "STOP: Quote V2 candidate preflight modified production source: $relative"
    }
  }
  Write-Host 'Candidate production mutation: NO' -ForegroundColor Green
}
finally {
  foreach ($relative in $candidateFiles + @($candidatePolicyTest)) {
    Remove-Item -LiteralPath (Join-Path $repoRoot $relative) `
      -Force -ErrorAction SilentlyContinue
  }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $repoRoot "_local_backups\dispatch-quote-v2-gate-v2-$stamp"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
foreach ($relative in $productionFiles) {
  Copy-RelativeFile -Root $repoRoot -RelativePath $relative -DestinationRoot $backupRoot
}
Write-Host "Gate rollback backup: $backupRoot" -ForegroundColor DarkGray

$mutationStarted = $false
try {
  Write-Step 'Applying only the already-preflighted corrected Quote V2 transformation'
  $mutationStarted = $true
  & node '.\tool\apply_dispatch_quote_v2_foundation_v2.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Corrected Quote V2 source transformation failed. The gate will restore its backup.'
  }

  $productionDashboardSource = Get-Content -Raw -LiteralPath `
    (Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_dashboard.dart')
  if ($productionDashboardSource.Contains('class _DispatchQuoteDialog extends StatefulWidget')) {
    throw 'STOP: Retired Dashboard quote editor remains in production after Quote V2 application.'
  }

  Write-Step 'Formatting and strictly analyzing production Dart before regressions'
  $productionDart = @(
    '.\lib\marketplace\marketplace_dispatch_quote_form.dart',
    '.\lib\marketplace\marketplace_dispatch_repository.dart',
    '.\lib\marketplace\marketplace_dispatch_dashboard.dart',
    '.\lib\marketplace\marketplace_dispatch_page.dart'
  )
  & dart format $productionDart
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Production Quote V2 Dart formatting failed.'
  }
  & dart format --output=none --set-exit-if-changed $productionDart
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Production Quote V2 Dart is not formatter-stable.'
  }
  foreach ($target in $productionDart) {
    & flutter analyze --fatal-infos --fatal-warnings $target
    if ($LASTEXITCODE -ne 0) {
      throw "STOP: Production Quote V2 analyzer failed for $target"
    }
  }
  Write-Host 'Production Quote V2 analyzer before tests: PASS' -ForegroundColor Green

  Write-Step 'Checking production Dispatch Functions syntax before tests'
  & node --check '.\firebase\functions\dispatch_command_policy.js'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Production Dispatch quote policy syntax failed.'
  }
  & node --check '.\firebase\functions\dispatch_commands.js'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Production Dispatch quote command syntax failed.'
  }
  Write-Host 'Production Functions syntax: PASS' -ForegroundColor Green

  Write-Step 'Running Quote V2 server calculation and existing Dispatch policy regressions'
  & node --test '.\firebase\functions\test\dispatch_quote_v2_policy.test.js'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Quote V2 server calculation regression failed.'
  }
  & node --test '.\firebase\functions\test\dispatch_command_policy.test.js'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Existing Dispatch command policy regression failed.'
  }

  Write-Step 'Running the corrected Quote V2 Flutter integration contract'
  & flutter test '.\test\dispatch_quote_v2_foundation_contract_test.dart' `
    --reporter expanded
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Corrected Quote V2 Flutter integration contract failed.'
  }

  $trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
  if ($trackerHashAfter -ne $trackerHashBefore) {
    throw 'STOP: Quote V2 foundation gate modified the Dispatch tracker.'
  }
}
catch {
  $failure = $_
  if ($mutationStarted) {
    Write-Host ''
    Write-Host 'Quote V2 post-mutation gate failed. Restoring all pre-existing production sources from the gate backup...' -ForegroundColor Yellow
    Restore-RelativeFiles `
      -Root $repoRoot `
      -BackupRoot $backupRoot `
      -RelativePaths $productionFiles
    Write-Host 'Quote V2 production rollback: COMPLETE' -ForegroundColor Green
  }
  throw $failure
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH QUOTE V2 FOUNDATION V2 PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Reusable detailed quote form analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Corrected exact local dry-run before mutation: PASS' -ForegroundColor Green
Write-Host 'Retired Dashboard quote editor absent from candidate: PASS' -ForegroundColor Green
Write-Host 'Candidate repository/dashboard analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Candidate server-calculated total proof: PASS' -ForegroundColor Green
Write-Host 'Candidate production mutation: NO' -ForegroundColor Green
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
