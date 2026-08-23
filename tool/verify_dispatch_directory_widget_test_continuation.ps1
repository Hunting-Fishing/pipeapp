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
if (-not (Test-Path -LiteralPath $directoryPath)) {
  throw 'STOP: Dispatch Directory source is missing.'
}
if (-not (Test-Path -LiteralPath $trackerPath)) {
  throw 'STOP: Dispatch master plan is missing.'
}

$directoryHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
$trackerHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash

$directoryText = Get-Content -LiteralPath $directoryPath -Raw
$requiredMarkers = @(
  "_firestore.collection('dispatch_directory_entries')",
  'DispatchDirectoryPageData? _lastSuccessfulData;',
  'Timer? _filterDebounce;',
  'late final MarketplaceDispatchDirectoryRepository _repository;',
  "'Updating Directory results...'"
)
foreach ($marker in $requiredMarkers) {
  if (-not $directoryText.Contains($marker)) {
    throw "STOP: Already-applied Directory source is missing expected marker: $marker"
  }
}
Write-Host 'Already-applied Directory source recognized: PASS' -ForegroundColor Green

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Synchronizing corrected Directory widget-test harness controls'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch corrected Directory widget-test controls.'
}

$supportFiles = @(
  'test/marketplace_dispatch_directory_test.dart',
  'test/dispatch_directory_widget_test_harness_hygiene_test.dart',
  'test/dispatch_directory_repository_nullability_contract_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'docs/repairs/DISPATCH_DIRECTORY_WIDGET_TEST_HARNESS.md',
  'docs/repairs/DISPATCH_DIRECTORY_REPOSITORY_NULLABILITY.md',
  'docs/repairs/DISPATCH_DIRECTORY_FILTER_RUNTIME_STABILITY.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize corrected Directory widget-test support bundle.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage corrected Directory widget-test support bundle.'
}

$parseErrors = $null
$parseTokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$parseTokens,
  [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
  throw "STOP: Directory widget-test continuation parser failure: $($parseErrors[0].Message)"
}

Write-Step 'Formatting synchronized test/support Dart files only'
$testFiles = @(
  '.\test\marketplace_dispatch_directory_test.dart',
  '.\test\dispatch_directory_widget_test_harness_hygiene_test.dart',
  '.\test\dispatch_directory_repository_nullability_contract_test.dart',
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart',
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart',
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
)
& dart format $testFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not normalize synchronized Directory tests.'
}
& dart format --output=none --set-exit-if-changed $testFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Synchronized Directory tests are not formatter-stable after normalization.'
}
Write-Host 'Directory test/support formatter normalization: PASS' -ForegroundColor Green

Write-Step 'Checking production Directory formatter stability without rewriting it'
& dart format --output=none --set-exit-if-changed '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory source is not formatter-stable. Do not rerun any earlier source mutation.'
}
Write-Host 'Production Directory formatter stability: PASS' -ForegroundColor Green

Write-Step 'Analyzing already-applied production Directory source before tests'
& flutter analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory source no longer analyzes cleanly. The analyzer output above is the only source layer to repair.'
}
Write-Host 'Production Directory analyzer: PASS' -ForegroundColor Green

Write-Step 'Proving Directory widget-test harness hygiene before feature tests'
& flutter test '.\test\dispatch_directory_widget_test_harness_hygiene_test.dart' --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory widget-test harness hygiene failed. Production source remains unchanged.'
}
Write-Host 'Directory widget-test harness hygiene: PASS' -ForegroundColor Green

Write-Step 'Running the corrected Directory widget acceptance tests in isolation'
& flutter test '.\test\marketplace_dispatch_directory_test.dart' --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Corrected Directory widget test still failed. Production source analyzer already passed; inspect the first exception above and do not rerun prior source mutations.'
}
Write-Host 'Directory widget acceptance regression: PASS' -ForegroundColor Green

Write-Step 'Running retained Directory source/runtime regressions'
& flutter test `
  '.\test\dispatch_directory_repository_nullability_contract_test.dart' `
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart' `
  --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Retained Directory regression failed after production analyzer and widget harness PASS. Do not rerun earlier mutations.'
}

Write-Step 'Strict analyzer on corrected Directory test/support files'
foreach ($target in $testFiles) {
  & flutter analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Strict analyzer failed for corrected Directory support test: $target"
  }
}

$directoryHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($directoryHashAfter -ne $directoryHashBefore) {
  throw 'STOP: Read-only widget-test continuation modified production Directory source.'
}
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Read-only widget-test continuation modified the Dispatch tracker.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DIRECTORY WIDGET-TEST CONTINUATION PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Already-applied production source recognized: PASS' -ForegroundColor Green
Write-Host 'Production formatter stability: PASS' -ForegroundColor Green
Write-Host 'Production analyzer before tests: PASS' -ForegroundColor Green
Write-Host 'Widget-test harness hygiene: PASS' -ForegroundColor Green
Write-Host 'Directory widget acceptance regression: PASS' -ForegroundColor Green
Write-Host 'Repository nullability regression: PASS' -ForegroundColor Green
Write-Host 'Filter runtime regression: PASS' -ForegroundColor Green
Write-Host 'Projection/query regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host 'Production Directory source modified by continuation: NO' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by continuation: NO' -ForegroundColor Green
Write-Host 'Ready for browser Hotshot re-test: YES' -ForegroundColor Green
