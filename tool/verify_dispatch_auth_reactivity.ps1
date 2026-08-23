$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "Dispatch auth verification requires design/formal-beautification-foundation. Current branch: $branch"
}

$target = Join-Path $repoRoot 'lib\marketplace\marketplace_dispatch_page.dart'
$patcher = Join-Path $repoRoot 'tool\repair_dispatch_auth_reactivity.mjs'
$contract = Join-Path $repoRoot 'test\dispatch_auth_reactivity_contract_test.dart'

foreach ($required in @($target, $patcher, $contract)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Dispatch auth repair file is missing: $required"
  }
}

$backupDir = Join-Path $repoRoot ("_local_backups\dispatch_auth_reactivity_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$targetBackup = Join-Path $backupDir 'marketplace_dispatch_page.dart'
Copy-Item -LiteralPath $target -Destination $targetBackup -Force

try {
  Write-Step 'Checking auth repair syntax before product mutation'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch auth repair syntax check failed.'
  }

  Write-Step 'Applying the narrow Dispatch auth reactivity repair'
  & node $patcher
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch auth reactivity repair failed.'
  }

  Write-Step 'Formatting only the repaired Dispatch page and contract test'
  & dart format `
    '.\lib\marketplace\marketplace_dispatch_page.dart' `
    '.\test\dispatch_auth_reactivity_contract_test.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch auth repair formatting failed.'
  }

  Write-Step 'Running strict analyzer on repaired Dispatch page'
  & dart analyze --fatal-infos --fatal-warnings '.\lib\marketplace\marketplace_dispatch_page.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch auth repair analyzer failed.'
  }

  Write-Step 'Running Dispatch auth reactivity contract'
  & flutter test '.\test\dispatch_auth_reactivity_contract_test.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch auth reactivity contract failed.'
  }

  Write-Step 'Re-running Phase 1 navigation regression'
  & flutter test '.\test\marketplace_dispatch_navigation_test.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch Phase 1 navigation regression failed.'
  }

  Write-Step 'Re-running Phase 2 taxonomy regression'
  & flutter test '.\test\marketplace_dispatch_service_taxonomy_test.dart'
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch Phase 2 taxonomy regression failed.'
  }

  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'DISPATCH AUTH REACTIVITY REPAIR PASSED' -ForegroundColor Green
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'Auth state listener: PASS' -ForegroundColor Green
  Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
  Write-Host 'Auth contract: PASS' -ForegroundColor Green
  Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
  Write-Host 'Phase 2 taxonomy regression: PASS' -ForegroundColor Green
  Write-Host "Backup retained at: $backupDir" -ForegroundColor DarkGray
}
catch {
  Write-Host ''
  Write-Host 'DISPATCH AUTH REPAIR FAILED - RESTORING PRE-RUN PAGE' -ForegroundColor Red
  Copy-Item -LiteralPath $targetBackup -Destination $target -Force
  Write-Host 'marketplace_dispatch_page.dart restored.' -ForegroundColor Yellow
  throw
}
