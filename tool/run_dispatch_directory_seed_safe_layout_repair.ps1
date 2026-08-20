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
Write-Step 'Synchronizing the complete seed-safe + dropdown-layout repair bundle'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal Directory repair controls.'
}

$supportFiles = @(
  'tool/dispatch_directory_seed_safe_repository_transform.mjs',
  'tool/dispatch_directory_dropdown_layout_transform.mjs',
  'tool/verify_dispatch_directory_seed_safe_layout_candidate.mjs',
  'tool/apply_dispatch_directory_seed_safe_layout_fix.mjs',
  'tool/templates/dispatch_directory_seed_safe_layout_candidate_widget_test.dart.txt',
  'test/dispatch_directory_seed_safe_repository_contract_test.dart',
  'test/dispatch_directory_dropdown_layout_contract_test.dart',
  'test/dispatch_directory_widget_test_harness_hygiene_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'test/dispatch_directory_runtime_contract_hygiene_test.dart',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'docs/repairs/DISPATCH_DIRECTORY_SEEDED_REPOSITORY_LIFECYCLE.md',
  'docs/repairs/DISPATCH_DIRECTORY_DROPDOWN_OVERFLOW.md'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the complete Directory repair bundle.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the Directory repair bundle.'
}

Write-Step 'Parsing every focused control before production mutation'
$nodeControls = @(
  'tool/dispatch_directory_seed_safe_repository_transform.mjs',
  'tool/dispatch_directory_dropdown_layout_transform.mjs',
  'tool/verify_dispatch_directory_seed_safe_layout_candidate.mjs',
  'tool/apply_dispatch_directory_seed_safe_layout_fix.mjs'
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
  throw "STOP: Seed-safe/layout repair PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Complete focused control parse: PASS' -ForegroundColor Green

Write-Step 'Formatting synchronized regression/support tests only'
$testFiles = @(
  '.\test\dispatch_directory_seed_safe_repository_contract_test.dart',
  '.\test\dispatch_directory_dropdown_layout_contract_test.dart',
  '.\test\dispatch_directory_widget_test_harness_hygiene_test.dart',
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart',
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart',
  '.\test\marketplace_dispatch_directory_test.dart',
  '.\test\marketplace_dispatch_directory_projection_query_test.dart'
)
& dart format $testFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not normalize synchronized Directory support tests.'
}

Write-Step 'Proving widget-test harness hygiene before source mutation'
& flutter test '.\test\dispatch_directory_widget_test_harness_hygiene_test.dart' --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory widget-test harness hygiene failed before source mutation.'
}
Write-Host 'Directory widget-test harness hygiene: PASS' -ForegroundColor Green

$candidateRelative = 'lib/marketplace/pipebuyer_directory_seed_safe_layout_preflight.dart'
$candidatePath = Join-Path $repoRoot 'lib\marketplace\pipebuyer_directory_seed_safe_layout_preflight.dart'
$tempTestPath = Join-Path $repoRoot 'test\pipebuyer_directory_seed_safe_layout_candidate_widget_test.dart'
$templatePath = Join-Path $repoRoot 'tool\templates\dispatch_directory_seed_safe_layout_candidate_widget_test.dart.txt'
try {
  Write-Step 'Building the exact local combined candidate before production mutation'
  $env:PIPEBUYER_DIRECTORY_SEED_SAFE_LAYOUT_CANDIDATE = $candidateRelative
  & node '.\tool\verify_dispatch_directory_seed_safe_layout_candidate.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Combined Directory candidate transformation failed. Production source was not changed.'
  }
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw 'STOP: Combined Directory candidate was not created.'
  }

  & dart format $candidatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Formatter rejected combined Directory candidate. Production source was not changed.'
  }
  & flutter analyze --fatal-infos --fatal-warnings $candidatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Analyzer rejected combined Directory candidate. Production source was not changed.'
  }

  Copy-Item -LiteralPath $templatePath -Destination $tempTestPath -Force
  & dart format $tempTestPath
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Could not format combined Directory candidate runtime test.'
  }

  Write-Step 'Running candidate runtime proof WITHOUT Firebase and WITHOUT dropdown overflow'
  & flutter test $tempTestPath --reporter expanded
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Combined candidate still fails seeded/responsive widget runtime proof. Production source was not changed.'
  }

  $directoryHashAfterCandidate = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
  if ($directoryHashAfterCandidate -ne $directoryHashBefore) {
    throw 'STOP: Candidate preflight modified production Directory source.'
  }
  Write-Host 'Exact local candidate analyzer + seeded responsive runtime proof: PASS' -ForegroundColor Green
}
finally {
  Remove-Item Env:PIPEBUYER_DIRECTORY_SEED_SAFE_LAYOUT_CANDIDATE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tempTestPath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Applying only the already-proven seed-safe + dropdown-layout correction'
& node '.\tool\apply_dispatch_directory_seed_safe_layout_fix.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Combined Directory source repair failed after candidate runtime PASS.'
}

Write-Step 'Formatting and analyzing production Directory source BEFORE regressions'
& dart format '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory formatting failed.'
}
& dart format --output=none --set-exit-if-changed '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory source is not formatter-stable after repair.'
}
& flutter analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_directory.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Production Directory source does not compile after the proven combined repair.'
}
Write-Host 'Production Directory analyzer: PASS' -ForegroundColor Green

Write-Step 'Running focused seed-safe + responsive-layout regressions first'
& flutter test `
  '.\test\dispatch_directory_seed_safe_repository_contract_test.dart' `
  '.\test\dispatch_directory_dropdown_layout_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_test.dart' `
  --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Focused seed-safe/layout regression failed after candidate runtime PASS. Do not rerun older source repairs.'
}

Write-Step 'Running retained filter-runtime and projection/query regressions'
& flutter test `
  '.\test\dispatch_directory_runtime_contract_hygiene_test.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart' `
  --reporter expanded
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Directory retained-runtime/projection regression failed after combined repair.'
}

Write-Step 'Strict analyzer on synchronized regression files'
foreach ($target in $testFiles) {
  & flutter analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Strict analyzer failed for support regression: $target"
  }
}

$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Combined Directory repair modified the Dispatch tracker.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DIRECTORY SEED-SAFE + LAYOUT REPAIR PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Control parse before mutation: PASS' -ForegroundColor Green
Write-Host 'Widget-test harness hygiene before mutation: PASS' -ForegroundColor Green
Write-Host 'Exact local combined candidate analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Candidate seeded runtime without Firebase: PASS' -ForegroundColor Green
Write-Host 'Candidate responsive dropdown layout at 1400/1000/820 px: PASS' -ForegroundColor Green
Write-Host 'Candidate production mutation: NO' -ForegroundColor Green
Write-Host 'Seeded mode avoids eager Firebase repository: PASS' -ForegroundColor Green
Write-Host 'Service/availability/business dropdown overflow control: PASS' -ForegroundColor Green
Write-Host 'Production analyzer before tests: PASS' -ForegroundColor Green
Write-Host 'Directory widget acceptance regression: PASS' -ForegroundColor Green
Write-Host 'Runtime stability regression preserved: PASS' -ForegroundColor Green
Write-Host 'Projection/query regression preserved: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by repair: NO' -ForegroundColor Green
Write-Host 'Ready for browser Hotshot re-test: YES' -ForegroundColor Green
