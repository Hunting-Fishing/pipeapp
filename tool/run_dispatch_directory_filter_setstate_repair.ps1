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

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Synchronizing the focused Directory setState void-safety repair bundle'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not fetch Directory setState repair controls.' }

$supportFiles = @(
  'tool/dispatch_directory_filter_setstate_transform.mjs',
  'tool/verify_dispatch_directory_filter_setstate_candidate.mjs',
  'tool/apply_dispatch_directory_filter_setstate_fix.mjs',
  'tool/templates/dispatch_directory_filter_setstate_candidate_widget_test.dart.txt',
  'test/dispatch_directory_filter_setstate_void_contract_test.dart',
  'test/dispatch_directory_seed_safe_repository_contract_test.dart',
  'test/dispatch_directory_dropdown_layout_contract_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'docs/repairs/DISPATCH_DIRECTORY_SETSTATE_FUTURE_CALLBACK.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not synchronize Directory setState repair bundle.' }
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not unstage Directory setState repair bundle.' }

Write-Step 'Parsing every focused control before production mutation'
$nodeControls = @(
  'tool/dispatch_directory_filter_setstate_transform.mjs',
  'tool/verify_dispatch_directory_filter_setstate_candidate.mjs',
  'tool/apply_dispatch_directory_filter_setstate_fix.mjs'
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
  throw "STOP: Directory setState repair PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Focused control parse: PASS' -ForegroundColor Green

Write-Step 'Formatting synchronized support tests only'
$testFiles = @(
  '.\test\dispatch_directory_filter_setstate_void_contract_test.dart',
  '.\test\dispatch_directory_seed_safe_repository_contract_test.dart',
  '.\test\dispatch_directory_dropdown_layout_contract_test.dart',
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart',
  '.\test\marketplace_dispatch_directory_test.dart',
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
)
& dart format $testFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not normalize synchronized Directory support tests.' }

$candidateRelative = 'lib/marketplace/pipebuyer_directory_filter_setstate_preflight.dart'
$candidatePath = Join-Path $repoRoot 'lib\marketplace\pipebuyer_directory_filter_setstate_preflight.dart'
$tempTestPath = Join-Path $repoRoot 'test\pipebuyer_directory_filter_setstate_candidate_widget_test.dart'
$templatePath = Join-Path $repoRoot 'tool\templates\dispatch_directory_filter_setstate_candidate_widget_test.dart.txt'
try {
  Write-Step 'Building exact local void-safe setState candidate before production mutation'
  $env:PIPEBUYER_DIRECTORY_SETSTATE_CANDIDATE = $candidateRelative
  & node '.\tool\verify_dispatch_directory_filter_setstate_candidate.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Directory setState candidate transformation failed. Production source was not changed.'
  }
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw 'STOP: Directory setState candidate was not created.'
  }

  & dart format $candidatePath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Formatter rejected Directory setState candidate.' }
  & flutter analyze --fatal-infos --fatal-warnings $candidatePath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Analyzer rejected Directory setState candidate.' }

  Copy-Item -LiteralPath $templatePath -Destination $tempTestPath -Force
  & dart format $tempTestPath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not format Directory setState candidate runtime test.' }

  Write-Step 'Running candidate Hotshot/debounce runtime proof before production mutation'
  & flutter test $tempTestPath --reporter expanded
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Directory setState candidate still fails interactive filter runtime proof. Production source was not changed.'
  }

  $directoryHashAfterCandidate = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
  if ($directoryHashAfterCandidate -ne $directoryHashBefore) {
    throw 'STOP: Candidate preflight modified production Directory source.'
  }
  Write-Host 'Exact local candidate analyzer + interactive Hotshot/debounce runtime proof: PASS' -ForegroundColor Green
}
finally {
  Remove-Item Env:PIPEBUYER_DIRECTORY_SETSTATE_CANDIDATE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tempTestPath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Applying only the already-proven void-safe setState callback correction'
& node '.\tool\apply_dispatch_directory_filter_setstate_fix.mjs'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Directory setState source repair failed after candidate PASS.' }

Write-Step 'Formatting and analyzing production Directory source before regressions'
& dart format '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Directory formatting failed.' }
& dart format --output=none --set-exit-if-changed '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Directory source is not formatter-stable.' }
& flutter analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Production Directory source does not compile after setState repair.' }
Write-Host 'Production Directory analyzer: PASS' -ForegroundColor Green

Write-Step 'Running the exact previously failing Directory interaction regression first'
& flutter test `
  '.\test\dispatch_directory_filter_setstate_void_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_test.dart' `
  --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory interaction regression still fails after candidate runtime PASS. Do not rerun older source repairs.'
}

Write-Step 'Running seed-safe, layout, retained-runtime and projection regressions'
& flutter test `
  '.\test\dispatch_directory_seed_safe_repository_contract_test.dart' `
  '.\test\dispatch_directory_dropdown_layout_contract_test.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart' `
  --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory sibling regression failed after setState repair.'
}

Write-Step 'Strict analyzer on synchronized regression files'
foreach ($target in $testFiles) {
  & flutter analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) { throw "STOP: Strict analyzer failed for support regression: $target" }
}

$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Directory setState repair modified the Dispatch tracker.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DIRECTORY FILTER SETSTATE REPAIR PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Control parse before mutation: PASS' -ForegroundColor Green
Write-Host 'Exact local candidate analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Candidate Hotshot/debounce runtime before mutation: PASS' -ForegroundColor Green
Write-Host 'Candidate production mutation: NO' -ForegroundColor Green
Write-Host 'Reload setState callback returns void: PASS' -ForegroundColor Green
Write-Host 'Debounced filter setState callback returns void: PASS' -ForegroundColor Green
Write-Host 'Production analyzer before tests: PASS' -ForegroundColor Green
Write-Host 'Previously failing service-filter regression: PASS' -ForegroundColor Green
Write-Host 'Seed-safe/layout/runtime/projection regressions: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by repair: NO' -ForegroundColor Green
Write-Host 'Ready for browser Hotshot re-test: YES' -ForegroundColor Green
