# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "STOP: Wrong branch. Expected design/formal-beautification-foundation, found $branch"
}

$remote = 'origin/design/formal-beautification-foundation'
Write-Host "`n==> Fetching formal controls without merging" -ForegroundColor Cyan
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal branch.'
}

$supportFiles = @(
  'tool/pipebuyer_context.ps1',
  'tool/pipebuyer_doctor.ps1',
  'tool/apply_dispatch_credential_intelligence.ps1',
  'tool/apply_dispatch_credential_acceptance_v2.ps1',
  'tool/apply_administrator_role_management.ps1',
  'tool/update_dispatch_credential_reminder_engine.ps1',
  'tool/normalize_dispatch_credential_dart_format.ps1',
  'tool/verify_dispatch_credential_intelligence.ps1',
  'tool/run_dispatch_phase3_credential_gate.ps1',
  'tool/templates/marketplace_dispatch_credentials_intelligence.dart.txt',
  'test/marketplace_dispatch_credential_intelligence_test.dart',
  'test/marketplace_dispatch_credential_persistence_discoverability_test.dart',
  'test/dispatch_credential_migration_idempotency_contract_test.dart',
  'test/marketplace_admin_role_management_contract_test.dart',
  'firebase/functions/test/dispatch_credential_monitor.test.js',
  'firebase/functions/test/administrator_role_commands.test.js',
  'docs/ADMIN_ROLE_PROVISIONING.md'
)

Write-Host "`n==> Synchronizing declared Phase 3 support/test controls" -ForegroundColor Cyan
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Phase 3 support bundle.'
}
& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the synchronized support bundle.'
}

Write-Host "`n==> Parsing every declared Phase 3 PowerShell control before any production edit" -ForegroundColor Cyan
$phasePowerShellControls = @(
  'tool\pipebuyer_context.ps1',
  'tool\pipebuyer_doctor.ps1',
  'tool\apply_dispatch_credential_intelligence.ps1',
  'tool\apply_dispatch_credential_acceptance_v2.ps1',
  'tool\apply_administrator_role_management.ps1',
  'tool\update_dispatch_credential_reminder_engine.ps1',
  'tool\normalize_dispatch_credential_dart_format.ps1',
  'tool\verify_dispatch_credential_intelligence.ps1',
  'tool\run_dispatch_phase3_credential_gate.ps1'
)
foreach ($relative in $phasePowerShellControls) {
  $target = Join-Path $repoRoot $relative
  if (-not (Test-Path -LiteralPath $target)) {
    throw "STOP: Declared Phase 3 PowerShell control is missing: $relative"
  }
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $target,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors.Count -gt 0) {
    $details = ($parseErrors | ForEach-Object {
      "line $($_.Extent.StartLineNumber): $($_.Message)"
    }) -join '; '
    throw "STOP: PowerShell parse preflight failed for $relative - $details"
  }
}
Write-Host 'Declared Phase 3 PowerShell parse preflight: PASS' -ForegroundColor Green

Write-Host "`n==> Preflighting credential migration idempotency before any production edit" -ForegroundColor Cyan
& flutter test '.\test\dispatch_credential_migration_idempotency_contract_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential migration idempotency contract failed before production edits.'
}

$newProductionFiles = @(
  @{
    Path = 'firebase/functions/administrator_role_commands.js'
    Marker = 'PRIMARY_ADMIN_MANAGER_EMAIL'
  },
  @{
    Path = 'lib/marketplace/marketplace_admin_role_manager.dart'
    Marker = 'class MarketplaceAdminRoleManager'
  }
)
foreach ($item in $newProductionFiles) {
  $absolute = Join-Path $repoRoot ($item.Path.Replace('/', '\'))
  if (-not (Test-Path -LiteralPath $absolute)) {
    & git checkout $remote -- $item.Path
    if ($LASTEXITCODE -ne 0) {
      throw "STOP: Could not install new production file $($item.Path)."
    }
    & git reset -q HEAD -- $item.Path
    Write-Host "Installed new bounded production module: $($item.Path)" -ForegroundColor Green
    continue
  }
  $text = Get-Content -LiteralPath $absolute -Raw
  if (-not $text.Contains($item.Marker)) {
    throw "STOP: Existing $($item.Path) is not the recognized Pipe Buyer module. It was not overwritten."
  }
  Write-Host "Recognized existing bounded production module: $($item.Path)" -ForegroundColor DarkGray
}

function Run-CheckedPowerShell {
  param(
    [Parameter(Mandatory = $true)][string]$Script,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Write-Host "`n==> $Label" -ForegroundColor Cyan
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Script
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: $Label failed. Do not continue to later stages."
  }
}

Run-CheckedPowerShell '.\tool\pipebuyer_doctor.ps1' 'Running scoped Pipe Buyer Doctor'
Run-CheckedPowerShell '.\tool\apply_dispatch_credential_acceptance_v2.ps1' 'Applying credential persistence and analytics acceptance repair'
Run-CheckedPowerShell '.\tool\apply_administrator_role_management.ps1' 'Applying protected administrator roster management'
Run-CheckedPowerShell '.\tool\run_dispatch_phase3_credential_gate.ps1' 'Running complete credential engineering gate'

Write-Host "`n==> Running immediate-save and analytics discoverability contract" -ForegroundColor Cyan
& flutter test '.\test\marketplace_dispatch_credential_persistence_discoverability_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential persistence/discoverability contract failed.'
}

Write-Host "`n==> Re-running administrator role command contract" -ForegroundColor Cyan
& node --test '.\firebase\functions\test\administrator_role_commands.test.js'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Administrator role command contract failed.'
}

Write-Host "`n==> Running administrator UI authorization-boundary contract" -ForegroundColor Cyan
& flutter test '.\test\marketplace_admin_role_management_contract_test.dart'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Administrator UI authorization-boundary contract failed.'
}

Write-Host "`n==> Final strict analyzer on the bounded acceptance UI" -ForegroundColor Cyan
foreach ($target in @(
  '.\lib\marketplace\marketplace_dispatch_credentials.dart',
  '.\lib\marketplace\marketplace_admin_role_manager.dart',
  '.\test\marketplace_dispatch_credential_persistence_discoverability_test.dart',
  '.\test\dispatch_credential_migration_idempotency_contract_test.dart',
  '.\test\marketplace_admin_role_management_contract_test.dart'
)) {
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Strict analyzer failed for $target"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH PHASE 3 ACCEPTANCE REPAIR PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Declared PowerShell controls parse before mutation: PASS' -ForegroundColor Green
Write-Host 'Credential migration formatter/idempotency preflight: PASS' -ForegroundColor Green
Write-Host 'Credential dialog immediate persistence: PASS' -ForegroundColor Green
Write-Host 'Insurance coverage fields: PASS' -ForegroundColor Green
Write-Host 'Analytics & alerts discoverability: PASS' -ForegroundColor Green
Write-Host 'Credential reminder engine: PASS' -ForegroundColor Green
Write-Host 'Private credential boundary: PASS' -ForegroundColor Green
Write-Host 'Primary-admin roster management: PASS' -ForegroundColor Green
Write-Host 'Generic profile role cannot grant Administrator claims: PASS' -ForegroundColor Green
Write-Host 'Flutter admin UI contains no administrator email allowlist: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by this gate: NO' -ForegroundColor Green
Write-Host 'Ready for browser acceptance: YES' -ForegroundColor Green
