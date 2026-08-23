param(
  [switch]$SkipDependencyRestore,
  [switch]$SkipWebBuild,
  [switch]$SkipRulesEmulator
)

$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess([string]$Operation) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace
$releaseSha = (git rev-parse HEAD 2>$null)
if (-not $releaseSha) {
  $releaseSha = 'local'
}
$diagnosticDefines = @(
  '--dart-define=PIPE_ENV=local-verification',
  "--dart-define=PIPE_RELEASE_SHA=$releaseSha"
)

Write-Host 'Flutter SDK'
flutter --version
Assert-NativeSuccess 'Flutter SDK inspection'

Write-Host 'Validating PowerShell release and autonomous tools'
$releaseToolScripts = @(
  (Join-Path $workspace 'tool\verify.ps1'),
  (Join-Path $workspace 'tool\callable_emulator_integration.ps1'),
  (Join-Path $workspace 'tool\web_visual_smoke.ps1'),
  (Join-Path $workspace 'tool\phase1_safe_default_rehearsal.ps1'),
  (Join-Path $workspace 'tool\autonomous_build.ps1'),
  (Join-Path $workspace 'tool\autonomous_build_v2.ps1'),
  (Join-Path $workspace 'tool\autonomous_process.ps1'),
  (Join-Path $workspace 'tool\autonomous_project.ps1'),
  (Join-Path $workspace 'tool\autonomous_guard.ps1'),
  (Join-Path $workspace 'tool\autonomous_builder_self_test.ps1'),
  (Join-Path $workspace 'tool\autonomous_guard_test.ps1')
)
foreach ($scriptPath in $releaseToolScripts) {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
  ) | Out-Null
  if ($parseErrors.Count -gt 0) {
    $details = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "PowerShell syntax failed for $scriptPath`: $details"
  }
}

Write-Host 'Testing autonomous builder governance and configuration'
& (Join-Path $workspace 'tool\autonomous_builder_self_test.ps1') -ProjectRoot $workspace

Write-Host 'Testing autonomous guard fail-closed behavior'
& (Join-Path $workspace 'tool\autonomous_guard_test.ps1')

if (-not $SkipDependencyRestore) {
  Write-Host 'Restoring Flutter dependencies'
  flutter pub get
  Assert-NativeSuccess 'Flutter dependency restore'
}

Write-Host 'Analyzing application and tests'
dart analyze lib test
Assert-NativeSuccess 'Dart analysis'

Write-Host 'Running Flutter tests'
flutter test @diagnosticDefines
Assert-NativeSuccess 'Flutter tests'

Write-Host 'Testing OAuth branding contract'
node --test tool/oauth_branding_test.mjs
Assert-NativeSuccess 'OAuth branding tests'

Write-Host 'Testing release manifest controls'
node --test tool/release_manifest_test.mjs
Assert-NativeSuccess 'Release manifest tests'

Write-Host 'Testing deployed Function parity controls'
node --test tool/function_parity_test.mjs
Assert-NativeSuccess 'Function parity tests'

Write-Host 'Testing Phase 1 acceptance evidence controls'
node --test tool/phase1_acceptance_test.mjs tool/prepare_phase1_acceptance_test.mjs tool/configure_firebase_messaging_worker_test.mjs
Assert-NativeSuccess 'Phase 1 acceptance evidence tests'

Write-Host 'Validating Firebase Functions'
if (-not $SkipDependencyRestore) {
  npm ci --prefix firebase/functions
  Assert-NativeSuccess 'Functions dependency restore'
}
npm run lint --prefix firebase/functions
Assert-NativeSuccess 'Functions lint validation'
npm run check --prefix firebase/functions
Assert-NativeSuccess 'Functions validation'
npm audit --omit=dev --audit-level=high --prefix firebase/functions
Assert-NativeSuccess 'Functions production dependency audit'

if (-not $SkipRulesEmulator) {
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
    throw (
      'Firestore rules tests require Java 21. Install Android Studio or a ' +
      'JDK, then ensure java.exe is on PATH.'
    )
  }
  if (-not $SkipDependencyRestore) {
    npm ci --prefix firebase/rules-tests
    Assert-NativeSuccess 'Firestore rules-test dependency restore'
  }
  npm audit --omit=dev --audit-level=high --prefix firebase/rules-tests
  Assert-NativeSuccess 'Firestore rules-test dependency audit'
  $firebaseCli = Get-Command firebase -ErrorAction SilentlyContinue
  if ($firebaseCli) {
    firebase emulators:exec `
      --project demo-pipe-buyer-rules `
      --config firebase.json `
      --only firestore,storage `
      'npm test --prefix firebase/rules-tests'
    Assert-NativeSuccess 'Firestore security rules tests'
  } else {
    npx --yes firebase-tools@15.25.0 emulators:exec `
      --project demo-pipe-buyer-rules `
      --config firebase.json `
      --only firestore,storage `
      'npm test --prefix firebase/rules-tests'
    Assert-NativeSuccess 'Firestore security rules tests'
  }

  Write-Host 'Testing authenticated callable workflows and retries'
  & (Join-Path $workspace 'tool\callable_emulator_integration.ps1')
}

if (-not $SkipWebBuild) {
  Write-Host 'Building the web release'
  flutter build web --release @diagnosticDefines
  Assert-NativeSuccess 'Flutter web release build'
  Write-Host 'Recording the verified release manifest'
  node tool/release_manifest.mjs `
    --environment local-verification `
    --release-sha $releaseSha `
    --output build/release-manifest.json `
    --require-web
  Assert-NativeSuccess 'Release manifest generation'
}

Write-Host 'Verification completed successfully.'
