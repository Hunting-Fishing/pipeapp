param(
  [switch]$SkipDependencyRestore,
  [switch]$SkipWebBuild,
  [switch]$SkipRulesEmulator
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace
$releaseSha = (git rev-parse --short=12 HEAD 2>$null)
if (-not $releaseSha) {
  $releaseSha = 'local'
}
$diagnosticDefines = @(
  '--dart-define=PIPE_ENV=local-verification',
  "--dart-define=PIPE_RELEASE_SHA=$releaseSha"
)

Write-Host 'Flutter SDK'
flutter --version

if (-not $SkipDependencyRestore) {
  Write-Host 'Restoring Flutter dependencies'
  flutter pub get
}

Write-Host 'Analyzing application and tests'
dart analyze lib test

Write-Host 'Running Flutter tests'
flutter test @diagnosticDefines

Write-Host 'Validating Firebase Functions'
if (-not $SkipDependencyRestore) {
  npm ci --prefix firebase/functions
}
npm run check --prefix firebase/functions

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
  }
  $firebaseCli = Get-Command firebase -ErrorAction SilentlyContinue
  if ($firebaseCli) {
    firebase emulators:exec `
      --project demo-pipe-buyer-rules `
      --config firebase/firebase.json `
      --only firestore `
      'npm test --prefix firebase/rules-tests'
  } else {
    npx --yes firebase-tools@15.24.0 emulators:exec `
      --project demo-pipe-buyer-rules `
      --config firebase/firebase.json `
      --only firestore `
      'npm test --prefix firebase/rules-tests'
  }
}

if (-not $SkipWebBuild) {
  Write-Host 'Building the web release'
  flutter build web --release @diagnosticDefines
}

Write-Host 'Verification completed successfully.'
