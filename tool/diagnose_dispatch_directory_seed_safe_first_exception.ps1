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
Write-Step 'Synchronizing read-only seed-safe diagnostic controls'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not fetch Directory diagnostic controls.' }

$supportFiles = @(
  'tool/dispatch_directory_seed_safe_repository_transform.mjs',
  'tool/verify_dispatch_directory_seed_safe_repository_candidate.mjs',
  'tool/templates/dispatch_directory_seed_safe_first_exception_test.dart.txt'
)
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not synchronize Directory diagnostic bundle.' }
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) { throw 'STOP: Could not unstage Directory diagnostic bundle.' }

Write-Step 'Parsing diagnostic controls before any candidate work'
& node --check '.\tool\dispatch_directory_seed_safe_repository_transform.mjs'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Seed-safe transform parse failed.' }
& node --check '.\tool\verify_dispatch_directory_seed_safe_repository_candidate.mjs'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Seed-safe candidate verifier parse failed.' }
$parseErrors = $null
$parseTokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$parseTokens,
  [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
  throw "STOP: Diagnostic PowerShell parse failed: $($parseErrors[0].Message)"
}
Write-Host 'Diagnostic control parse: PASS' -ForegroundColor Green

$candidateRelative = 'lib/marketplace/pipebuyer_directory_seed_safe_preflight.dart'
$candidatePath = Join-Path $repoRoot 'lib\marketplace\pipebuyer_directory_seed_safe_preflight.dart'
$tempTestPath = Join-Path $repoRoot 'test\pipebuyer_directory_seed_safe_first_exception_test.dart'
$templatePath = Join-Path $repoRoot 'tool\templates\dispatch_directory_seed_safe_first_exception_test.dart.txt'
$diagnosticDir = Join-Path $repoRoot '_local_diagnostics'
New-Item -ItemType Directory -Force -Path $diagnosticDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $diagnosticDir "dispatch-directory-seed-safe-first-exception-$stamp.txt"

try {
  Write-Step 'Building exact local seed-safe candidate READ-ONLY'
  $env:PIPEBUYER_DIRECTORY_SEED_SAFE_CANDIDATE = $candidateRelative
  & node '.\tool\verify_dispatch_directory_seed_safe_repository_candidate.mjs'
  if ($LASTEXITCODE -ne 0) {
    throw 'STOP: Candidate transformation failed. Production source was not changed.'
  }
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw 'STOP: Diagnostic candidate was not created.'
  }

  & dart format $candidatePath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Candidate formatter failed.' }
  & flutter analyze --fatal-infos --fatal-warnings $candidatePath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Candidate analyzer failed.' }

  Copy-Item -LiteralPath $templatePath -Destination $tempTestPath -Force
  & dart format $tempTestPath
  if ($LASTEXITCODE -ne 0) { throw 'STOP: Diagnostic test formatter failed.' }

  Write-Step 'Capturing the FIRST seeded-widget runtime exception only'
  $output = & flutter test $tempTestPath --reporter expanded 2>&1
  $exitCode = $LASTEXITCODE
  $output | Tee-Object -FilePath $logPath

  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Yellow
  Write-Host 'PIPE BUYER DIRECTORY FIRST-EXCEPTION DIAGNOSTIC' -ForegroundColor Yellow
  Write-Host '============================================================' -ForegroundColor Yellow
  $markers = $output | Select-String 'PIPEBUYER_FIRST_EXCEPTION_(PHASE|CLASS|TYPE|BEGIN|END)|PIPEBUYER_FIRST_EXCEPTION_CLASS=NONE'
  if ($markers) {
    $markers | ForEach-Object { Write-Host $_.Line -ForegroundColor Yellow }
  } else {
    Write-Host 'No explicit first-exception marker was emitted; use the saved diagnostic log.' -ForegroundColor Yellow
  }
  Write-Host "Diagnostic log: $logPath" -ForegroundColor Yellow
  Write-Host 'Production Directory source modified by diagnostic: NO' -ForegroundColor Green
  Write-Host 'Dispatch tracker modified by diagnostic: NO' -ForegroundColor Green

  if ($exitCode -eq 0) {
    Write-Host 'Seed-safe diagnostic runtime: PASS' -ForegroundColor Green
  } else {
    throw 'STOP: First runtime exception captured. Repair only the classified failing layer; do not rerun prior mutations.'
  }
}
finally {
  Remove-Item Env:PIPEBUYER_DIRECTORY_SEED_SAFE_CANDIDATE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tempTestPath -Force -ErrorAction SilentlyContinue

  $directoryHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $directoryPath).Hash
  $trackerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackerPath).Hash
  if ($directoryHashAfter -ne $directoryHashBefore) {
    Write-Error 'STOP: Diagnostic changed production Directory source.'
  }
  if ($trackerHashAfter -ne $trackerHashBefore) {
    Write-Error 'STOP: Diagnostic changed the Dispatch tracker.'
  }
}
