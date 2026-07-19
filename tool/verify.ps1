param(
  [switch]$SkipDependencyRestore,
  [switch]$SkipWebBuild,
  [switch]$SkipRulesEmulator
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

Write-Host 'Flutter SDK'
flutter --version

if (-not $SkipDependencyRestore) {
  Write-Host 'Restoring Flutter dependencies'
  flutter pub get
}

Write-Host 'Analyzing application and tests'
dart analyze lib test

Write-Host 'Running Flutter tests'
flutter test

Write-Host 'Validating Firebase Functions'
if (-not $SkipDependencyRestore) {
  npm ci --prefix firebase/functions
}
npm run check --prefix firebase/functions

if (-not $SkipRulesEmulator) {
  $firebaseCli = Get-Command firebase -ErrorAction SilentlyContinue
  $java = Get-Command java -ErrorAction SilentlyContinue
  if ($firebaseCli -and $java) {
    if (-not $SkipDependencyRestore) {
      npm ci --prefix firebase/rules-tests
    }
    firebase emulators:exec `
      --project demo-pipe-buyer-rules `
      --config firebase/firebase.json `
      --only firestore `
      'npm test --prefix firebase/rules-tests'
  } else {
    Write-Warning (
      'Firestore emulator tests were not run locally because Java and the ' +
      'Firebase CLI are required. CI installs both and enforces these tests.'
    )
  }
}

if (-not $SkipWebBuild) {
  Write-Host 'Building the web release'
  flutter build web --release
}

Write-Host 'Verification completed successfully.'
