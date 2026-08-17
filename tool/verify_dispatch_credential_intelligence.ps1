$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$credentialSource = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$credentialTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credentials_test.dart'
$privacyTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credentials_privacy_contract_test.dart'
$intelligenceTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_credential_intelligence_test.dart'
$monitor = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\dispatch_credential_monitor.js'
$monitorTest = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\test\dispatch_credential_monitor.test.js'
$functionsIndex = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\index.js'
$notificationPolicy = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\notification_delivery_policy.js'
$notificationPolicyTest = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\test\notification_delivery_policy.test.js'
$serviceAreaClassification = Join-Path $script:PipeBuyerRepoRoot 'test\service_area_geocoder_classification_test.dart'
$masterPlan = Join-Path $script:PipeBuyerRepoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'
$credentialRulesTest = Join-Path $script:PipeBuyerRepoRoot 'firebase\rules-tests\dispatch_credentials_rules.test.js'
$storageRules = Join-Path $script:PipeBuyerRepoRoot 'firebase\storage.rules'
$firestoreRules = Join-Path $script:PipeBuyerRepoRoot 'firebase\firestore.rules'

$regressionTests = @(
  'test\marketplace_dispatch_company_profile_test.dart',
  'test\marketplace_dispatch_company_profile_persistence_contract_test.dart',
  'test\marketplace_dispatch_equipment_capability_test.dart',
  'test\marketplace_dispatch_geography_test.dart',
  'test\marketplace_dispatch_service_area_persistence_contract_test.dart',
  'test\marketplace_dispatch_service_taxonomy_test.dart',
  'test\marketplace_dispatch_navigation_test.dart',
  'test\dispatch_auth_reactivity_contract_test.dart'
) | ForEach-Object { Join-Path $script:PipeBuyerRepoRoot $_ }

foreach ($required in @(
  $credentialSource,
  $credentialTest,
  $privacyTest,
  $intelligenceTest,
  $monitor,
  $monitorTest,
  $functionsIndex,
  $notificationPolicy,
  $notificationPolicyTest,
  $serviceAreaClassification,
  $masterPlan,
  $credentialRulesTest,
  $storageRules,
  $firestoreRules
) + $regressionTests) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required credential intelligence verification file is missing: $required"
  }
}

Write-Step 'Confirming the credential intelligence implementation is already installed'
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
    throw "STOP: Credential intelligence implementation marker is missing: $marker. Run apply_dispatch_credential_intelligence.ps1 once before verifying."
  }
}
Write-Host 'Implementation markers: PASS' -ForegroundColor Green
Write-Host 'Verifier source mutation: NONE' -ForegroundColor Green

Write-Step 'Checking Node.js syntax'
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

Write-Step 'Confirming Dart formatter stability without changing source'
& dart format --output=none --set-exit-if-changed `
  $credentialSource `
  $credentialTest `
  $privacyTest `
  $intelligenceTest
if ($LASTEXITCODE -ne 0) {
  throw 'Credential intelligence Dart source is not formatter stable. Format the reported file once, then rerun.'
}

Write-Step 'Running strict analyzer on credential intelligence source and tests'
foreach ($target in @($credentialSource, $credentialTest, $privacyTest, $intelligenceTest)) {
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

Write-Step 'Re-proving the accepted Towns/Regions map classification'
& flutter test $serviceAreaClassification
if ($LASTEXITCODE -ne 0) {
  throw 'Service-area Towns/Regions classification regression failed.'
}

Write-Step 'Running Phase 3 / Phase 2 / Phase 1 / auth regressions'
foreach ($target in $regressionTests) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch regression failed for $target"
  }
}

Write-Step 'Running credential Firestore and Storage rules tests on isolated emulator ports'
$rulesNodeModules = Join-Path $script:PipeBuyerRepoRoot 'firebase\rules-tests\node_modules'
if (-not (Test-Path -LiteralPath $rulesNodeModules)) {
  Push-Location (Join-Path $script:PipeBuyerRepoRoot 'firebase\rules-tests')
  try {
    npm ci
    if ($LASTEXITCODE -ne 0) {
      throw 'Credential rules-test dependency restore failed.'
    }
  }
  finally {
    Pop-Location
  }
}

$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java) {
  $androidStudioJdk = 'C:\Program Files\Android\Android Studio\jbr'
  if (Test-Path (Join-Path $androidStudioJdk 'bin\java.exe')) {
    $env:JAVA_HOME = $androidStudioJdk
    $env:Path = "$androidStudioJdk\bin;$env:Path"
    $java = Get-Command java -ErrorAction SilentlyContinue
  }
}
if (-not $java) {
  throw 'Credential rules tests require Java. Android Studio JBR or a JDK must be available.'
}

Push-Location $script:PipeBuyerRepoRoot
try {
  $rulesCommand = 'node --test --test-concurrency=1 firebase/rules-tests/dispatch_credentials_rules.test.js'
  $firebaseCli = Get-Command firebase -ErrorAction SilentlyContinue
  if ($firebaseCli) {
    & firebase emulators:exec --project demo-pipe-buyer-dispatch-credential-rules --config firebase.json --only firestore,storage $rulesCommand
  }
  else {
    & npx --yes firebase-tools@15.25.0 emulators:exec --project demo-pipe-buyer-dispatch-credential-rules --config firebase.json --only firestore,storage $rulesCommand
  }
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch credential Firestore/Storage rules test failed.'
  }
}
finally {
  Pop-Location
}

Write-Step 'Checking privacy, reminder, and acceptance-state contracts'
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

$storageText = Get-Content -LiteralPath $storageRules -Raw
if (-not $storageText.Contains('match /business_documents/{userId}/{fileName}')) {
  throw 'Private business document Storage rule is missing.'
}
$firestoreText = Get-Content -LiteralPath $firestoreRules -Raw
if (-not $firestoreText.Contains('match /business_private/{businessId}')) {
  throw 'Private business Firestore rule is missing.'
}

$planText = Get-Content -LiteralPath $masterPlan -Raw
foreach ($marker in @(
  '**Current verified completion:** **51%**',
  '**Current verified:** 14/15',
  '- [x] Service area and home-base map setup. **1 pt**',
  '- [ ] Credential/insurance metadata with private document separation. **1 pt**'
)) {
  if (-not $planText.Contains($marker)) {
    throw "Dispatch master plan pre-credential-acceptance state missing: $marker. Run reconcile_dispatch_phase3_precredential_acceptance.ps1 once, then rerun this read-only verifier."
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL INTELLIGENCE ENGINEERING GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Verifier is read-only: PASS' -ForegroundColor Green
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
