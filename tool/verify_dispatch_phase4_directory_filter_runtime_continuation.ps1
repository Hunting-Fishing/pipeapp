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
$requiredSourceMarkers = @(
  "_firestore.collection('dispatch_directory_entries')",
  'DispatchDirectoryPageData? _lastSuccessfulData;',
  'Timer? _filterDebounce;',
  'int _loadGeneration = 0;',
  'final generation = ++_loadGeneration;',
  'initialData: _lastSuccessfulData,',
  "'Updating Directory results...'"
)
foreach ($marker in $requiredSourceMarkers) {
  if (-not $directoryText.Contains($marker)) {
    throw "STOP: Already-applied runtime source is missing expected marker: $marker"
  }
}
Write-Host 'Already-applied Directory runtime source recognized: PASS' -ForegroundColor Green

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Synchronizing corrected read-only Directory regression controls'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch corrected Directory regression controls.'
}
$supportFiles = @(
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'docs/repairs/DISPATCH_DIRECTORY_FILTER_RUNTIME_STABILITY.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize corrected Directory regression controls.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage corrected Directory regression controls.'
}

$parseErrors = $null
$parseTokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$parseTokens,
  [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
  throw "STOP: Read-only Directory continuation parser failure: $($parseErrors[0].Message)"
}

Write-Step 'Checking formatter stability without changing production source'
& dart format --output=none --set-exit-if-changed `
  '.\lib\marketplace\marketplace_dispatch_directory.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory runtime source/tests are not formatter-stable. Do not rerun the source mutation.'
}

Write-Step 'Analyzing the already-applied production Directory source BEFORE tests'
& flutter analyze --fatal-infos --fatal-warnings `
  '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: ALREADY-APPLIED DIRECTORY SOURCE DOES NOT COMPILE CLEANLY. Do not rerun the mutation. The analyzer output immediately above is the source-level defect to repair.'
}
Write-Host 'Already-applied Directory source compile/analyzer: PASS' -ForegroundColor Green

Write-Step 'Proving Directory regression-contract hygiene'
& flutter test '.\test\dispatch_directory_runtime_contract_hygiene_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory regression-contract hygiene failed. Production source remains unchanged.'
}
Write-Host 'Directory regression-contract hygiene: PASS' -ForegroundColor Green

Write-Step 'Running corrected runtime and existing Directory regressions'
& flutter test `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory regression failed after production source analyzer PASS. This is now isolated to a test/runtime behavior layer; do not rerun the mutation.'
}

Write-Step 'Strict analyzer on corrected regression files'
& flutter analyze --fatal-infos --fatal-warnings `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Corrected Directory regression files failed strict analyzer.'
}

$directoryHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($directoryHashAfter -ne $directoryHashBefore) {
  throw 'STOP: Read-only continuation modified the production Directory source.'
}
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Read-only continuation modified the Dispatch tracker.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DIRECTORY RUNTIME READ-ONLY CONTINUATION PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Already-applied runtime source recognized: PASS' -ForegroundColor Green
Write-Host 'Production source analyzer before tests: PASS' -ForegroundColor Green
Write-Host 'Regression-contract hygiene: PASS' -ForegroundColor Green
Write-Host 'Runtime stability regression: PASS' -ForegroundColor Green
Write-Host 'Existing Directory regressions: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host 'Production Directory source modified by continuation: NO' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by continuation: NO' -ForegroundColor Green
Write-Host 'Ready for browser Hotshot re-test: YES' -ForegroundColor Green
