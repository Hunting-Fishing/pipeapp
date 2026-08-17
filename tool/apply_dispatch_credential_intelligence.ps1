$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Normalize-Lf([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Replace-ExactlyOnce {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Before,
    [Parameter(Mandatory = $true)][string]$After,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $sourceLf = Normalize-Lf $Source
  $beforeLf = Normalize-Lf $Before
  $afterLf = Normalize-Lf $After

  if ($sourceLf.Contains($afterLf)) {
    Write-Host "Already applied: $Label" -ForegroundColor DarkGray
    return $sourceLf
  }

  $count = ([regex]::Matches($sourceLf, [regex]::Escape($beforeLf))).Count
  if ($count -ne 1) {
    throw "STOP: Expected exactly one source target for '$Label', found $count. No guessing."
  }

  Write-Host "Applying: $Label" -ForegroundColor Green
  return $sourceLf.Replace($beforeLf, $afterLf)
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, (Normalize-Lf $Text), $utf8NoBom)
}

$credentialSource = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$templatePath = Join-Path $script:PipeBuyerRepoRoot 'tool\templates\marketplace_dispatch_credentials_intelligence.dart.txt'
$indexPath = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\index.js'
$notificationPolicyPath = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\notification_delivery_policy.js'

foreach ($required in @($credentialSource, $templatePath, $indexPath, $notificationPolicyPath)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required credential-intelligence file is missing: $required"
  }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-credential-intelligence-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
foreach ($path in @($credentialSource, $indexPath, $notificationPolicyPath)) {
  Copy-Item -LiteralPath $path -Destination (Join-Path $backupDir (Split-Path $path -Leaf))
}
Write-Host "Backup created: $backupDir" -ForegroundColor Green

Write-Host "`n==> Installing the bounded credential records + analytics source" -ForegroundColor Cyan
$currentCredential = Normalize-Lf ([System.IO.File]::ReadAllText($credentialSource))
$templateCredential = Normalize-Lf ([System.IO.File]::ReadAllText($templatePath))

$alreadyIntelligence = $currentCredential.Contains("Tab(icon: Icon(Icons.insights_outlined), text: 'Analytics & alerts')") -and
  $currentCredential.Contains('syncDispatchCredentialReminderSchedule') -and
  $currentCredential.Contains('coverageLimit')

if ($alreadyIntelligence) {
  Write-Host 'Credential intelligence source already installed.' -ForegroundColor DarkGray
}
else {
  foreach ($marker in @(
    'class DispatchCredentialRecord',
    "collection('business_private')",
    'Future<void> _editMetadata(DispatchCredentialRecord record)',
    'Save all credential metadata',
    'Uploading does not mean it is verified.'
  )) {
    if (-not $currentCredential.Contains($marker)) {
      throw "STOP: Credential source no longer matches the known Phase 3 foundation. Missing marker: $marker"
    }
  }
  foreach ($unexpected in @('DispatchCredentialReminderSettings', 'coverageLimit', 'Analytics & alerts')) {
    if ($currentCredential.Contains($unexpected)) {
      throw "STOP: Credential source contains a partial intelligence migration marker '$unexpected'. Inspect it instead of overwriting."
    }
  }
  Write-Utf8NoBom $credentialSource $templateCredential
  Write-Host 'Installed credential coverage, analytics, reminders and matching-readiness source.' -ForegroundColor Green
}

Write-Host "`n==> Formatting the credential Dart source before verification" -ForegroundColor Cyan
& dart format $credentialSource
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential Dart source formatting failed.'
}
& dart format --output=none --set-exit-if-changed $credentialSource
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential Dart source is not formatter stable after migration.'
}
Write-Host 'Credential Dart source formatter stability: PASS' -ForegroundColor Green

Write-Host "`n==> Wiring the scalable credential reminder function" -ForegroundColor Cyan
$index = Normalize-Lf ([System.IO.File]::ReadAllText($indexPath))
$index = Replace-ExactlyOnce $index @'
const { createDispatchCommands } = require("./dispatch_commands");
'@ @'
const { createDispatchCommands } = require("./dispatch_commands");
const {
  createDispatchCredentialMonitor,
} = require("./dispatch_credential_monitor");
'@ 'import credential reminder monitor'

$index = Replace-ExactlyOnce $index @'
const dispatchCommands = createDispatchCommands(admin);
'@ @'
const dispatchCommands = createDispatchCommands(admin);
const dispatchCredentialMonitor = createDispatchCredentialMonitor(admin);
'@ 'instantiate credential reminder monitor'

$index = Replace-ExactlyOnce $index @'
exports.unregisterNotificationEndpoint = onCall(
  protectedCallableOptions,
  notificationDelivery.unregisterNotificationEndpoint,
);
'@ @'
exports.unregisterNotificationEndpoint = onCall(
  protectedCallableOptions,
  notificationDelivery.unregisterNotificationEndpoint,
);
exports.syncDispatchCredentialReminderSchedule = onCall(
  protectedCallableOptions,
  dispatchCredentialMonitor.syncDispatchCredentialReminderSchedule,
);
'@ 'export credential reminder schedule sync callable'

$index = Replace-ExactlyOnce $index @'
exports.cleanupExpiredMarketplaceListingDrafts = onSchedule(
  "every 24 hours",
  async () => marketplaceCommands.cleanupExpiredMarketplaceListingDrafts(),
);
'@ @'
exports.cleanupExpiredMarketplaceListingDrafts = onSchedule(
  "every 24 hours",
  async () => marketplaceCommands.cleanupExpiredMarketplaceListingDrafts(),
);
exports.monitorDispatchCredentialReminders = onSchedule(
  "every 6 hours",
  async () => dispatchCredentialMonitor.monitorCredentialReminders(),
);
'@ 'schedule credential expiry notification monitor'
Write-Utf8NoBom $indexPath $index

Write-Host "`n==> Adding credential notification delivery copy" -ForegroundColor Cyan
$policy = Normalize-Lf ([System.IO.File]::ReadAllText($notificationPolicyPath))
$policy = Replace-ExactlyOnce $policy @'
    dispatch: ["Dispatch update", "Open Pipe Buyer to review the trucking job activity."],
    dispatch_award: ["Dispatch quote selected", "A Dispatch award needs your attention."],
'@ @'
    dispatch: ["Dispatch update", "Open Pipe Buyer to review the trucking job activity."],
    dispatch_credential: ["Credential expiry reminder", "A Dispatch credential needs your attention."],
    dispatch_award: ["Dispatch quote selected", "A Dispatch award needs your attention."],
'@ 'add credential expiry notification copy'
Write-Utf8NoBom $notificationPolicyPath $policy

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL INTELLIGENCE SOURCE APPLIED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Insurance coverage amount + currency fields: INSTALLED' -ForegroundColor Green
Write-Host 'Private aggregate coverage field: INSTALLED' -ForegroundColor Green
Write-Host 'Records / Analytics & alerts tabs: INSTALLED' -ForegroundColor Green
Write-Host 'Credential readiness and expiry analytics: INSTALLED' -ForegroundColor Green
Write-Host 'Private reminder settings: INSTALLED' -ForegroundColor Green
Write-Host 'Scheduled credential notification monitor wiring: INSTALLED' -ForegroundColor Green
Write-Host 'Credential Dart formatter stability: PASS' -ForegroundColor Green
Write-Host 'Dispatch acceptance tracker modified by this migration: NO' -ForegroundColor Green
Write-Host ''
Write-Host 'Run tool/verify_dispatch_credential_intelligence.ps1 next. Acceptance scoring is handled separately.' -ForegroundColor Yellow
