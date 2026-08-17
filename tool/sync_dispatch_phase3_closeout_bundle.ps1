$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

$remote = 'origin/design/formal-beautification-foundation'

Write-Host "`n==> Fetching the formal branch without merging" -ForegroundColor Cyan
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal branch.'
}

# Support/control files only. Production Dart/Functions source and the Dispatch
# progress tracker are intentionally excluded from this synchronization step.
$supportFiles = @(
  'tool/fix_service_area_geocoder_classification.ps1',
  'tool/verify_service_area_geocoder_classification.ps1',
  'test/service_area_geocoder_classification_test.dart',
  'docs/repairs/SERVICE_AREA_TOWN_REGION_BOUNDARY_CLASSIFICATION.md',
  'firebase/functions/test/dispatch_credential_monitor.test.js',
  'test/marketplace_dispatch_credential_intelligence_test.dart',
  'tool/templates/marketplace_dispatch_credentials_intelligence.dart.txt',
  'tool/apply_dispatch_credential_intelligence.ps1',
  'tool/update_dispatch_credential_reminder_engine.ps1',
  'tool/verify_dispatch_credential_intelligence.ps1',
  'tool/run_dispatch_phase3_credential_gate.ps1',
  'docs/DISPATCH_PHASE3_CREDENTIAL_INTELLIGENCE.md',
  'docs/repairs/DISPATCH_CREDENTIAL_REMINDER_NEXT_DUE.md'
)

Write-Host "`n==> Synchronizing the complete Phase 3 support/control bundle" -ForegroundColor Cyan
& git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Phase 3 support/control bundle.'
}

& git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the synchronized Phase 3 support/control files.'
}

$missing = @()
foreach ($relative in $supportFiles) {
  $absolute = Join-Path $script:PipeBuyerRepoRoot ($relative.Replace('/', '\'))
  if (-not (Test-Path -LiteralPath $absolute)) {
    $missing += $relative
  }
}

if ($missing.Count -gt 0) {
  Write-Host "`nMissing support files:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  throw "STOP: Phase 3 support/control bundle is incomplete ($($missing.Count) file(s) missing)."
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH PHASE 3 CONTROL BUNDLE READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Towns/Regions regression support: READY' -ForegroundColor Green
Write-Host 'Credential intelligence tests: READY' -ForegroundColor Green
Write-Host 'Known reminder-engine updater: READY' -ForegroundColor Green
Write-Host 'Credential verifier: SOURCE-READ-ONLY' -ForegroundColor Green
Write-Host 'Production Dart/Functions overwritten by sync: NO' -ForegroundColor Green
Write-Host 'Dispatch tracker touched by sync: NO' -ForegroundColor Green
Write-Host 'Support files staged by sync: NO' -ForegroundColor Green
Write-Host ''
Write-Host 'Next command: .\tool\run_dispatch_phase3_credential_gate.ps1' -ForegroundColor Yellow
