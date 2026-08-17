# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function FileHash([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$credentialSource = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$credentialTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credentials_test.dart'
$privacyTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credentials_privacy_contract_test.dart'
$intelligenceTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credential_intelligence_test.dart'
$targets = @($credentialSource, $credentialTest, $privacyTest, $intelligenceTest)

foreach ($target in $targets) {
  if (-not (Test-Path -LiteralPath $target)) {
    throw "STOP: Required credential Dart target is missing: $target"
  }
}

$sourceText = Get-Content -LiteralPath $credentialSource -Raw
foreach ($marker in @(
  'final double? coverageLimit;',
  'class DispatchCredentialReminderSettings',
  "text: 'Analytics & alerts'"
)) {
  if (-not $sourceText.Contains($marker)) {
    throw "STOP: Credential intelligence marker is missing before formatting: $marker"
  }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-credential-format-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
foreach ($target in $targets) {
  Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir (Split-Path $target -Leaf))
}

$before = @{}
foreach ($target in $targets) {
  $before[$target] = FileHash $target
}

Write-Host "`n==> Normalizing only the credential Dart source/test format" -ForegroundColor Cyan
& dart format $targets
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Dart formatter failed for the bounded credential target set.'
}

Write-Host "`n==> Proving formatter stability" -ForegroundColor Cyan
& dart format --output=none --set-exit-if-changed $targets
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential Dart files are still not formatter stable after normalization.'
}

$changed = @()
foreach ($target in $targets) {
  if ((FileHash $target) -ne $before[$target]) {
    $changed += $target
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL DART FORMAT READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
if ($changed.Count -eq 0) {
  Write-Host 'Formatter changes required: NO' -ForegroundColor Green
} else {
  Write-Host "Formatter changes required: YES ($($changed.Count) bounded file(s))" -ForegroundColor Green
  foreach ($path in $changed) {
    Write-Host "  - $path" -ForegroundColor DarkGray
  }
}
Write-Host "Backup created: $backupDir" -ForegroundColor DarkGray
Write-Host 'Production files outside credential target set changed: NO' -ForegroundColor Green
Write-Host 'Dispatch tracker modified: NO' -ForegroundColor Green
