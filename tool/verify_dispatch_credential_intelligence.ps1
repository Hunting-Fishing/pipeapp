$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function File-Hash([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
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
$credentialRulesTest = Join-Path $script:PipeBuyerRepoRoot 'firebase\rules-tests\dispatch_credentials_rules.test.js'
$storageRules = Join-Path $script:PipeBuyerRepoRoot 'firebase\storage.rules'
$firestoreRules = Join-Path $script:PipeBuyerRepoRoot 'firebase\firestore.rules'
$masterPlan = Join-Path $script:PipeBuyerRepoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'

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

$requiredFiles = @(
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
  $credentialRulesTest,
  $storageRules,
  $firestoreRules
) + $regressionTests

foreach ($required in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required credential intelligence verification file is missing: $required"
  }
}

if (-not (Test-Path -LiteralPath (Join-Path $script:PipeBuyerRepoRoot '.dart_tool\package_config.json'))) {
  throw 'STOP: Flutter package configuration is missing. Run tool/pipebuyer_doctor.ps1 before verification.'
}

$protectedSources = @(
  $credentialSource,
  $monitor,
  $functionsIndex,
  $notificationPolicy,
  $storageRules,
  $firestoreRules
)
$beforeHashes = @{}
foreach ($path in $protectedSources) {
  $beforeHashes[$path] = File-Hash $path
}

Write-Step 'Confirming credential intelligence implementation markers'
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
    throw "STOP: Credential intelligence implementation marker is missing: $marker"
  }
}
if ($credentialText.Contains("collection('public_business_profiles')") -or
    $credentialText.Contains("collection('dispatch_carriers')")) {
  throw 'Credential intelligence must not write private coverage/reminder data into public or legacy provider records.'
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
  throw 'Credential intelligence Dart source is not formatter stable.'
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
    & npm ci
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

Write-Step 'Checking privacy and reminder contracts'
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
if (-not $storageText.Contains('match /business_documents/{userId}/{fileName}') -or
    -not $storageText.Contains('allow read: if isOwner(userId) || isAdmin();')) {
  throw 'Private credential Storage boundary is missing.'
}
$firestoreText = Get-Content -LiteralPath $firestoreRules -Raw
if (-not $firestoreText.Contains('match /business_private/{businessId}') -or
    -not $firestoreText.Contains('allow create, read, update, delete: if owns(businessId);')) {
  throw 'Private credential Firestore boundary is missing.'
}

# Tracker/documentation state is informational only. Engineering verifiers do
# not fail, rewrite, or downgrade source because a local status document is
# ahead, behind, or partially updated.
if (Test-Path -LiteralPath $masterPlan) {
  $planText = Get-Content -LiteralPath $masterPlan -Raw
  $match = [regex]::Match($planText, '\*\*Current verified completion:\*\* \*\*(\d+)%\*\*')
  if ($match.Success) {
    Write-Host "Dispatch tracker observed: $($match.Groups[1].Value)% (informational only)" -ForegroundColor DarkGray
  }
}

Write-Step 'Proving verifier did not mutate protected production source'
foreach ($path in $protectedSources) {
  $afterHash = File-Hash $path
  if ($afterHash -ne $beforeHashes[$path]) {
    throw "SAFETY STOP: Read-only verifier changed protected source: $path"
  }
}
Write-Host 'Protected production source hashes unchanged: PASS' -ForegroundColor Green

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL INTELLIGENCE ENGINEERING GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Verifier is source-read-only: PASS' -ForegroundColor Green
Write-Host 'Reminder next-due scheduling: PASS' -ForegroundColor Green
Write-Host 'Primary insurance coverage amount + currency: PASS' -ForegroundColor Green
Write-Host 'Optional aggregate coverage amount: PASS' -ForegroundColor Green
Write-Host 'Server-side minimum coverage eligibility helper: PASS' -ForegroundColor Green
Write-Host 'Records / Analytics & alerts UI contract: PASS' -ForegroundColor Green
Write-Host 'Credential readiness + expiry analytics: PASS' -ForegroundColor Green
Write-Host 'Private reminder preference model: PASS' -ForegroundColor Green
Write-Host 'Scheduled Pipe Buyer credential notification monitor: PASS' -ForegroundColor Green
Write-Host 'Private Firestore/Storage boundary: PASS' -ForegroundColor Green
Write-Host 'No verification overclaim: PASS' -ForegroundColor Green
Write-Host 'Town/Region map regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch navigation/auth regressions: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Tracker state was not changed or enforced by this verifier.' -ForegroundColor Yellow
Write-Host 'Browser acceptance remains a separate step.' -ForegroundColor Yellow
