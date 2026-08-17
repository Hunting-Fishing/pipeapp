$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

$remote = 'origin/design/formal-beautification-foundation'

Write-Host "`n==> Fetching the formal branch without merging" -ForegroundColor Cyan
git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal branch.'
}

# Support files only. Production Dart/Functions source is intentionally excluded.
# Guarded verifiers/fixers remain responsible for modifying source.
$supportFiles = @(
  'tool/fix_service_area_geocoder_classification.ps1',
  'tool/verify_service_area_geocoder_classification.ps1',
  'test/service_area_geocoder_classification_test.dart',
  'docs/repairs/SERVICE_AREA_TOWN_REGION_BOUNDARY_CLASSIFICATION.md',
  'firebase/functions/dispatch_credential_monitor.js',
  'firebase/functions/test/dispatch_credential_monitor.test.js',
  'test/marketplace_dispatch_credential_intelligence_test.dart',
  'tool/templates/marketplace_dispatch_credentials_intelligence.dart.txt',
  'tool/apply_dispatch_credential_intelligence.ps1',
  'tool/verify_dispatch_credential_intelligence.ps1',
  'docs/DISPATCH_PHASE3_CREDENTIAL_INTELLIGENCE.md'
)

Write-Host "`n==> Synchronizing the complete Phase 3 closeout support bundle" -ForegroundColor Cyan
git checkout $remote -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the Phase 3 closeout support bundle.'
}

# Keep fetched support files unstaged until local engineering/browser acceptance is complete.
git reset -q HEAD -- $supportFiles
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the synchronized Phase 3 support files.'
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
  throw "STOP: Phase 3 closeout support bundle is incomplete ($($missing.Count) file(s) missing)."
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH PHASE 3 CLOSEOUT BUNDLE READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Towns/Regions map regression support: READY' -ForegroundColor Green
Write-Host 'Credential intelligence support: READY' -ForegroundColor Green
Write-Host 'Production source overwritten by this sync: NO' -ForegroundColor Green
Write-Host 'Support files staged by this sync: NO' -ForegroundColor Green
Write-Host ''
Write-Host 'Next: run verify_service_area_geocoder_classification.ps1, then verify_dispatch_credential_intelligence.ps1.' -ForegroundColor Yellow
