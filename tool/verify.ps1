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

Write-Host 'Testing release manifest controls'
node --test tool/release_manifest_test.mjs
Assert-NativeSuccess 'Release manifest tests'

Write-Host 'Validating Firebase Functions'
if (-not $SkipDependencyRestore) {
  npm ci --prefix firebase/functions
  Assert-NativeSuccess 'Functions dependency restore'
}
npm run check --prefix firebase/functions
Assert-NativeSuccess 'Functions validation'

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
  $firebaseCli = Get-Command firebase -ErrorAction SilentlyContinue
  if ($firebaseCli) {
    firebase emulators:exec `
      --project demo-pipe-buyer-rules `
      --config firebase/firebase.json `
      --only firestore `
      'npm test --prefix firebase/rules-tests'
    Assert-NativeSuccess 'Firestore security rules tests'
  } else {
    npx --yes firebase-tools@15.24.0 emulators:exec `
      --project demo-pipe-buyer-rules `
      --config firebase/firebase.json `
      --only firestore `
      'npm test --prefix firebase/rules-tests'
    Assert-NativeSuccess 'Firestore security rules tests'
  }
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
