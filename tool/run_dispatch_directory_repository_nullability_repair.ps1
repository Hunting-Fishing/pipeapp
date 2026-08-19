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

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Synchronizing the bounded repository-nullability repair controls'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal Directory nullability repair controls.'
}

$supportFiles = @(
  'tool/dispatch_directory_repository_nullability_transform.mjs',
  'tool/verify_dispatch_directory_repository_nullability_candidate.mjs',
  'tool/apply_dispatch_directory_repository_nullability_fix.mjs',
  'test/dispatch_directory_repository_nullability_contract_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'docs/repairs/DISPATCH_DIRECTORY_REPOSITORY_NULLABILITY.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Directory nullability repair bundle.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the Directory nullability repair bundle.'
}

Write-Step 'Parsing all focused controls before production mutation'
$nodeControls = @(
  'tool/dispatch_directory_repository_nullability_transform.mjs',
  'tool/verify_dispatch_directory_repository_nullability_candidate.mjs',
  'tool/apply_dispatch_directory_repository_nullability_fix.mjs'
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
  throw "STOP: Directory nullability repair PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Focused source-repair control parse: PASS' -ForegroundColor Green

Write-Step 'Formatting synchronized regression/support files only'
$testFiles = @(
  '.\test\dispatch_directory_repository_nullability_contract_test.dart',
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart',
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart',
  '.\test\marketplace_dispatch_directory_test.dart',
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
)
& dart format $testFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not normalize synchronized Directory regression/support tests.'
}

$candidateRelative = 'lib/marketplace/pipebuyer_directory_repository_nullability_preflight.dart'
$candidatePath = Join-Path $repoRoot 'lib\marketplace\pipebuyer_directory_repository_nullability_preflight.dart'
try {
  Write-Step 'Building and compiling the exact local one-field repair candidate before source mutation'
  $env:PIPEBUYER_DIRECTORY_REPOSITORY_CANDIDATE = $candidateRelative
  & node '.\tool\verify_dispatch_directory_repository_nullability_candidate.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Directory repository nullability candidate transformation failed. Production source was not changed.'
  }
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw 'STOP: Directory repository compile-preflight candidate was not created.'
  }
  & dart format $candidatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Formatter rejected the Directory nullability candidate. Production source was not changed.'
  }
  & flutter analyze --fatal-infos --fatal-warnings $candidatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Analyzer rejected the Directory nullability candidate. Production source was not changed.'
  }
  $directoryHashAfterCandidate = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
  if ($directoryHashAfterCandidate -ne $directoryHashBefore) {
    throw 'STOP: Candidate preflight modified production Directory source.'
  }
  Write-Host 'Exact local one-field candidate compile/analyzer: PASS' -ForegroundColor Green
}
finally {
  Remove-Item Env:PIPEBUYER_DIRECTORY_REPOSITORY_CANDIDATE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Applying only the proven repository nullability correction'
& node '.\tool\apply_dispatch_directory_repository_nullability_fix.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory repository nullability source repair failed after candidate PASS.'
}

Write-Step 'Formatting and analyzing production Directory source before tests'
& dart format '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory formatting failed after the bounded source repair.'
}
& dart format --output=none --set-exit-if-changed '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory source is not formatter-stable after repair.'
}
& flutter analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory source still does not compile cleanly after the bounded nullability repair.'
}
Write-Host 'Production Directory compile/analyzer: PASS' -ForegroundColor Green

Write-Step 'Running repository-nullability and retained-runtime regressions'
& flutter test `
  '.\test\dispatch_directory_repository_nullability_contract_test.dart' `
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory regression failed after production analyzer PASS. Do not rerun this source repair.'
}

Write-Step 'Strict analyzer on bounded regression files'
foreach ($target in $testFiles) {
  & flutter analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Strict analyzer failed for support regression: $target"
  }
}

$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Directory repository nullability repair modified the Dispatch tracker.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DIRECTORY REPOSITORY NULLABILITY REPAIR PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Control parse before mutation: PASS' -ForegroundColor Green
Write-Host 'Exact local repaired candidate analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Candidate production mutation: NO' -ForegroundColor Green
Write-Host 'Repository field non-null late-final: PASS' -ForegroundColor Green
Write-Host 'initState repository assignment preserved: PASS' -ForegroundColor Green
Write-Host 'Production source analyzer before tests: PASS' -ForegroundColor Green
Write-Host 'Runtime stability regression preserved: PASS' -ForegroundColor Green
Write-Host 'Existing Directory regressions: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by repair: NO' -ForegroundColor Green
Write-Host 'Ready for browser Hotshot re-test: YES' -ForegroundColor Green
