# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$branch = (git branch --show-current).Trim()
if ($branch -ne $expectedBranch) {
  throw "STOP: Wrong branch. Expected $expectedBranch, found $branch"
}

$trackerPath = Join-Path $repoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$directoryPath = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_directory.dart'
if (-not (Test-Path -LiteralPath $trackerPath)) {
  throw 'STOP: Dispatch master plan is missing.'
}
if (-not (Test-Path -LiteralPath $directoryPath)) {
  throw 'STOP: Dispatch Directory source is missing.'
}
$trackerHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
$directoryHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash

$directoryText = Get-Content -LiteralPath $directoryPath -Raw
if (-not $directoryText.Contains("_firestore.collection('dispatch_directory_entries')")) {
  throw 'STOP: The accepted server-owned Directory query layer is not installed. Do not apply the runtime continuation to an older Directory source.'
}
if (-not $directoryText.Contains('class MarketplaceDispatchDirectoryPage extends StatefulWidget')) {
  throw 'STOP: The expected Dispatch Directory page was not found.'
}

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Fetching the focused Directory runtime repair controls without merging'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal Directory runtime repair controls.'
}

$supportFiles = @(
  'tool/dispatch_directory_filter_runtime_transform.mjs',
  'tool/verify_dispatch_directory_filter_runtime_transform_dryrun.mjs',
  'tool/apply_dispatch_phase4_directory_filter_stability.mjs',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart',
  'docs/repairs/DISPATCH_DIRECTORY_FILTER_RUNTIME_STABILITY.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Directory runtime repair support bundle.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the Directory runtime repair support bundle.'
}

Write-Step 'Parsing all focused controls before production mutation'
$nodeControls = @(
  'tool/dispatch_directory_filter_runtime_transform.mjs',
  'tool/verify_dispatch_directory_filter_runtime_transform_dryrun.mjs',
  'tool/apply_dispatch_phase4_directory_filter_stability.mjs'
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
  throw "STOP: Directory runtime repair PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Focused Directory runtime control parse preflight: PASS' -ForegroundColor Green

Write-Step 'Preflighting Directory runtime regression-contract hygiene'
& flutter test '.\test\dispatch_directory_runtime_contract_hygiene_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory runtime regression contract is stale. Production source was not mutated.'
}
Write-Host 'Directory runtime contract hygiene: PASS' -ForegroundColor Green

$candidateRelative = 'lib/marketplace/pipebuyer_directory_runtime_preflight.dart'
$candidatePath = Join-Path $repoRoot 'lib\marketplace\pipebuyer_directory_runtime_preflight.dart'
try {
  Write-Step 'Dry-running and compiling the complete transform against the exact local Directory source'
  $env:PIPEBUYER_DIRECTORY_RUNTIME_CANDIDATE = $candidateRelative
  & node '.\tool\verify_dispatch_directory_filter_runtime_transform_dryrun.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Directory runtime transform dry-run failed. Production source was not mutated by this stage.'
  }
  $directoryHashAfterDryRun = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
  if ($directoryHashAfterDryRun -ne $directoryHashBefore) {
    throw 'STOP: Directory runtime dry-run changed production source. Do not continue.'
  }
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw 'STOP: Directory runtime compile-preflight candidate was not created.'
  }

  & dart format $candidatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Formatter rejected the in-memory Directory runtime candidate. Production source was not mutated.'
  }
  & flutter analyze --fatal-infos --fatal-warnings $candidatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Compile/analyzer preflight rejected the transformed Directory candidate. Production source was not mutated.'
  }
  Write-Host 'Exact local-source transform + compile preflight: PASS' -ForegroundColor Green
}
finally {
  Remove-Item Env:PIPEBUYER_DIRECTORY_RUNTIME_CANDIDATE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Applying only the already-proven filter/loading lifecycle repair'
& node '.\tool\apply_dispatch_phase4_directory_filter_stability.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory filter runtime stability repair failed after successful dry-run and compile preflight.'
}

Write-Step 'Formatting only the repaired Directory source and bounded regressions'
$dartFiles = @(
  'lib/marketplace/marketplace_dispatch_directory.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart'
)
& dart format $dartFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Dart formatter failed on the bounded Directory runtime repair.'
}
& dart format --output=none --set-exit-if-changed $dartFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory runtime repair files are not formatter-stable.'
}

Write-Step 'Running strict analyzer before any post-mutation Flutter test'
$analyzeFiles = @(
  'lib/marketplace/marketplace_dispatch_directory.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart'
)
foreach ($target in $analyzeFiles) {
  & flutter analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Strict analyzer failed for $target. Do not rerun the mutation; continue from a read-only/source-focused repair."
  }
}
Write-Host 'Post-mutation compile/analyzer proof: PASS' -ForegroundColor Green

Write-Step 'Running filter runtime stability and existing Directory regressions'
& flutter test `
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory runtime regression failed after source analyzer PASS. Do not rerun the mutation; repair/continue at the test layer.'
}

$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Directory runtime repair modified the Dispatch tracker. Browser acceptance must remain separate.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER PHASE 4 DIRECTORY FILTER RUNTIME REPAIR PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Control parse before mutation: PASS' -ForegroundColor Green
Write-Host 'Regression-contract hygiene before mutation: PASS' -ForegroundColor Green
Write-Host 'Exact current local-source transform dry-run: PASS' -ForegroundColor Green
Write-Host 'Transformed candidate compile/analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Dry-run production mutation: NO' -ForegroundColor Green
Write-Host 'Previously accepted Directory projection/query layer preserved: PASS' -ForegroundColor Green
Write-Host 'Last successful results retained during refresh: PASS' -ForegroundColor Green
Write-Host 'Rapid filter/search refresh debounce: PASS' -ForegroundColor Green
Write-Host 'Stale async refresh completion protection: PASS' -ForegroundColor Green
Write-Host 'Inline refresh/error state instead of blank page: PASS' -ForegroundColor Green
Write-Host 'Post-mutation strict analyzer before tests: PASS' -ForegroundColor Green
Write-Host 'Existing Directory filter regressions: PASS' -ForegroundColor Green
Write-Host 'Formatter stability: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by repair: NO' -ForegroundColor Green
Write-Host 'Ready for browser re-test: YES' -ForegroundColor Green
