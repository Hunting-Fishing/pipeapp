$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$apply = Join-Path $PSScriptRoot 'apply_dispatch_credential_intelligence.ps1'
$credentialSource = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$credentialTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credentials_test.dart'
$privacyTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credentials_privacy_contract_test.dart'
$intelligenceTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credential_intelligence_test.dart'
$monitor = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\dispatch_credential_monitor.js'
$monitorTest = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\test\dispatch_credential_monitor.test.js'
$functionsIndex = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\index.js'
$notificationPolicy = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\notification_delivery_policy.js'
$notificationPolicyTest = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\test\notification_delivery_policy.test.js'
$legacyCredentialGate = Join-Path $PSScriptRoot 'verify_dispatch_phase3_credentials.ps1'
$serviceAreaClassification = Join-Path $script:PipeBuyerRepoRoot 'test\service_area_geocoder_classification_test.dart'
$masterPlan = Join-Path $script:PipeBuyerRepoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'

foreach ($required in @(
  $apply,
  $credentialSource,
  $credentialTest,
  $privacyTest,
  $intelligenceTest,
  $monitor,
  $monitorTest,
  $functionsIndex,
  $notificationPolicy,
  $notificationPolicyTest,
  $legacyCredentialGate,
  $serviceAreaClassification,
  $masterPlan
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required credential intelligence file is missing: $required"
  }
}

Write-Step 'Applying the guarded credential intelligence source migration'
& powershell -ExecutionPolicy Bypass -File $apply
if ($LASTEXITCODE -ne 0) {
  throw 'Credential intelligence source migration failed. Stop at the first error above.'
}

Write-Step 'Checking Node.js syntax before running any credential reminder tests'
foreach ($target in @($monitor, $functionsIndex, $notificationPolicy)) {
  & node --check $target
  if ($LASTEXITCODE -ne 0) {
    throw "Node.js syntax check failed for $target"
  }
}

Write-Step 'Running credential reminder scheduling unit tests'
& node --test $monitorTest
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch credential reminder scheduling tests failed.'
}

Write-Step 'Re-running notification delivery policy tests'
& node --test $notificationPolicyTest
if ($LASTEXITCODE -ne 0) {
  throw 'Notification delivery policy regression failed.'
}

Write-Step 'Formatting the credential intelligence Dart source and focused tests'
& dart format $credentialSource $credentialTest $privacyTest $intelligenceTest
if ($LASTEXITCODE -ne 0) {
  throw 'Credential intelligence Dart formatting failed.'
}

Write-Step 'Confirming formatter stability'
& dart format --output=none --set-exit-if-changed `
  $credentialSource `
  $credentialTest `
  $privacyTest `
  $intelligenceTest
if ($LASTEXITCODE -ne 0) {
  throw 'Credential intelligence Dart source is not formatter stable.'
}

Write-Step 'Running strict analyzer on credential intelligence source and tests'
foreach ($target in @(
  $credentialSource,
  $credentialTest,
  $privacyTest,
  $intelligenceTest
)) {
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Credential intelligence strict analyzer failed for $target"
  }
}

Write-Step 'Running coverage, reminder and private-data model tests'
foreach ($target in @($credentialTest, $privacyTest, $intelligenceTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Credential intelligence Flutter test failed for $target"
  }
}

Write-Step 'Re-proving the Towns/Regions map classification accepted immediately before this slice'
& flutter test $serviceAreaClassification
if ($LASTEXITCODE -ne 0) {
  throw 'Service-area Towns/Regions classification regression failed.'
}

Write-Step 'Running the complete existing Phase 3 credential privacy/rules regression gate at the new 51% baseline'
& powershell -ExecutionPolicy Bypass -File $legacyCredentialGate
if ($LASTEXITCODE -ne 0) {
  throw 'Existing Phase 3 credential privacy/rules gate failed.'
}

Write-Step 'Checking source-level intelligence contracts'
$credentialText = Get-Content -LiteralPath $credentialSource -Raw
foreach ($marker in @(
  'final double? coverageLimit;',
  'final double? aggregateLimit;',
  'bool meetsMinimumCoverage(',
  'class DispatchCredentialReminderSettings',
  "'dispatchCredentialReminderSettings': settings.toPrivateMap()",
  "_commands.execute('syncDispatchCredentialReminderSchedule'",
  "text: 'Analytics & alerts'",
  'Insurance matching readiness',
  'Credential analytics & alerts',
  'Exact policy numbers and coverage amounts remain private.'
)) {
  if (-not $credentialText.Contains($marker)) {
    throw "Credential intelligence contract missing: $marker"
  }
}

if ($credentialText.Contains("collection('public_business_profiles')") -or
    $credentialText.Contains("collection('dispatch_carriers')")) {
  throw 'Credential intelligence must not write private coverage or reminder data into public/legacy provider records.'
}

$indexText = Get-Content -LiteralPath $functionsIndex -Raw
foreach ($marker in @(
  'createDispatchCredentialMonitor',
  'syncDispatchCredentialReminderSchedule',
  'monitorDispatchCredentialReminders',
  '"every 6 hours"'
)) {
  if (-not $indexText.Contains($marker)) {
    throw "Credential reminder function wiring missing: $marker"
  }
}

$monitorText = Get-Content -LiteralPath $monitor -Raw
foreach ($marker in @(
  'dispatchCredentialNextReminderAt',
  '.where("dispatchCredentialNextReminderAt", "<=", now)',
  'dispatchCredentialReminderSent',
  'type: "dispatch_credential"',
  'externalDelivery: true'
)) {
  if (-not $monitorText.Contains($marker)) {
    throw "Credential reminder scaling/privacy contract missing: $marker"
  }
}

$planText = Get-Content -LiteralPath $masterPlan -Raw
foreach ($marker in @(
  '**Current verified completion:** **51%**',
  '**Current verified:** 14/15',
  '- [x] Service area and home-base map setup. **1 pt**',
  '- [ ] Credential/insurance metadata with private document separation. **1 pt**'
)) {
  if (-not $planText.Contains($marker)) {
    throw "Dispatch master plan acceptance state missing: $marker"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL INTELLIGENCE ENGINEERING GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Service-area browser acceptance recorded: PASS (Phase 3 = 14/15)' -ForegroundColor Green
Write-Host 'Primary insurance coverage amount + currency: PASS' -ForegroundColor Green
Write-Host 'Optional aggregate coverage amount: PASS' -ForegroundColor Green
Write-Host 'Server-side minimum coverage eligibility helper: PASS' -ForegroundColor Green
Write-Host 'Records / Analytics & alerts UI contract: PASS' -ForegroundColor Green
Write-Host 'Credential readiness + expiry analytics: PASS' -ForegroundColor Green
Write-Host 'Private reminder preference model: PASS' -ForegroundColor Green
Write-Host 'Scalable next-due reminder scheduling model: PASS' -ForegroundColor Green
Write-Host 'Scheduled Pipe Buyer credential notification monitor: PASS' -ForegroundColor Green
Write-Host 'Private Firestore/Storage boundary: PASS' -ForegroundColor Green
Write-Host 'No verification overclaim: PASS' -ForegroundColor Green
Write-Host 'Town/Region map regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Official Dispatch progress remains 51% / Phase 3 14-of-15 until browser acceptance of the expanded credential workflow.' -ForegroundColor Yellow
Write-Host 'After browser acceptance, Phase 3 may move to 15/15 and Phase 4 may open.' -ForegroundColor Yellow
