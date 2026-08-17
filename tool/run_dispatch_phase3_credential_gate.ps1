$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

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

$doctor = Join-Path $PSScriptRoot 'pipebuyer_doctor.ps1'
$updateReminder = Join-Path $PSScriptRoot 'update_dispatch_credential_reminder_engine.ps1'
$normalizeDart = Join-Path $PSScriptRoot 'normalize_dispatch_credential_dart_format.ps1'
$verify = Join-Path $PSScriptRoot 'verify_dispatch_credential_intelligence.ps1'

foreach ($required in @($doctor, $updateReminder, $normalizeDart, $verify)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required Dispatch credential gate control is missing: $required"
  }
}

Write-Host ''
Write-Host 'PIPE BUYER DISPATCH CREDENTIAL GATE' -ForegroundColor White
Write-Host 'This gate never edits the Dispatch progress tracker.' -ForegroundColor DarkGray
Write-Host 'It may update only the one recognized broken reminder-engine revision.' -ForegroundColor DarkGray
Write-Host 'It may normalize Dart formatting only in the declared credential source/test set.' -ForegroundColor DarkGray
Write-Host 'Verification after those bounded normalizers is source-read-only.' -ForegroundColor DarkGray

Run-CheckedPowerShell $doctor 'Running Pipe Buyer environment Doctor'
Run-CheckedPowerShell $updateReminder 'Normalizing the known credential reminder engine revision'
Run-CheckedPowerShell $normalizeDart 'Normalizing bounded credential Dart formatting'
Run-CheckedPowerShell $verify 'Running the source-read-only credential engineering verifier'

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DISPATCH CREDENTIAL GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Environment Doctor: PASS' -ForegroundColor Green
Write-Host 'Credential reminder engine: PASS' -ForegroundColor Green
Write-Host 'Credential Dart format: PASS' -ForegroundColor Green
Write-Host 'Credential engineering verifier: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified by gate: NO' -ForegroundColor Green
Write-Host 'Ready for browser acceptance: YES' -ForegroundColor Green
