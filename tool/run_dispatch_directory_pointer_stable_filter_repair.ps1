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

$directoryPath = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_directory.dart'
$trackerPath = Join-Path $repoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'
if (-not (Test-Path -LiteralPath $directoryPath)) { throw 'STOP: Dispatch Directory source is missing.' }
if (-not (Test-Path -LiteralPath $trackerPath)) { throw 'STOP: Dispatch master plan is missing.' }
$directoryHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
$trackerHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash

$sourceBefore = Get-Content -Raw -LiteralPath $directoryPath
foreach ($required in @(
  'DispatchDirectoryPageData? _lastSuccessfulData;',
  'Timer? _filterDebounce;',
  'final nextLoad = _load();',
  "_firestore.collection('dispatch_directory_entries')"
)) {
  if (-not $sourceBefore.Contains($required)) {
    throw "STOP: Required previously-green Directory lifecycle marker is missing: $required"
  }
}
if ($sourceBefore.Contains('setState(() => _loadFuture = _load());')) {
  throw 'STOP: Previously repaired Future-returning setState callback has regressed. Do not continue.'
}
Write-Host 'Previously-green Directory lifecycle recognized: PASS' -ForegroundColor Green

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Synchronizing the pointer-stable Directory filter repair bundle'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not fetch pointer-stable Directory controls.' }

$supportFiles = @(
  'tool/dispatch_directory_pointer_stable_filter_transform.mjs',
  'tool/verify_dispatch_directory_pointer_stable_candidate.mjs',
  'tool/apply_dispatch_directory_pointer_stable_filter_fix.mjs',
  'tool/templates/dispatch_directory_pointer_stable_candidate_widget_test.dart.txt',
  'tool/dispatch_directory_dropdown_layout_transform.mjs',
  'test/dispatch_directory_pointer_stable_filter_contract_test.dart',
  'test/dispatch_directory_dropdown_layout_contract_test.dart',
  'test/dispatch_directory_filter_setstate_void_contract_test.dart',
  'test/dispatch_directory_seed_safe_repository_contract_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart',
  'test/dispatch_directory_widget_test_harness_hygiene_test.dart',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'docs/repairs/DISPATCH_DIRECTORY_MOUSE_TRACKER_FREEZE.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not synchronize pointer-stable Directory repair bundle.' }
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not unstage pointer-stable Directory repair bundle.' }

Write-Step 'Parsing focused controls before production mutation'
$nodeControls = @(
  'tool/dispatch_directory_pointer_stable_filter_transform.mjs',
  'tool/verify_dispatch_directory_pointer_stable_candidate.mjs',
  'tool/apply_dispatch_directory_pointer_stable_filter_fix.mjs',
  'tool/dispatch_directory_dropdown_layout_transform.mjs'
)
foreach ($target in $nodeControls) {
  & node --check $target
  if ($LASTEXITCODE -ne 0) { throw "STOP: Node parse preflight failed for $target" }
}
$parseErrors = $null
$parseTokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$parseTokens,
  [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
  throw "STOP: Pointer-stable Directory PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Focused control parse: PASS' -ForegroundColor Green

Write-Step 'Formatting synchronized support tests only'
$testFiles = @(
  '.\test\dispatch_directory_pointer_stable_filter_contract_test.dart',
  '.\test\dispatch_directory_dropdown_layout_contract_test.dart',
  '.\test\dispatch_directory_filter_setstate_void_contract_test.dart',
  '.\test\dispatch_directory_seed_safe_repository_contract_test.dart',
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart',
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart',
  '.\test\dispatch_directory_widget_test_harness_hygiene_test.dart',
  '.\test\marketplace_dispatch_directory_test.dart',
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
)
& dart format $testFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not normalize synchronized Directory support tests.' }

$candidateRelative = 'lib/marketplace/pipebuyer_directory_pointer_stable_preflight.dart'
$candidatePath = Join-Path $repoRoot 'lib\marketplace\pipebuyer_directory_pointer_stable_preflight.dart'
$tempTestPath = Join-Path $repoRoot 'test\pipebuyer_directory_pointer_stable_candidate_widget_test.dart'
$templatePath = Join-Path $repoRoot 'tool\templates\dispatch_directory_pointer_stable_candidate_widget_test.dart.txt'
try {
  Write-Step 'Building exact local pointer-stable Directory candidate before production mutation'
  $env:PIPEBUYER_DIRECTORY_POINTER_STABLE_CANDIDATE = $candidateRelative
  & node '.\tool\verify_dispatch_directory_pointer_stable_candidate.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Pointer-stable Directory candidate transformation failed. Production source was not changed.'
  }
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw 'STOP: Pointer-stable Directory candidate was not created.'
  }

  & dart format $candidatePath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Formatter rejected pointer-stable Directory candidate.' }
  & flutter analyze --fatal-infos --fatal-warnings $candidatePath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Analyzer rejected pointer-stable Directory candidate.' }

  Copy-Item -LiteralPath $templatePath -Destination $tempTestPath -Force
  & dart format $tempTestPath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not format pointer-stable Directory candidate runtime test.' }

  Write-Step 'Running repeated MOUSE selection proof before production mutation'
  & flutter test $tempTestPath --reporter expanded
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Pointer-stable candidate still fails repeated mouse selection proof. Production source was not changed.'
  }

  $directoryHashAfterCandidate = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
  if ($directoryHashAfterCandidate -ne $directoryHashBefore) {
    throw 'STOP: Candidate preflight modified production Directory source.'
  }
  Write-Host 'Exact local candidate analyzer + repeated mouse interaction: PASS' -ForegroundColor Green
}
finally {
  Remove-Item Env:PIPEBUYER_DIRECTORY_POINTER_STABLE_CANDIDATE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tempTestPath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Applying only the already-proven pointer-stable filter replacement'
& node '.\tool\apply_dispatch_directory_pointer_stable_filter_fix.mjs'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Pointer-stable Directory source repair failed after candidate PASS.' }

Write-Step 'Formatting and analyzing production Directory source before regressions'
& dart format '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Directory formatting failed.' }
& dart format --output=none --set-exit-if-changed '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Directory source is not formatter-stable.' }
& flutter analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Directory source does not compile after pointer-stable repair.' }
Write-Host 'Production Directory analyzer: PASS' -ForegroundColor Green

Write-Step 'Running pointer-stable and exact Directory interaction regressions first'
& flutter test `
  '.\test\dispatch_directory_pointer_stable_filter_contract_test.dart' `
  '.\test\dispatch_directory_dropdown_layout_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_test.dart' `
  --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Pointer-stable Directory interaction regression failed. Do not rerun older source repairs.'
}

Write-Step 'Running previously-green Directory lifecycle/projection regressions'
& flutter test `
  '.\test\dispatch_directory_filter_setstate_void_contract_test.dart' `
  '.\test\dispatch_directory_seed_safe_repository_contract_test.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart' `
  '.\test\dispatch_directory_widget_test_harness_hygiene_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart' `
  --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Previously-green Directory sibling regression failed after pointer-stable repair.'
}

Write-Step 'Strict analyzer on synchronized regression files'
foreach ($target in $testFiles) {
  & flutter analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) { throw "STOP: Strict analyzer failed for support regression: $target" }
}

$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Pointer-stable Directory repair modified the Dispatch tracker.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DIRECTORY POINTER-STABLE FILTER REPAIR PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Previously-green lifecycle recognized: PASS' -ForegroundColor Green
Write-Host 'Control parse before mutation: PASS' -ForegroundColor Green
Write-Host 'Exact local candidate analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Repeated mouse selector runtime before mutation: PASS' -ForegroundColor Green
Write-Host 'Candidate production mutation: NO' -ForegroundColor Green
Write-Host 'Overlay dropdown filters removed: PASS' -ForegroundColor Green
Write-Host 'Same-tree inline selectors installed: PASS' -ForegroundColor Green
Write-Host 'Pointer-triggered geometry staging: PASS' -ForegroundColor Green
Write-Host 'Production analyzer before regressions: PASS' -ForegroundColor Green
Write-Host 'Directory interaction regression: PASS' -ForegroundColor Green
Write-Host 'Seed-safe/setState/runtime/projection regressions: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by repair: NO' -ForegroundColor Green
Write-Host 'Ready for browser mouse-selection re-test: YES' -ForegroundColor Green
