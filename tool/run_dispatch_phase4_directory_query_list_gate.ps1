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
if (-not (Test-Path -LiteralPath $trackerPath)) {
  throw 'STOP: Dispatch master plan is missing.'
}
$trackerHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash

$remote = 'origin/design/formal-beautification-foundation'
Write-Step 'Fetching current Phase 4 Directory controls without merging'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal Phase 4 Directory controls.'
}

$supportFiles = @(
  'tool/apply_dispatch_phase4_directory_query_ui.mjs',
  'tool/dispatch_directory_filter_runtime_transform.mjs',
  'tool/apply_dispatch_phase4_directory_filter_stability.mjs',
  'firebase/functions/scripts/seed_dispatch_directory_visual.js',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'test/dispatch_directory_projection_source_contract_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
  'firebase/functions/test/dispatch_directory_projection.test.js',
  'firebase/functions/test/dispatch_directory_security_contract.test.js',
  'docs/DISPATCH_PHASE4_DIRECTORY_QUERY_LIST.md',
  'docs/repairs/DISPATCH_DIRECTORY_FILTER_RUNTIME_STABILITY.md'
)

Write-Step 'Synchronizing the declared Phase 4 query/list support bundle'
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Phase 4 query/list support bundle.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the Phase 4 query/list support bundle.'
}

$directorySource = 'lib/marketplace/marketplace_dispatch_directory.dart'
$directoryPath = Join-Path $repoRoot ($directorySource.Replace('/', '\'))
if (-not (Test-Path -LiteralPath $directoryPath)) {
  Write-Step 'Installing the reviewed Directory list candidate because it is not present locally'
  & git checkout $remote -- $directorySource
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Could not install $directorySource"
  }
  & git reset -q HEAD -- $directorySource
  Write-Host 'Reviewed Directory list candidate installed.' -ForegroundColor Green
} else {
  $directoryText = Get-Content -LiteralPath $directoryPath -Raw
  $recognized = $directoryText.Contains('class MarketplaceDispatchDirectoryPage') -and (
    $directoryText.Contains("_firestore.collection('public_business_profiles')") -or
    $directoryText.Contains("_firestore.collection('dispatch_directory_entries')")
  )
  if (-not $recognized) {
    throw "STOP: Existing $directorySource is not a recognized Pipe Buyer Directory candidate. It was not overwritten."
  }
  Write-Host 'Recognized existing Directory list source.' -ForegroundColor DarkGray
}

$requiredLocalFiles = @(
  'lib/marketplace/marketplace_dispatch_navigation.dart',
  'tool/start_formal_acceptance_environment.ps1',
  'firebase/functions/dispatch_directory_projection.js'
)
foreach ($file in $requiredLocalFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot ($file.Replace('/', '\'))))) {
    throw "STOP: Required previously accepted Phase 4 file is missing: $file"
  }
}

Write-Step 'Preflighting every declared control before mutation'
$nodeControls = @(
  'tool/apply_dispatch_phase4_directory_query_ui.mjs',
  'tool/dispatch_directory_filter_runtime_transform.mjs',
  'tool/apply_dispatch_phase4_directory_filter_stability.mjs',
  'firebase/functions/scripts/seed_dispatch_directory_visual.js',
  'firebase/functions/dispatch_directory_projection.js',
  'firebase/functions/test/dispatch_directory_projection.test.js',
  'firebase/functions/test/dispatch_directory_security_contract.test.js'
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
  throw "STOP: Phase 4 query/list gate PowerShell parse failed: $($parseErrors[0].Message)"
}

$navigationText = Get-Content -LiteralPath '.\lib\marketplace\marketplace_dispatch_navigation.dart' -Raw
$foundationMarker = 'class MarketplaceDispatchDirectoryFoundation extends StatelessWidget {'
$foundationIndex = $navigationText.IndexOf($foundationMarker)
if ($foundationIndex -lt 0) {
  throw 'STOP: Directory foundation class was not found before mutation.'
}
$foundationSuffix = $navigationText.Substring($foundationIndex + $foundationMarker.Length)
if (-not $navigationText.Contains('MarketplaceDispatchDirectoryPage(')) {
  $laterClasses = [regex]::Matches($foundationSuffix, '(?m)^class\s+')
  if ($laterClasses.Count -gt 0) {
    throw 'STOP: Directory foundation is no longer the final navigation class. The integrator will not truncate later source.'
  }
}
Write-Host 'Declared Phase 4 query/list control preflight: PASS' -ForegroundColor Green

Write-Step 'Applying the atomic Directory repository + provider-list integration'
& node '.\tool\apply_dispatch_phase4_directory_query_ui.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Phase 4 Directory query/list integration failed.'
}

Write-Step 'Applying the permanent non-blank filter refresh lifecycle'
& node '.\tool\apply_dispatch_phase4_directory_filter_stability.mjs'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Phase 4 Directory filter runtime stability integration failed.'
}

Write-Step 'Formatting only the touched Directory Dart source and tests'
$dartFiles = @(
  'lib/marketplace/marketplace_dispatch_directory.dart',
  'lib/marketplace/marketplace_dispatch_navigation.dart',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'test/dispatch_directory_projection_source_contract_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart'
)
& dart format $dartFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Dart formatter failed on the bounded Phase 4 query/list files.'
}
& dart format --output=none --set-exit-if-changed $dartFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Phase 4 query/list Dart files are not formatter-stable.'
}

Write-Step 'Parsing the patched formal acceptance launcher'
$launcherErrors = $null
$launcherTokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path '.\tool\start_formal_acceptance_environment.ps1').Path,
  [ref]$launcherTokens,
  [ref]$launcherErrors
) | Out-Null
if ($launcherErrors.Count -gt 0) {
  throw "STOP: Formal acceptance launcher parse failed after Directory seed wiring: $($launcherErrors[0].Message)"
}
Write-Host 'Formal acceptance launcher parse: PASS' -ForegroundColor Green

Write-Step 'Running Directory projection/query/widget/runtime contracts'
& flutter test `
  '.\test\marketplace_dispatch_directory_test.dart' `
  '.\test\marketplace_dispatch_directory_projection_query_test.dart' `
  '.\test\dispatch_directory_projection_source_contract_test.dart' `
  '.\test\dispatch_directory_filter_runtime_stability_contract_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Phase 4 Directory Flutter contracts failed.'
}

Write-Step 'Re-running server projection and privacy contracts'
& node --test `
  '.\firebase\functions\test\dispatch_directory_projection.test.js' `
  '.\firebase\functions\test\dispatch_directory_security_contract.test.js'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Phase 4 server Directory projection/privacy regressions failed.'
}

Write-Step 'Running strict analyzer on the bounded Directory integration'
$analyzeFiles = @(
  'lib/marketplace/marketplace_dispatch_directory.dart',
  'lib/marketplace/marketplace_dispatch_navigation.dart',
  'test/marketplace_dispatch_directory_test.dart',
  'test/marketplace_dispatch_directory_projection_query_test.dart',
  'test/dispatch_directory_projection_source_contract_test.dart',
  'test/dispatch_directory_filter_runtime_stability_contract_test.dart'
)
foreach ($target in $analyzeFiles) {
  & flutter analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Strict analyzer failed for $target"
  }
}

$trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
if ($trackerHashAfter -ne $trackerHashBefore) {
  throw 'STOP: Phase 4 query/list engineering gate modified the Dispatch tracker. Browser acceptance must remain separate.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH PHASE 4 DIRECTORY QUERY + LIST GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Control parse before mutation: PASS' -ForegroundColor Green
Write-Host 'Server-owned Directory repository/query layer: PASS' -ForegroundColor Green
Write-Host 'Service filter wiring: PASS' -ForegroundColor Green
Write-Host 'Availability/business/capability filters: PASS' -ForegroundColor Green
Write-Host 'Real provider list cards: PASS' -ForegroundColor Green
Write-Host 'Loading/error/empty states: PASS' -ForegroundColor Green
Write-Host 'Filter refresh retains usable results: PASS' -ForegroundColor Green
Write-Host 'Rapid filter/search refresh debounce: PASS' -ForegroundColor Green
Write-Host 'Deterministic six-provider Directory fixture: PASS' -ForegroundColor Green
Write-Host 'Server projection/privacy regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by this gate: NO' -ForegroundColor Green
Write-Host 'Ready for browser acceptance: YES' -ForegroundColor Green
Write-Host 'Next after acceptance: geography/radius + synchronized OpenStreetMap pins' -ForegroundColor Green
