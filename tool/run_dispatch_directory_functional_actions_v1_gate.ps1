$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Hash-File([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "Missing required file: $Path" }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This gate is for design/formal-beautification-foundation. Current branch: $branch"
}

$remote = 'origin/design/formal-beautification-foundation'
$directory = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_directory.dart'
$actionsRepo = Join-Path $repoRoot 'lib\marketplace\marketplace_actions_repository.dart'
$communication = Join-Path $repoRoot 'firebase\functions\communication_commands.js'
$functionsIndex = Join-Path $repoRoot 'firebase\functions\index.js'
$tracker = Join-Path $repoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$transform = Join-Path $repoRoot 'tool\apply_dispatch_directory_functional_actions_v1.mjs'
$contract = Join-Path $repoRoot 'test\dispatch_directory_functional_actions_contract_test.dart'
$businessActions = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_directory_actions.dart'
$reputationBadge = Join-Path $repoRoot 'lib\marketplace\marketplace_reputation_badge.dart'

Write-Step 'Synchronizing only the new Directory functional-actions support bundle'
git fetch origin design/formal-beautification-foundation | Out-Host
$support = @(
  'tool/apply_dispatch_directory_functional_actions_v1.mjs',
  'test/dispatch_directory_functional_actions_contract_test.dart',
  'lib/marketplace/marketplace_dispatch_directory_actions.dart',
  'lib/marketplace/marketplace_reputation_badge.dart',
  'docs/DISPATCH_DIRECTORY_FUNCTIONAL_ACTIONS_AND_REPUTATION.md'
)
git checkout $remote -- $support
git reset -q HEAD -- $support

Write-Step 'Recording production and Dispatch tracker fingerprints'
$before = @{
  directory = Hash-File $directory
  actionsRepo = Hash-File $actionsRepo
  communication = Hash-File $communication
  functionsIndex = Hash-File $functionsIndex
  tracker = Hash-File $tracker
}

Write-Step 'Parsing the deterministic transform before candidate construction'
node --check $transform
if ($LASTEXITCODE -ne 0) { throw 'STOP: Directory functional-actions transform does not parse.' }

Write-Step 'Dry-running the exact local source without mutation'
node $transform
if ($LASTEXITCODE -ne 0) { throw 'STOP: Exact local Directory functional-actions dry-run failed.' }
if ((Hash-File $directory) -ne $before.directory -or
    (Hash-File $actionsRepo) -ne $before.actionsRepo -or
    (Hash-File $communication) -ne $before.communication -or
    (Hash-File $functionsIndex) -ne $before.functionsIndex) {
  throw 'STOP: Dry-run changed production source.'
}
Write-Host 'Exact local dry-run production mutation: NO' -ForegroundColor Green

Write-Step 'Building a complete temporary candidate graph before production mutation'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$preflight = Join-Path $repoRoot "_local_preflight\dispatch-directory-actions-$stamp"
New-Item -ItemType Directory -Force -Path $preflight | Out-Null
Copy-Item -Recurse -Force (Join-Path $repoRoot 'lib') (Join-Path $preflight 'lib')
New-Item -ItemType Directory -Force -Path (Join-Path $preflight 'firebase') | Out-Null
Copy-Item -Recurse -Force (Join-Path $repoRoot 'firebase\functions') (Join-Path $preflight 'firebase\functions')

$env:PIPEBUYER_ROOT = $preflight
try {
  node $transform --apply
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Candidate transform failed.' }
} finally {
  Remove-Item Env:PIPEBUYER_ROOT -ErrorAction SilentlyContinue
}

$candidateDirectory = Join-Path $preflight 'lib\marketplace\marketplace_dispatch_directory.dart'
$candidateActionsRepo = Join-Path $preflight 'lib\marketplace\marketplace_actions_repository.dart'
$candidateBusinessActions = Join-Path $preflight 'lib\marketplace\marketplace_dispatch_directory_actions.dart'
$candidateReputationBadge = Join-Path $preflight 'lib\marketplace\marketplace_reputation_badge.dart'
$candidateCommunication = Join-Path $preflight 'firebase\functions\communication_commands.js'
$candidateIndex = Join-Path $preflight 'firebase\functions\index.js'

Write-Step 'Formatting and strictly analyzing the exact candidate graph'
dart format $candidateDirectory $candidateActionsRepo $candidateBusinessActions $candidateReputationBadge | Out-Host
flutter analyze --fatal-infos --fatal-warnings `
  $candidateDirectory `
  $candidateActionsRepo `
  $candidateBusinessActions `
  $candidateReputationBadge
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Candidate Directory functional-actions Dart graph does not compile. Production source was not changed.'
}
node --check $candidateCommunication
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Candidate business messaging command does not parse. Production source was not changed.'
}
node --check $candidateIndex
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Candidate Functions index does not parse. Production source was not changed.'
}
Write-Host 'Exact local candidate analyzer before mutation: PASS' -ForegroundColor Green
Write-Host 'Candidate Functions syntax before mutation: PASS' -ForegroundColor Green

if ((Hash-File $directory) -ne $before.directory -or
    (Hash-File $actionsRepo) -ne $before.actionsRepo -or
    (Hash-File $communication) -ne $before.communication -or
    (Hash-File $functionsIndex) -ne $before.functionsIndex) {
  throw 'STOP: Candidate construction changed production source.'
}
Write-Host 'Candidate production mutation: NO' -ForegroundColor Green

Write-Step 'Backing up the four production files that may now change'
$backup = Join-Path $repoRoot "_local_backups\dispatch-directory-functional-actions-$stamp"
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Copy-Item -LiteralPath $directory -Destination (Join-Path $backup 'marketplace_dispatch_directory.dart')
Copy-Item -LiteralPath $actionsRepo -Destination (Join-Path $backup 'marketplace_actions_repository.dart')
Copy-Item -LiteralPath $communication -Destination (Join-Path $backup 'communication_commands.js')
Copy-Item -LiteralPath $functionsIndex -Destination (Join-Path $backup 'index.js')

$promoted = $false
try {
  Write-Step 'Applying the candidate-proven functional Directory transform'
  node $transform --apply
  if ($LASTEXITCODE -ne 0) { throw 'Production transform failed.' }
  $promoted = $true

  Write-Step 'Formatting and analyzing production before regressions'
  dart format $directory $actionsRepo $businessActions $reputationBadge | Out-Host
  flutter analyze --fatal-infos --fatal-warnings `
    $directory `
    $actionsRepo `
    $businessActions `
    $reputationBadge
  if ($LASTEXITCODE -ne 0) { throw 'Production Directory actions analyzer failed.' }
  node --check $communication
  if ($LASTEXITCODE -ne 0) { throw 'Production communication command syntax failed.' }
  node --check $functionsIndex
  if ($LASTEXITCODE -ne 0) { throw 'Production Functions index syntax failed.' }

  Write-Step 'Running the functional Directory + dual-ring reputation contract'
  flutter test $contract
  if ($LASTEXITCODE -ne 0) { throw 'Directory functional-actions contract failed.' }

  if ((Hash-File $tracker) -ne $before.tracker) {
    throw 'Dispatch master tracker changed during engineering gate.'
  }
} catch {
  if ($promoted) {
    Write-Host ''
    Write-Host 'Directory functional-actions post-promotion gate failed.' -ForegroundColor Red
    Write-Host 'Restoring the four pre-existing production files...' -ForegroundColor Yellow
    Copy-Item -Force (Join-Path $backup 'marketplace_dispatch_directory.dart') $directory
    Copy-Item -Force (Join-Path $backup 'marketplace_actions_repository.dart') $actionsRepo
    Copy-Item -Force (Join-Path $backup 'communication_commands.js') $communication
    Copy-Item -Force (Join-Path $backup 'index.js') $functionsIndex
    Write-Host 'Directory functional-actions production rollback: COMPLETE' -ForegroundColor Green
  }
  throw
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH DIRECTORY FUNCTIONAL ACTIONS V1 PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Exact local dry-run before mutation: PASS'
Write-Host 'Exact local candidate analyzer before mutation: PASS'
Write-Host 'Candidate production mutation: NO'
Write-Host 'Business-level in-app conversation command: PASS'
Write-Host 'View Business action: PASS'
Write-Host 'Message action: PASS'
Write-Host 'Get Quote private business request: PASS'
Write-Host 'Conditional public Call / Email / Website actions: PASS'
Write-Host 'Report Business action: PASS'
Write-Host 'Dual membership + reputation score rings: PASS'
Write-Host 'Hover tooltip + selectable score legend: PASS'
Write-Host 'New providers avoid fabricated 0/100: PASS'
Write-Host 'Dispatch tracker modified by gate: NO'
Write-Host 'Ready for Directory browser acceptance: YES'
