$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$generatedFiles = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugin_registrant.h',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugin_registrant.h',
  'windows/flutter/generated_plugins.cmake'
)

function Restore-GeneratedPluginFiles {
  foreach ($generated in $generatedFiles) {
    git restore -- $generated 2>$null
  }
}

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranch = ((git branch --show-current | Out-String).Trim())

if ([string]::IsNullOrWhiteSpace($currentBranch)) {
  $headSha = ((git rev-parse HEAD | Out-String).Trim())
  $expectedSha = ((git rev-parse "origin/$expectedBranch" | Out-String).Trim())
  if ([string]::IsNullOrWhiteSpace($headSha) -or
      [string]::IsNullOrWhiteSpace($expectedSha) -or
      $headSha -ne $expectedSha) {
    throw "Detached credential verification worktree must exactly match origin/$expectedBranch."
  }
}
elseif ($currentBranch -ne $expectedBranch) {
  throw "Dispatch Phase 3 credential verification requires $expectedBranch. Current branch: $currentBranch"
}

$credentialSource = '.\lib\marketplace\marketplace_dispatch_credentials.dart'
$companyProfilePage = '.\lib\marketplace\marketplace_dispatch_company_profile_page.dart'
$credentialTest = '.\test\marketplace_dispatch_credentials_test.dart'
$privacyTest = '.\test\marketplace_dispatch_credentials_privacy_contract_test.dart'
$profileTest = '.\test\marketplace_dispatch_company_profile_test.dart'
$persistenceTest = '.\test\marketplace_dispatch_company_profile_persistence_contract_test.dart'
$equipmentTest = '.\test\marketplace_dispatch_equipment_capability_test.dart'
$geographyTest = '.\test\marketplace_dispatch_geography_test.dart'
$serviceAreaTest = '.\test\marketplace_dispatch_service_area_persistence_contract_test.dart'
$taxonomyTest = '.\test\marketplace_dispatch_service_taxonomy_test.dart'
$navigationTest = '.\test\marketplace_dispatch_navigation_test.dart'
$authTest = '.\test\dispatch_auth_reactivity_contract_test.dart'
$credentialRulesTest = '.\firebase\rules-tests\dispatch_credentials_rules.test.js'
$storageRules = '.\firebase\storage.rules'
$firestoreRules = '.\firebase\firestore.rules'
$masterPlan = '.\docs\DISPATCH_NETWORK_MASTER_PLAN.md'

foreach ($required in @(
  $credentialSource,
  $companyProfilePage,
  $credentialTest,
  $privacyTest,
  $profileTest,
  $persistenceTest,
  $equipmentTest,
  $geographyTest,
  $serviceAreaTest,
  $taxonomyTest,
  $navigationTest,
  $authTest,
  $credentialRulesTest,
  $storageRules,
  $firestoreRules,
  $masterPlan
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Phase 3 credential file is missing: $required"
  }
}

$lockPath = '.\pubspec.lock'
$packageConfig = '.\.dart_tool\package_config.json'
if (-not (Test-Path -LiteralPath $packageConfig)) {
  if (-not (Test-Path -LiteralPath $lockPath)) {
    throw 'pubspec.lock is missing.'
  }
  $lockHashBefore = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash
  Write-Step 'Resolving Flutter dependencies because package_config.json is missing'
  flutter pub get
  if ($LASTEXITCODE -ne 0) {
    Restore-GeneratedPluginFiles
    throw 'flutter pub get failed.'
  }
  if (-not (Test-Path -LiteralPath $packageConfig)) {
    Restore-GeneratedPluginFiles
    throw 'flutter pub get did not create .dart_tool/package_config.json.'
  }
  $lockHashAfter = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash
  Restore-GeneratedPluginFiles
  if ($lockHashAfter -ne $lockHashBefore) {
    throw 'SAFETY STOP: dependency bootstrap changed pubspec.lock.'
  }
}

Write-Step 'Formatting Phase 3 credential source and tests'
dart format `
  $credentialSource `
  $companyProfilePage `
  $credentialTest `
  $privacyTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 credential formatting failed.'
}

Write-Step 'Confirming formatter stability'
dart format --output=none --set-exit-if-changed `
  $credentialSource `
  $companyProfilePage `
  $credentialTest `
  $privacyTest
if ($LASTEXITCODE -ne 0) {
  throw 'Phase 3 credential files are not formatter stable.'
}

Write-Step 'Running strict analyzer'
foreach ($target in @(
  $credentialSource,
  $companyProfilePage,
  $credentialTest,
  $privacyTest
)) {
  dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 credential strict analyzer failed for $target"
  }
}

Write-Step 'Running credential model and privacy tests'
foreach ($target in @($credentialTest, $privacyTest)) {
  flutter test $target
  if ($LASTEXITCODE -ne 0) {
    Restore-GeneratedPluginFiles
    throw "Phase 3 credential test failed for $target"
  }
}
Restore-GeneratedPluginFiles

Write-Step 'Re-running Phase 3 profile, equipment, and geography regressions'
foreach ($target in @(
  $profileTest,
  $persistenceTest,
  $equipmentTest,
  $geographyTest,
  $serviceAreaTest
)) {
  flutter test $target
  if ($LASTEXITCODE -ne 0) {
    Restore-GeneratedPluginFiles
    throw "Phase 3 regression failed for $target"
  }
}
Restore-GeneratedPluginFiles

Write-Step 'Re-running Phase 2, Phase 1, and auth regressions'
foreach ($target in @($taxonomyTest, $navigationTest, $authTest)) {
  flutter test $target
  if ($LASTEXITCODE -ne 0) {
    Restore-GeneratedPluginFiles
    throw "Dispatch regression failed for $target"
  }
}
Restore-GeneratedPluginFiles

Write-Step 'Running credential Firestore and Storage rules tests'
$rulesNodeModules = '.\firebase\rules-tests\node_modules'
if (-not (Test-Path -LiteralPath $rulesNodeModules)) {
  Push-Location '.\firebase\rules-tests'
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

$rulesCommand = 'node --test --test-concurrency=1 firebase/rules-tests/dispatch_credentials_rules.test.js'
$firebaseCli = Get-Command firebase -ErrorAction SilentlyContinue
if ($firebaseCli) {
  firebase emulators:exec `
    --project demo-pipe-buyer-dispatch-credential-rules `
    --config firebase.json `
    --only firestore,storage `
    $rulesCommand
}
else {
  npx --yes firebase-tools@15.25.0 emulators:exec `
    --project demo-pipe-buyer-dispatch-credential-rules `
    --config firebase.json `
    --only firestore,storage `
    $rulesCommand
}
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch credential Firestore/Storage rules test failed.'
}

Write-Step 'Checking credential privacy contracts'
$credentialText = Get-Content -LiteralPath $credentialSource -Raw
foreach ($requiredText in @(
  "collection('business_private')",
  "'dispatchCredentials': values",
  'business_documents/$uid/dispatch_credential_',
  'Uploading does not mean it is verified.'
)) {
  if (-not $credentialText.Contains($requiredText)) {
    throw "Credential privacy contract is missing: $requiredText"
  }
}

if ($credentialText.Contains("collection('public_business_profiles')") -or
    $credentialText.Contains("collection('dispatch_carriers')")) {
  throw 'Credential source must not write credential metadata into public or legacy carrier records.'
}

$companyPageText = Get-Content -LiteralPath $companyProfilePage -Raw
foreach ($requiredText in @(
  "import 'marketplace_dispatch_credentials.dart';",
  'MarketplaceDispatchCredentialsPage()',
  'Manage credentials'
)) {
  if (-not $companyPageText.Contains($requiredText)) {
    throw "Company Profile credential wiring is missing: $requiredText"
  }
}

$storageText = Get-Content -LiteralPath $storageRules -Raw
foreach ($requiredText in @(
  'match /business_documents/{userId}/{fileName}',
  'allow read: if isOwner(userId) || isAdmin();'
)) {
  if (-not $storageText.Contains($requiredText)) {
    throw "Private business document rule is missing: $requiredText"
  }
}

$firestoreText = Get-Content -LiteralPath $firestoreRules -Raw
foreach ($requiredText in @(
  'match /business_private/{businessId}',
  'allow create, read, update, delete: if owns(businessId);'
)) {
  if (-not $firestoreText.Contains($requiredText)) {
    throw "Private business Firestore rule is missing: $requiredText"
  }
}

$planText = Get-Content -LiteralPath $masterPlan -Raw
if (-not $planText.Contains('**Current verified completion:** **50%**')) {
  throw 'Master plan moved beyond the verified 50% baseline before remaining browser acceptance.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 3 CREDENTIAL ENGINEERING GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Stable credential codes: PASS' -ForegroundColor Green
Write-Host 'Self-reported status model: PASS' -ForegroundColor Green
Write-Host 'Private Firestore metadata boundary: PASS' -ForegroundColor Green
Write-Host 'Private Storage evidence boundary: PASS' -ForegroundColor Green
Write-Host 'Credential emulator rules tests: PASS' -ForegroundColor Green
Write-Host 'No public verification claim: PASS' -ForegroundColor Green
Write-Host 'Company Profile credential wiring: PASS' -ForegroundColor Green
Write-Host 'Phase 3 regressions: PASS' -ForegroundColor Green
Write-Host 'Phase 2 taxonomy regression: PASS' -ForegroundColor Green
Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch auth reactivity regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Official Dispatch progress remains 50% until the remaining browser acceptance checks pass.' -ForegroundColor Yellow
Write-Host 'Phase 4 remains blocked until Phase 3 reaches 15/15.' -ForegroundColor Yellow
